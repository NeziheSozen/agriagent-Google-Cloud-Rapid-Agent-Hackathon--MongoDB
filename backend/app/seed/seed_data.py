"""
AgriAgent — Database Seed Script.

Populates MongoDB with rich, realistic Turkish agriculture data for
demo / hackathon purposes. Uses the **synchronous** PyMongo MongoClient
(simpler for one-off scripts).

Usage::

    python -m app.seed.seed_data

The script is **idempotent**: it drops existing collections before
inserting so it can be re-run safely at any time.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

from pymongo import MongoClient

# ── Configuration ────────────────────────────────────────────────────────
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "agriagent_db")


def _dt(year: int, month: int = 1, day: int = 15) -> datetime:
    """Shorthand to create a datetime for seed data."""
    return datetime(year, month, day)


def _recent(days_ago: int = 5) -> datetime:
    """Return a datetime *days_ago* days before now (for threat dates)."""
    return datetime.utcnow() - timedelta(days=days_ago)


# ═════════════════════════════════════════════════════════════════════════
# FARMERS COLLECTION
# ═════════════════════════════════════════════════════════════════════════
FARMERS = [{'user_id': 'farmer_001',
  'name': 'Ahmet Yılmaz',
  'location': 'Tekirdağ',
  'region': 'Thrace',
  'plots': [{'plot_id': 'plot_0a',
             'name': 'Main Field',
             'size_hectares': 50.0,
             'irrigation_level': 'Low',
             'tenure_type': 'Owned',
             'soil_analysis': {'ph': 7.2,
                               'nitrogen_ppm': 42.0,
                               'phosphorus_ppm': 18.5,
                               'potassium_ppm': 195.0,
                               'organic_matter_percent': 3.1,
                               'salinity_ds_m': 0.4,
                               'texture': 'Loamy',
                               'test_date': _dt(2025, 3, 10)},
             'crop_history': [{'year': 2021,
                               'crop': 'Barley',
                               'yield_tons_per_hectare': 4.2,
                               'profit': 85000,
                               'notes': 'Good rainfall year'},
                              {'year': 2022,
                               'crop': 'Sunflower',
                               'yield_tons_per_hectare': 2.8,
                               'profit': 120000,
                               'notes': 'High oil prices boosted profit'},
                              {'year': 2023,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 5.1,
                               'profit': 95000,
                               'notes': 'Average season'},
                              {'year': 2024,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 4.8,
                               'profit': 88000,
                               'notes': 'Consecutive wheat — slight yield drop'},
                              {'year': 2025,
                               'crop': 'Corn',
                               'yield_tons_per_hectare': 6.5,
                               'profit': 110000,
                               'notes': 'Irrigation supplemented in August'}]}],
  'created_at': _dt(2024, 1, 5)},
 {'user_id': 'farmer_002',
  'name': 'Fatma Demir',
  'location': 'Konya',
  'region': 'Central Anatolia',
  'plots': [{'plot_id': 'plot_1a',
             'name': 'Main Field',
             'size_hectares': 120.0,
             'irrigation_level': 'Medium',
             'tenure_type': 'Owned',
             'soil_analysis': {'ph': 7.8,
                               'nitrogen_ppm': 28.0,
                               'phosphorus_ppm': 12.0,
                               'potassium_ppm': 160.0,
                               'organic_matter_percent': 1.8,
                               'salinity_ds_m': 1.2,
                               'texture': 'Clay',
                               'test_date': _dt(2025, 4, 22)},
             'crop_history': [{'year': 2021,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 3.8,
                               'profit': 210000,
                               'notes': 'Drought stress in June'},
                              {'year': 2022,
                               'crop': 'Barley',
                               'yield_tons_per_hectare': 3.5,
                               'profit': 175000,
                               'notes': 'Rotation improved soil structure'},
                              {'year': 2023,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 4.2,
                               'profit': 240000,
                               'notes': 'Better rainfall than expected'},
                              {'year': 2024,
                               'crop': 'Lentil',
                               'yield_tons_per_hectare': 1.6,
                               'profit': 280000,
                               'notes': 'Excellent legume prices'},
                              {'year': 2025,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 4.0,
                               'profit': 220000,
                               'notes': 'Nitrogen-fixed soil helped'}]}],
  'created_at': _dt(2024, 2, 12)},
 {'user_id': 'farmer_003',
  'name': 'Mehmet Kaya',
  'location': 'Antalya',
  'region': 'Mediterranean',
  'plots': [{'plot_id': 'plot_3a',
             'name': 'Tomato Greenhouse',
             'size_hectares': 3.0,
             'irrigation_level': 'High',
             'tenure_type': 'Owned',
             'soil_analysis': {'ph': 6.5,
                               'nitrogen_ppm': 55.0,
                               'phosphorus_ppm': 32.0,
                               'potassium_ppm': 240.0,
                               'organic_matter_percent': 4.5,
                               'salinity_ds_m': 0.3,
                               'texture': 'Sandy',
                               'test_date': _dt(2025, 2, 8)},
             'crop_history': [{'year': 2021,
                               'crop': 'Tomato',
                               'yield_tons_per_hectare': 65.0,
                               'profit': 195000,
                               'notes': 'Greenhouse + open-field'},
                              {'year': 2022,
                               'crop': 'Cucumber',
                               'yield_tons_per_hectare': 50.0,
                               'profit': 160000,
                               'notes': 'Drip-irrigated, good quality'},
                              {'year': 2023,
                               'crop': 'Tomato',
                               'yield_tons_per_hectare': 70.0,
                               'profit': 210000,
                               'notes': 'New disease-resistant variety'},
                              {'year': 2024,
                               'crop': 'Pepper',
                               'yield_tons_per_hectare': 35.0,
                               'profit': 230000,
                               'notes': 'Export-grade bell peppers'},
                              {'year': 2025,
                               'crop': 'Tomato',
                               'yield_tons_per_hectare': 68.0,
                               'profit': 200000,
                               'notes': 'Tuta absoluta pressure managed'}]},
            {'plot_id': 'plot_3b',
             'name': 'Citrus Orchard',
             'size_hectares': 12.0,
             'irrigation_level': 'Medium',
             'tenure_type': 'Rented',
             'soil_analysis': None,
             'crop_history': [{'year': 2021,
                               'crop': 'Lemon',
                               'yield_tons_per_hectare': 20.0,
                               'profit': 80000,
                               'notes': 'Initial yield'},
                              {'year': 2022,
                               'crop': 'Lemon',
                               'yield_tons_per_hectare': 22.0,
                               'profit': 85000,
                               'notes': ''},
                              {'year': 2023,
                               'crop': 'Lemon',
                               'yield_tons_per_hectare': 25.0,
                               'profit': 95000,
                               'notes': ''},
                              {'year': 2024,
                               'crop': 'Lemon',
                               'yield_tons_per_hectare': 28.0,
                               'profit': 110000,
                               'notes': ''},
                              {'year': 2025,
                               'crop': 'Lemon',
                               'yield_tons_per_hectare': 30.0,
                               'profit': 120000,
                               'notes': 'Mature trees'}]}],
  'created_at': _dt(2024, 1, 20)},
 {'user_id': 'farmer_004',
  'name': 'Ayşe Çelik',
  'location': 'Adana',
  'region': 'Çukurova',
  'plots': [{'plot_id': 'plot_3a',
             'name': 'Main Field',
             'size_hectares': 80.0,
             'irrigation_level': 'Medium',
             'tenure_type': 'Owned',
             'soil_analysis': {'ph': 7.0,
                               'nitrogen_ppm': 38.0,
                               'phosphorus_ppm': 22.0,
                               'potassium_ppm': 210.0,
                               'organic_matter_percent': 2.9,
                               'salinity_ds_m': 0.6,
                               'texture': 'Silty',
                               'test_date': _dt(2025, 5, 3)},
             'crop_history': [{'year': 2021,
                               'crop': 'Cotton',
                               'yield_tons_per_hectare': 4.5,
                               'profit': 320000,
                               'notes': 'Strong export demand'},
                              {'year': 2022,
                               'crop': 'Corn',
                               'yield_tons_per_hectare': 9.0,
                               'profit': 250000,
                               'notes': 'Second-crop corn after wheat'},
                              {'year': 2023,
                               'crop': 'Cotton',
                               'yield_tons_per_hectare': 4.8,
                               'profit': 350000,
                               'notes': 'Premium fiber quality'},
                              {'year': 2024,
                               'crop': 'Corn',
                               'yield_tons_per_hectare': 8.5,
                               'profit': 230000,
                               'notes': 'Fall armyworm pressure'},
                              {'year': 2025,
                               'crop': 'Cotton',
                               'yield_tons_per_hectare': 4.6,
                               'profit': 340000,
                               'notes': 'Integrated pest management applied'}]}],
  'created_at': _dt(2024, 3, 1)},
 {'user_id': 'farmer_005',
  'name': 'Ali Öztürk',
  'location': 'Edirne',
  'region': 'Thrace',
  'plots': [{'plot_id': 'plot_4a',
             'name': 'Main Field',
             'size_hectares': 200.0,
             'irrigation_level': 'Low',
             'tenure_type': 'Owned',
             'soil_analysis': {'ph': 7.4,
                               'nitrogen_ppm': 35.0,
                               'phosphorus_ppm': 15.0,
                               'potassium_ppm': 180.0,
                               'organic_matter_percent': 2.6,
                               'salinity_ds_m': 0.5,
                               'texture': 'Loamy',
                               'test_date': _dt(2025, 4, 15)},
             'crop_history': [{'year': 2021,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 5.0,
                               'profit': 420000,
                               'notes': 'Scale advantage on costs'},
                              {'year': 2022,
                               'crop': 'Sunflower',
                               'yield_tons_per_hectare': 3.0,
                               'profit': 380000,
                               'notes': 'Global sunflower shortage'},
                              {'year': 2023,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 5.3,
                               'profit': 450000,
                               'notes': 'Precision agriculture pilot'},
                              {'year': 2024,
                               'crop': 'Sunflower',
                               'yield_tons_per_hectare': 2.7,
                               'profit': 350000,
                               'notes': 'Downy mildew affected 10% area'},
                              {'year': 2025,
                               'crop': 'Wheat',
                               'yield_tons_per_hectare': 5.5,
                               'profit': 480000,
                               'notes': 'Best yield in 5 years'}]}],
  'created_at': _dt(2024, 2, 28)}]


# ═════════════════════════════════════════════════════════════════════════
# CLIMATE TRENDS COLLECTION
# ═════════════════════════════════════════════════════════════════════════
CLIMATE_TRENDS = [
    {
        "location": "Tekirdağ",
        "region": "Thrace",
        "historical": [
            {"year": 2021, "avg_spring_rainfall_mm": 320.0, "avg_summer_temp_celsius": 26.0, "drought_days": 25, "frost_days": 18},
            {"year": 2022, "avg_spring_rainfall_mm": 305.0, "avg_summer_temp_celsius": 26.5, "drought_days": 30, "frost_days": 15},
            {"year": 2023, "avg_spring_rainfall_mm": 295.0, "avg_summer_temp_celsius": 27.0, "drought_days": 33, "frost_days": 12},
            {"year": 2024, "avg_spring_rainfall_mm": 285.0, "avg_summer_temp_celsius": 27.5, "drought_days": 38, "frost_days": 10},
            {"year": 2025, "avg_spring_rainfall_mm": 275.0, "avg_summer_temp_celsius": 28.0, "drought_days": 42, "frost_days": 8},
        ],
        "forecast": {
            "season": "2026 Summer",
            "predicted_rainfall_mm": 260.0,
            "predicted_avg_temp_celsius": 28.5,
            "drought_risk": "Medium",
            "trend_summary": "Spring rainfall has declined ~14% over 5 years while summer temperatures rose 2°C. Drought days increasing steadily. Recommend drought-tolerant varieties and conservation tillage.",
        },
        "analysis_notes": "Thrace shows a clear warming and drying trend consistent with climate models for southeastern Europe. The 2026 season may require supplemental irrigation for crops like sunflower that were historically rain-fed.",
    },
    {
        "location": "Konya",
        "region": "Central Anatolia",
        "historical": [
            {"year": 2021, "avg_spring_rainfall_mm": 180.0, "avg_summer_temp_celsius": 28.0, "drought_days": 45, "frost_days": 35},
            {"year": 2022, "avg_spring_rainfall_mm": 165.0, "avg_summer_temp_celsius": 29.0, "drought_days": 50, "frost_days": 32},
            {"year": 2023, "avg_spring_rainfall_mm": 155.0, "avg_summer_temp_celsius": 29.5, "drought_days": 55, "frost_days": 28},
            {"year": 2024, "avg_spring_rainfall_mm": 148.0, "avg_summer_temp_celsius": 30.0, "drought_days": 60, "frost_days": 25},
            {"year": 2025, "avg_spring_rainfall_mm": 140.0, "avg_summer_temp_celsius": 30.5, "drought_days": 65, "frost_days": 22},
        ],
        "forecast": {
            "season": "2026 Summer",
            "predicted_rainfall_mm": 130.0,
            "predicted_avg_temp_celsius": 31.0,
            "drought_risk": "Critical",
            "trend_summary": "Severe drying trend — rainfall down 22% in 5 years and drought days increased by 44%. Critical water stress expected. Pivot to drought-hardy crops like chickpea and lentil.",
        },
        "analysis_notes": "Konya basin aquifer levels dropping alarmingly. Central Anatolia is Turkey's bread basket but faces existential climate pressure. Shift from wheat monoculture to legume-cereal rotations is essential.",
    },
    {
        "location": "Antalya",
        "region": "Mediterranean",
        "historical": [
            {"year": 2021, "avg_spring_rainfall_mm": 420.0, "avg_summer_temp_celsius": 30.0, "drought_days": 15, "frost_days": 2},
            {"year": 2022, "avg_spring_rainfall_mm": 415.0, "avg_summer_temp_celsius": 30.5, "drought_days": 18, "frost_days": 1},
            {"year": 2023, "avg_spring_rainfall_mm": 410.0, "avg_summer_temp_celsius": 31.0, "drought_days": 20, "frost_days": 0},
            {"year": 2024, "avg_spring_rainfall_mm": 400.0, "avg_summer_temp_celsius": 31.5, "drought_days": 22, "frost_days": 0},
            {"year": 2025, "avg_spring_rainfall_mm": 395.0, "avg_summer_temp_celsius": 32.0, "drought_days": 25, "frost_days": 0},
        ],
        "forecast": {
            "season": "2026 Summer",
            "predicted_rainfall_mm": 385.0,
            "predicted_avg_temp_celsius": 32.5,
            "drought_risk": "Low",
            "trend_summary": "Mediterranean climate remains relatively stable with adequate rainfall. Warming winters reduce frost risk but may increase pest pressure year-round. Greenhouse production remains optimal.",
        },
        "analysis_notes": "Antalya benefits from maritime moisture but rising summer temperatures increase evapotranspiration. Drip irrigation efficiency is critical. Year-round growing season enables high-value horticulture.",
    },
    {
        "location": "Adana",
        "region": "Çukurova",
        "historical": [
            {"year": 2021, "avg_spring_rainfall_mm": 350.0, "avg_summer_temp_celsius": 32.0, "drought_days": 20, "frost_days": 5},
            {"year": 2022, "avg_spring_rainfall_mm": 340.0, "avg_summer_temp_celsius": 32.5, "drought_days": 22, "frost_days": 3},
            {"year": 2023, "avg_spring_rainfall_mm": 345.0, "avg_summer_temp_celsius": 33.0, "drought_days": 25, "frost_days": 2},
            {"year": 2024, "avg_spring_rainfall_mm": 335.0, "avg_summer_temp_celsius": 33.5, "drought_days": 28, "frost_days": 2},
            {"year": 2025, "avg_spring_rainfall_mm": 330.0, "avg_summer_temp_celsius": 34.0, "drought_days": 30, "frost_days": 1},
        ],
        "forecast": {
            "season": "2026 Summer",
            "predicted_rainfall_mm": 320.0,
            "predicted_avg_temp_celsius": 34.5,
            "drought_risk": "Medium",
            "trend_summary": "Moderate drying with significant summer heat increase (+2°C in 5yr). Cotton heat tolerance helps but bollworm pressure rises with warmth. Humidity increasing coastal pest risk.",
        },
        "analysis_notes": "Çukurova plain remains one of Turkey's most productive regions but faces heat stress and emerging pest challenges. Cotton-corn rotation is well-adapted but margins are tightening.",
    },
]


# ═════════════════════════════════════════════════════════════════════════
# REGIONAL THREATS COLLECTION
# ═════════════════════════════════════════════════════════════════════════
REGIONAL_THREATS = [
    {
        "region": "Thrace",
        "active_threats": [
            {
                "threat_name": "Sunflower Downy Mildew",
                "threat_name_tr": "Ayçiçeği Mildiyösü",
                "threat_type": "Disease",
                "affected_crops": ["Sunflower"],
                "severity": "High",
                "source_location": "Edirne",
                "reported_date": _recent(7),
                "spread_risk_to_neighbors": 0.75,
                "description": "Plasmopara halstedii detected in Edirne sunflower fields. Fungal spores spread via wind and rain splash. Use resistant hybrids and apply metalaxyl-M seed treatments. Affected area: ~15% of Thrace sunflower fields.",
            },
            {
                "threat_name": "Wheat Rust",
                "threat_name_tr": "Buğday Pası",
                "threat_type": "Disease",
                "affected_crops": ["Wheat", "Barley"],
                "severity": "Medium",
                "source_location": "Tekirdağ",
                "reported_date": _recent(12),
                "spread_risk_to_neighbors": 0.60,
                "description": "Yellow rust (Puccinia striiformis) confirmed in western Tekirdağ wheat fields. Apply foliar fungicide (tebuconazole) at first symptom. Monitor neighbouring barley fields.",
            },
        ],
    },
    {
        "region": "Central Anatolia",
        "active_threats": [
            {
                "threat_name": "Sunn Pest",
                "threat_name_tr": "Süne",
                "threat_type": "Pest",
                "affected_crops": ["Wheat", "Barley"],
                "severity": "Critical",
                "source_location": "Konya",
                "reported_date": _recent(3),
                "spread_risk_to_neighbors": 0.85,
                "description": "Eurygaster integriceps populations exceeding economic threshold (4 adults/m²) in Konya and Aksaray. Aerial spraying authorised by Provincial Directorate. Sunn pest degrades grain protein, causing severe quality loss. Coordinate with neighbours for area-wide control.",
            },
            {
                "threat_name": "Wheat Stem Sawfly",
                "threat_name_tr": "Buğday Sap Arıcığı",
                "threat_type": "Pest",
                "affected_crops": ["Wheat"],
                "severity": "Medium",
                "source_location": "Eskişehir",
                "reported_date": _recent(10),
                "spread_risk_to_neighbors": 0.45,
                "description": "Cephus pygmaeus larvae found tunnelling in wheat stems near Eskişehir. Solid-stemmed wheat varieties show resistance. Harvest at optimal moisture to reduce lodging losses.",
            },
        ],
    },
    {
        "region": "Mediterranean",
        "active_threats": [
            {
                "threat_name": "Tomato Leafminer",
                "threat_name_tr": "Domates Güvesi (Tuta absoluta)",
                "threat_type": "Invasive",
                "affected_crops": ["Tomato", "Pepper", "Eggplant"],
                "severity": "High",
                "source_location": "Antalya",
                "reported_date": _recent(5),
                "spread_risk_to_neighbors": 0.80,
                "description": "Tuta absoluta activity spiking in Antalya greenhouses and open fields. Deploy pheromone traps (delta type, 40/ha) for monitoring. Use Bacillus thuringiensis (Bt) and release Nesidiocoris tenuis as biological control. Remove and destroy infested leaves.",
            },
            {
                "threat_name": "Citrus Greening",
                "threat_name_tr": "Turunçgil Yeşillenme Hastalığı",
                "threat_type": "Disease",
                "affected_crops": ["Orange", "Lemon", "Mandarin"],
                "severity": "Medium",
                "source_location": "Mersin",
                "reported_date": _recent(15),
                "spread_risk_to_neighbors": 0.55,
                "description": "Candidatus Liberibacter asiaticus suspected in Mersin citrus orchards — PCR confirmation pending. Asian citrus psyllid (Diaphorina citri) vector detected. Quarantine protocols activated. Remove symptomatic trees and apply systemic insecticides.",
            },
        ],
    },
    {
        "region": "Çukurova",
        "active_threats": [
            {
                "threat_name": "Cotton Bollworm",
                "threat_name_tr": "Pamuk Kurtçuğu",
                "threat_type": "Pest",
                "affected_crops": ["Cotton", "Corn", "Tomato"],
                "severity": "High",
                "source_location": "Adana",
                "reported_date": _recent(4),
                "spread_risk_to_neighbors": 0.70,
                "description": "Helicoverpa armigera trap counts exceeding threshold in Adana cotton fields. Apply chlorantraniliprole at egg-hatch stage. Use Bt cotton varieties where available. Corn refuge strategy recommended for resistance management.",
            },
            {
                "threat_name": "Fall Armyworm",
                "threat_name_tr": "Sonbahar Tırtılı",
                "threat_type": "Invasive",
                "affected_crops": ["Corn", "Sorghum", "Cotton"],
                "severity": "Critical",
                "source_location": "Hatay",
                "reported_date": _recent(2),
                "spread_risk_to_neighbors": 0.90,
                "description": "Spodoptera frugiperda confirmed in second-crop corn in Hatay and spreading north to Adana. This invasive species from the Americas can devastate corn yields by 40-70%. Scout fields at dawn/dusk. Apply emamectin benzoate or spinetoram. Report sightings to the Ministry of Agriculture.",
            },
        ],
    },
]


# ═════════════════════════════════════════════════════════════════════════
# MARKET DATA COLLECTION
# ═════════════════════════════════════════════════════════════════════════
MARKET_DATA = [
    {
        "crop": "Canola",
        "current_price_per_ton": 18500.0,
        "predicted_harvest_price_per_ton": 21000.0,
        "price_trend": "Rising",
        "confidence_percent": 78.0,
        "volatility": "Medium",
        "global_demand_signal": "EU biodiesel mandate driving strong canola/rapeseed demand. Turkish crush margins favourable.",
    },
    {
        "crop": "Sunflower",
        "current_price_per_ton": 14200.0,
        "predicted_harvest_price_per_ton": 12800.0,
        "price_trend": "Falling",
        "confidence_percent": 72.0,
        "volatility": "High",
        "global_demand_signal": "Ukraine sunflower exports recovering post-conflict, increasing global supply. Turkish domestic surplus expected.",
    },
    {
        "crop": "Wheat",
        "current_price_per_ton": 9500.0,
        "predicted_harvest_price_per_ton": 10200.0,
        "price_trend": "Stable",
        "confidence_percent": 85.0,
        "volatility": "Low",
        "global_demand_signal": "Global wheat stocks adequate. TMO (Turkish Grain Board) floor price provides stability. Minor upside from quality premiums.",
    },
    {
        "crop": "Chickpea",
        "current_price_per_ton": 32000.0,
        "predicted_harvest_price_per_ton": 35500.0,
        "price_trend": "Rising",
        "confidence_percent": 70.0,
        "volatility": "Medium",
        "global_demand_signal": "India and Middle East demand rising. Turkey is a key exporter. Drought in Australian crops tightening global supply.",
    },
    {
        "crop": "Corn",
        "current_price_per_ton": 7800.0,
        "predicted_harvest_price_per_ton": 7200.0,
        "price_trend": "Falling",
        "confidence_percent": 75.0,
        "volatility": "Medium",
        "global_demand_signal": "Record US and Brazilian corn harvests pushing global prices down. Turkish feed industry well-supplied.",
    },
    {
        "crop": "Lentil",
        "current_price_per_ton": 28000.0,
        "predicted_harvest_price_per_ton": 30000.0,
        "price_trend": "Rising",
        "confidence_percent": 68.0,
        "volatility": "Medium",
        "global_demand_signal": "Plant-based protein trend sustaining demand. Canadian lentil crop below average. Turkish red lentil commands premium.",
    },
    {
        "crop": "Cotton",
        "current_price_per_ton": 22000.0,
        "predicted_harvest_price_per_ton": 23500.0,
        "price_trend": "Rising",
        "confidence_percent": 74.0,
        "volatility": "High",
        "global_demand_signal": "Textile sector recovery in Asia. Turkish Aegean cotton premium quality sought by European mills. Supply constrained by water limits.",
    },
    {
        "crop": "Barley",
        "current_price_per_ton": 8200.0,
        "predicted_harvest_price_per_ton": 8500.0,
        "price_trend": "Stable",
        "confidence_percent": 82.0,
        "volatility": "Low",
        "global_demand_signal": "Steady demand from feed and malt sectors. No major supply disruptions expected. Saudi Arabia tender purchases provide floor.",
    },
    {
        "crop": "Soybean",
        "current_price_per_ton": 16000.0,
        "predicted_harvest_price_per_ton": 18500.0,
        "price_trend": "Rising",
        "confidence_percent": 65.0,
        "volatility": "High",
        "global_demand_signal": "Turkey heavily import-dependent on soy. Government incentives for domestic production increasing. Crush margin attractive.",
    },
    {
        "crop": "Tomato",
        "current_price_per_ton": 5500.0,
        "predicted_harvest_price_per_ton": 4800.0,
        "price_trend": "Falling",
        "confidence_percent": 80.0,
        "volatility": "High",
        "global_demand_signal": "Peak-season oversupply expected in Antalya and Mersin. Processing factories at capacity. Export to Russia stable but price-sensitive.",
    },
    {
        "crop": "Pepper",
        "current_price_per_ton": 12000.0,
        "predicted_harvest_price_per_ton": 13000.0,
        "price_trend": "Stable",
        "confidence_percent": 76.0,
        "volatility": "Medium",
        "global_demand_signal": "Domestic consumption strong. EU fresh pepper imports from Turkey growing. Quality premiums for greenhouse-grown peppers.",
    },
    {
        "crop": "Sugar Beet",
        "current_price_per_ton": 3200.0,
        "predicted_harvest_price_per_ton": 3400.0,
        "price_trend": "Stable",
        "confidence_percent": 90.0,
        "volatility": "Low",
        "global_demand_signal": "Regulated market — Turkish Sugar Authority sets quota and floor price. Minimal volatility expected. Contract farming ensures stable returns.",
    },
    {
        "crop": "Lettuce",
        "current_price_per_ton": 4500.0,
        "predicted_harvest_price_per_ton": 4800.0,
        "price_trend": "Stable",
        "confidence_percent": 82.0,
        "volatility": "High",
        "global_demand_signal": "High demand in local markets (pazar) and supermarkets. Sensitive to sudden weather changes like frost.",
    },
    {
        "crop": "Curly Lettuce",
        "current_price_per_ton": 5200.0,
        "predicted_harvest_price_per_ton": 5000.0,
        "price_trend": "Falling",
        "confidence_percent": 75.0,
        "volatility": "High",
        "global_demand_signal": "Slight oversupply expected in spring. Good for greenhouse rotation. Local fast food and restaurant demand is steady.",
    },
    {
        "crop": "Broad Bean",
        "current_price_per_ton": 14000.0,
        "predicted_harvest_price_per_ton": 15500.0,
        "price_trend": "Rising",
        "confidence_percent": 68.0,
        "volatility": "Medium",
        "global_demand_signal": "Early season harvest captures premium prices. Excellent nitrogen fixer for small soil plots.",
    },
    {
        "crop": "Green Bean",
        "current_price_per_ton": 18000.0,
        "predicted_harvest_price_per_ton": 17500.0,
        "price_trend": "Stable",
        "confidence_percent": 80.0,
        "volatility": "Medium",
        "global_demand_signal": "Staple vegetable with strong fresh market demand and canning factory contracts.",
    },
]


# ═════════════════════════════════════════════════════════════════════════
# SEEDING LOGIC
# ═════════════════════════════════════════════════════════════════════════
def seed() -> None:
    """Drop, insert, and index all collections."""
    print("🌱 Connecting to MongoDB ...")
    client = MongoClient(MONGODB_URL)
    db = client[DATABASE_NAME]

    # ── Drop existing data (idempotent) ──────────────────────────────────
    print("🗑️  Dropping existing collections ...")
    db.farmers.drop()
    db.climate_trends.drop()
    db.regional_threats.drop()
    db.market_data.drop()
    db.strategy_reports.drop()

    # ── Insert farmers ───────────────────────────────────────────────────
    db.farmers.insert_many(FARMERS)
    print(f"👨‍🌾 Inserted {len(FARMERS)} farmer profiles")

    # ── Insert climate trends ────────────────────────────────────────────
    db.climate_trends.insert_many(CLIMATE_TRENDS)
    print(f"🌤️  Inserted {len(CLIMATE_TRENDS)} climate trend documents")

    # ── Insert regional threats ──────────────────────────────────────────
    db.regional_threats.insert_many(REGIONAL_THREATS)
    print(f"🐛 Inserted {len(REGIONAL_THREATS)} regional threat documents")

    # ── Insert market data ───────────────────────────────────────────────
    db.market_data.insert_many(MARKET_DATA)
    print(f"📈 Inserted {len(MARKET_DATA)} market data entries")

    # ── Create indexes ───────────────────────────────────────────────────
    print("📇 Creating indexes ...")
    db.farmers.create_index("user_id", unique=True)
    db.farmers.create_index("region")
    db.climate_trends.create_index("location", unique=True)
    db.climate_trends.create_index("region")
    db.regional_threats.create_index("region")
    db.regional_threats.create_index("active_threats.reported_date")
    db.market_data.create_index("crop", unique=True)
    db.strategy_reports.create_index([("user_id", 1), ("created_at", -1)])
    db.cooperatives.create_index("coop_id", unique=True)
    db.cooperatives.create_index("join_code", unique=True)
    db.cooperatives.create_index("region")
    db.fleet_bookings.create_index([("machine_id", 1), ("date", 1)], unique=True)

    # ── Insert cooperative seed data ─────────────────────────────────────
    print("🤝 Seeding cooperative data ...")
    db.cooperatives.drop()
    db.fleet_bookings.drop()
    db.cooperatives.insert_one({
        "coop_id": "coop_tekirdag_001",
        "name": "Tekirdağ Farmer Sharing Network",
        "region": "Tekirdağ",
        "description": "Voluntary sharing network for grain and oilseed producers in the Tekirdağ region",
        "coop_type": "collective",
        "member_ids": ["farmer_001"],
        "machines": [
            {
                "machine_id": "m001",
                "name": "Pneumatic Seeder",
                "type": "seeder",
                "owner_id": "farmer_001",
                "owner_name": "Nezihe Sözen",
                "shared": True,
                "daily_rental_cost": 2500,
                "status": "active",
                "ownership_type": "individual",
            },
            {
                "machine_id": "m002",
                "name": "Combine Harvester",
                "type": "harvester",
                "owner_id": "farmer_001",
                "owner_name": "Nezihe Sözen",
                "shared": True,
                "daily_rental_cost": 5000,
                "status": "active",
                "ownership_type": "individual",
            },
            {
                "machine_id": "m003",
                "name": "Field Sprayer",
                "type": "sprayer",
                "owner_id": "farmer_001",
                "owner_name": "Nezihe Sözen",
                "shared": False,
                "daily_rental_cost": 1500,
                "status": "active",
                "ownership_type": "individual",
            },
            {
                "machine_id": "m004",
                "name": "Tractor (65 HP)",
                "type": "tractor",
                "owner_id": "cooperative",
                "owner_name": "Tekirdağ Farmer Sharing Network",
                "shared": True,
                "daily_rental_cost": 3000,
                "status": "active",
                "ownership_type": "cooperative",
            },
        ],
        "admin_id": "farmer_001",
        "join_code": "TKR-482",
        "created_at": datetime.now(timezone.utc).isoformat(),
    })
    print("🤝 Inserted 1 cooperative with 4 machines")

    # Update farmer_001 with cooperative info
    db.farmers.update_one(
        {"user_id": "farmer_001"},
        {"$set": {
            "cooperative_id": "coop_tekirdag_001",
            "cooperative_name": "Tekirdağ Farmer Sharing Network",
        }},
    )
    print("👨‍🌾 Updated farmer_001 with cooperative membership")

    print("✅ Seed complete! Collections:")
    for name in sorted(db.list_collection_names()):
        count = db[name].count_documents({})
        print(f"   📦 {name}: {count} documents")

    client.close()
    print("🏁 Done — MongoDB seeded for AgriAgent!")


if __name__ == "__main__":
    seed()
