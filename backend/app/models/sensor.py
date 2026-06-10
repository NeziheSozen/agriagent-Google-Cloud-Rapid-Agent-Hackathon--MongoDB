from pydantic import BaseModel, Field
from datetime import datetime, timezone

class SensorData(BaseModel):
    """
    IoT Sensor data model for MongoDB Time Series.
    """
    plot_id: str = Field(..., description="The ID of the farm plot")
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    soil_moisture: float = Field(..., description="Soil moisture percentage (0-100)")
    temperature: float = Field(..., description="Temperature in Celsius")
    humidity: float = Field(..., description="Air humidity percentage (0-100)")

class LcdScanResult(BaseModel):
    """
    Structured response parsed from the LCD screen image of a low-cost sensor.
    """
    value: float = Field(..., description="The numerical measurement value extracted from the LCD screen")
    unit: str = Field(..., description="The unit of measurement (e.g. %, C, pH, etc.)")
    sensor_type: str = Field(..., description="The type of the sensor: 'moisture', 'temperature', or 'ph'")
