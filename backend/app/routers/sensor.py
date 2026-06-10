from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from app.models.sensor import SensorData, LcdScanResult
from app.database import get_db
from pymongo.asynchronous.database import AsyncDatabase
from app.agents.llm_utils import get_genai_client, generate_json_with_image
from datetime import datetime, timezone

router = APIRouter(tags=["IoT Sensors"])

@router.post("/sensor", summary="Ingest IoT sensor data into Time Series collection")
async def ingest_sensor_data(data: SensorData, db: AsyncDatabase = Depends(get_db)):
    """
    Ingest a new sensor reading into the 'sensor_data' Time Series collection.
    """
    doc = data.model_dump()
    await db.sensor_data.insert_one(doc)
    return {"status": "success"}

@router.post("/sensor/{plot_id}/sync-open-meteo", summary="Fetch last 7 days from Open-Meteo")
async def sync_open_meteo(plot_id: str, lat: float, lon: float, db: AsyncDatabase = Depends(get_db)):
    """
    Connects to Open-Meteo free API, fetches the LAST 7 DAYS of daily temperature,
    humidity and soil moisture, and writes each day as a separate reading into
    the MongoDB Time Series collection.
    """
    import httpx
    from datetime import datetime, timedelta, timezone
    
    end_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    start_date = (datetime.now(timezone.utc) - timedelta(days=6)).strftime("%Y-%m-%d")
    
    url = (
        f"https://api.open-meteo.com/v1/forecast?"
        f"latitude={lat}&longitude={lon}"
        f"&daily=temperature_2m_mean,relative_humidity_2m_mean,soil_moisture_0_to_7cm_mean"  
        f"&start_date={start_date}&end_date={end_date}"
        f"&timezone=auto"
    )
    
    headers = {"User-Agent": "AgriAgent-App/1.0"}
    async with httpx.AsyncClient(headers=headers) as client:
        response = await client.get(url)
        if response.status_code != 200:
            raise HTTPException(status_code=502, detail="Failed to fetch data from Open-Meteo")
            
        data = response.json()
        daily = data.get("daily", {})
        
        dates = daily.get("time", [])
        temps = daily.get("temperature_2m_mean", [])
        humidities = daily.get("relative_humidity_2m_mean", [])
        soil_moistures = daily.get("soil_moisture_0_to_7cm_mean", [])
        
        # Delete old data for this plot to avoid duplicates
        await db.sensor_data.delete_many({"plot_id": plot_id})
        
        inserted_count = 0
        latest_data = None
        for i, date_str in enumerate(dates):
            temp = temps[i] if i < len(temps) and temps[i] is not None else 20.0
            humidity = humidities[i] if i < len(humidities) and humidities[i] is not None else 50.0
            soil_m = (soil_moistures[i] if i < len(soil_moistures) and soil_moistures[i] is not None else 0.3) * 100
            
            ts = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
            
            sensor_data = SensorData(
                plot_id=plot_id,
                soil_moisture=round(soil_m, 1),
                temperature=round(temp, 1),
                humidity=round(humidity, 1),
                timestamp=ts,
            )
            
            await db.sensor_data.insert_one(sensor_data.model_dump())
            inserted_count += 1
            latest_data = sensor_data
        
        return {
            "status": "success",
            "source": "Open-Meteo API (7-day history)",
            "days_inserted": inserted_count,
            "data": latest_data.model_dump() if latest_data else {},
        }

@router.get("/sensor/{plot_id}/trend", summary="Get sensor trends using Aggregation")
async def get_sensor_trend(plot_id: str, db: AsyncDatabase = Depends(get_db)):
    """
    Use an aggregation pipeline to calculate average moisture and temperature for a plot.
    This demonstrates the power of Time Series collections in MongoDB.
    """
    pipeline = [
        {"$match": {"plot_id": plot_id}},
        {
            "$group": {
                "_id": {
                    "year": {"$year": "$timestamp"},
                    "month": {"$month": "$timestamp"},
                    "day": {"$dayOfMonth": "$timestamp"}
                },
                "avg_moisture": {"$avg": "$soil_moisture"},
                "avg_temperature": {"$avg": "$temperature"},
                "readings_count": {"$sum": 1}
            }
        },
        {"$sort": {"_id.year": -1, "_id.month": -1, "_id.day": -1}},
        {"$limit": 7}  # Last 7 days
    ]
    
    cursor = await db.sensor_data.aggregate(pipeline)
    results = []
    async for doc in cursor:
        results.append(doc)
        
    return results

@router.post("/sensor/{plot_id}/scan-lcd", summary="Scan and parse physical sensor LCD screenshot via Gemini Vision OCR")
async def scan_lcd_sensor(
    plot_id: str,
    file: UploadFile = File(...),
    db: AsyncDatabase = Depends(get_db)
):
    """
    Upload a picture of an LCD screen (such as from a cheap $5 sensor).
    This endpoint uses Gemini 2.5 Flash Vision to parse the image,
    ingest the reading into MongoDB Time-Series collection,
    and update the soil analysis pH if the measurement is pH.
    """
    # Read file bytes
    image_bytes = await file.read()
    mime_type = file.content_type or "image/jpeg"
    
    # 1. Parse image using Gemini Vision
    client = get_genai_client()
    prompt = (
        "You are an expert agricultural engineer and specialized IoT telemetry analyst. "
        "The attached image shows the screen (LCD/LED or dial) of a physical soil moisture, pH, "
        "temperature, or humidity probe sensor used by a farmer in the field. "
        "Please extract the numerical measurement value, the unit, and classify the sensor type. "
        "Sensor type must be one of: 'moisture', 'temperature', or 'ph'. "
        "If you see a value like 6.5 on a pH meter, sensor_type is 'ph', value is 6.5, and unit is 'pH'. "
        "If you see a value like 35% on a moisture probe, sensor_type is 'moisture', value is 35.0, and unit is '%'. "
        "If you see a temperature like 24 C, sensor_type is 'temperature', value is 24.0, and unit is 'C'. "
        "Please parse the reading carefully and return the structured JSON output."
    )
    
    try:
        scan_res: LcdScanResult = generate_json_with_image(
            client=client,
            prompt=prompt,
            image_bytes=image_bytes,
            mime_type=mime_type,
            response_schema=LcdScanResult,
            model_name="gemini-2.5-flash",
            temperature=0.1
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini OCR parsing failed: {str(e)}")

    # 2. Update the database
    # Check if a farmer profile has a plot with this plot_id
    farmer_data = await db.farmers.find_one({"plots.plot_id": plot_id})
    if not farmer_data:
        raise HTTPException(status_code=404, detail=f"Plot with ID {plot_id} not found in any farmer profile")
        
    from app.models.farmer import FarmerProfile, SoilAnalysis
    farmer = FarmerProfile(**farmer_data)
    
    plot_index = -1
    for idx, p in enumerate(farmer.plots):
        if p.plot_id == plot_id:
            plot_index = idx
            break
            
    if plot_index == -1:
        raise HTTPException(status_code=404, detail="Plot reference is invalid")
        
    # If the sensor is pH, update the plot's soil analysis in the farmer document
    if scan_res.sensor_type == "ph":
        plot = farmer.plots[plot_index]
        if not plot.soil_analysis:
            plot.soil_analysis = SoilAnalysis(
                ph=scan_res.value,
                nitrogen_ppm=0.0,
                phosphorus_ppm=0.0,
                potassium_ppm=0.0,
                organic_matter_percent=0.0,
                salinity_ds_m=0.0,
                texture="Loamy",
                test_date=datetime.now(timezone.utc)
            )
        else:
            plot.soil_analysis.ph = scan_res.value
            
        await db.farmers.update_one(
            {"user_id": farmer.user_id},
            {"$set": {
                f"plots.{plot_index}.soil_analysis": plot.soil_analysis.model_dump(mode="json")
            }}
        )
    else:
        # Otherwise, insert/update the time-series sensor collection
        # Fetch the latest reading for this plot to propagate existing metrics nicely
        latest = await db.sensor_data.find_one(
            {"plot_id": plot_id},
            sort=[("timestamp", -1)]
        )
        
        current_moisture = latest.get("soil_moisture", 50.0) if latest else 50.0
        current_temp = latest.get("temperature", 20.0) if latest else 20.0
        current_humidity = latest.get("humidity", 50.0) if latest else 50.0
        
        if scan_res.sensor_type == "moisture":
            current_moisture = scan_res.value
        elif scan_res.sensor_type == "temperature":
            current_temp = scan_res.value
        elif scan_res.sensor_type == "humidity":
            current_humidity = scan_res.value
            
        new_reading = SensorData(
            plot_id=plot_id,
            soil_moisture=round(current_moisture, 1),
            temperature=round(current_temp, 1),
            humidity=round(current_humidity, 1),
            timestamp=datetime.now(timezone.utc)
        )
        
        await db.sensor_data.insert_one(new_reading.model_dump())

    return {
        "status": "success",
        "sensor_type": scan_res.sensor_type,
        "value": scan_res.value,
        "unit": scan_res.unit
    }

