import json
import uuid

import logging
from pydantic import BaseModel, Field
from pymongo.asynchronous.database import AsyncDatabase
from app.models.market import MarketForecast
from app.agents.llm_utils import get_genai_client, generate_json_response
from app.agents.agronomist_agent import AgronomistOutput
from app.agents.coop_agent import CoopOutput
from app.agents.policy_agent import get_policy_grants

logger = logging.getLogger(__name__)

class FinancialCropOption(BaseModel):
    crop: str = Field(description="Name of the crop")
    expected_yield_tons_per_hectare: float = Field(description="Expected yield passed from agronomist")
    estimated_revenue: float = Field(description="Calculated expected revenue in USD")
    estimated_cost: float = Field(description="Calculated expected CapEx/OpEx cost in USD")
    estimated_profit: float = Field(description="Calculated expected profit in USD")
    financial_risk_score: float = Field(description="Financial risk score (0-10)")
    financial_notes: str = Field(description="Notes on market trends and profitability")

class EconomistOutput(BaseModel):
    market_outlook: str = Field(description="Analysis of market prices and subsidy impact")
    financial_ranking: list[FinancialCropOption] = Field(description="The 3 crops evaluated and ranked by financial ROI")

async def analyze_finance(
    db: AsyncDatabase,
    farmer_data: dict,
    agronomist_data: AgronomistOutput,
    coop_data: CoopOutput,
    market: MarketForecast | None
) -> EconomistOutput:
    """
    Economist Agent: Analyzes market prices, costs, and subsidies using ADK.
    Integrates with the CoopAgent's negotiated discounts and Policy RAG.
    """
    from google.adk.agents.llm_agent import LlmAgent
    from google.adk import Runner
    from google.adk.sessions.in_memory_session_service import InMemorySessionService
    
    logger.info("💰 Economist Agent (ADK) starting financial analysis...")

    # 1. Prepare Context
    lang = farmer_data.get('language', 'tr')
    crops_to_evaluate = [c.crop for c in agronomist_data.top_3_crops]
    
    # Calculate total farm size
    plots = farmer_data.get('plots', [])
    total_hectares = sum(p.get('size_hectares', 0) if isinstance(p, dict) else getattr(p, 'size_hectares', 0) for p in plots)
    if total_hectares == 0:
        total_hectares = 1.0  # Default to 1 ha if not specified
    
    agronomist_context = ""
    for c in agronomist_data.top_3_crops:
        agronomist_context += f"- Crop: {c.crop}, Expected Yield: {c.expected_yield_tons_per_hectare} tons/ha, Biological Risk: {c.biological_risk_score}/10\n"
        
    market_context = "No market data available."
    if market:
        market_list = []
        for p in market.predictions:
            # We lowercase both for robust matching (e.g. "Salatalık" == "salatalık")
            if p.crop.lower() in [c.lower() for c in crops_to_evaluate]:
                # Price is current market price per ton. 
                # Provide it to the economist so they can calculate revenue (Yield x Price)
                market_list.append(f"{p.crop}: Live Market Price = {p.price_today_per_ton} USD/ton")
        if market_list:
            market_context = "\n".join(market_list)

    region = farmer_data.get('region', 'Unknown')
    age = farmer_data.get('age', 45)
    gender = farmer_data.get('gender', 'Prefer not to say')

    # 2. Fetch Policy RAG Data (MongoDB Vector Search)
    grants_context = await get_policy_grants(db, region, age, crops_to_evaluate, gender)
    
    # 3. Use Co-op Synergy Data from CoopAgent
    coop_context = f"{coop_data.synergy_analysis}\nB2B Discount Rate: %{coop_data.negotiated_discount_percent}"

    location = farmer_data.get('location', 'Unknown')
    country = farmer_data.get('country', '')
    
    # Determine currency code based on country
    _country_currencies = {
        'Turkey': 'TRY', 'Türkiye': 'TRY',
        'United States': 'USD', 'USA': 'USD',
        'Germany': 'EUR', 'France': 'EUR', 'Italy': 'EUR', 'Spain': 'EUR', 'Netherlands': 'EUR',
        'United Kingdom': 'GBP', 'UK': 'GBP',
        'India': 'INR', 'Brazil': 'BRL', 'Mexico': 'MXN',
        'Japan': 'JPY', 'China': 'CNY', 'South Korea': 'KRW',
        'Canada': 'CAD', 'Australia': 'AUD',
        'Egypt': 'EGP', 'Nigeria': 'NGN', 'Kenya': 'KES', 'South Africa': 'ZAR',
        'Pakistan': 'PKR', 'Bangladesh': 'BDT', 'Indonesia': 'IDR',
        'Argentina': 'ARS', 'Colombia': 'COP', 'Chile': 'CLP', 'Peru': 'PEN',
        'Russia': 'RUB', 'Ukraine': 'UAH', 'Poland': 'PLN',
        'Thailand': 'THB', 'Vietnam': 'VND', 'Philippines': 'PHP', 'Malaysia': 'MYR',
        'Morocco': 'MAD', 'Tunisia': 'TND', 'Algeria': 'DZD',
        'Iran': 'IRR', 'Iraq': 'IQD', 'Saudi Arabia': 'SAR', 'UAE': 'AED',
        'Israel': 'ILS', 'Ethiopia': 'ETB', 'Tanzania': 'TZS', 'Ghana': 'GHS',
    }
    # Try to detect from country field first, then from location string
    currency_code = 'USD'
    if country:
        currency_code = _country_currencies.get(country, 'USD')
    else:
        # Try matching location string against known country names
        loc_lower = location.lower()
        for c_name, c_code in _country_currencies.items():
            if c_name.lower() in loc_lower:
                currency_code = c_code
                break

    farmer_context = f"Farmer: {farmer_data.get('name', 'Unknown')}, Location: {location}, Region: {region}, Total Farm Size: {total_hectares} hectares, Currency: {currency_code}"

    # 4. Build Agent Instruction
    instruction = f"""You are an expert Agricultural Economist Agent.
Analyze the agronomic options provided by the Agronomist Agent, cross-reference with live market prices, and strictly output JSON.
CRITICAL REQUIREMENT: You MUST write the ENTIRE report and all text fields in the language with code '{lang}' (e.g. if 'tr' then Turkish, if 'en' then English).

DATA:
--- FARMER INFO ---
{farmer_context}

--- AGRONOMIST AGENT APPROVED CROPS AND EXPECTED YIELDS ---
{agronomist_context}

--- MARKET PRICE FORECASTS (USD) ---
{market_context}

--- GOVERNMENT SUBSIDIES AND GRANTS (POLICY RAG) ---
{grants_context}

--- COLLECTIVE PURCHASING / COOPERATIVE (AGGREGATION ENGINE) ---
{coop_context}

--- PRODUCTION COST REFERENCE (USD per hectare, Global Averages) ---
Use these baseline costs to estimate total cost per hectare. These include seeds, fertilizer, pesticides, labor, irrigation, and machinery:
Wheat: 520 USD/ha | Barley: 460 USD/ha | Corn: 720 USD/ha | Sunflower: 430 USD/ha | Canola: 400 USD/ha
Cotton: 1,290 USD/ha | Chickpea: 340 USD/ha | Lentil: 320 USD/ha | Soybean: 570 USD/ha
Tomato: 2,430 USD/ha | Pepper: 2,140 USD/ha | Cucumber: 2,000 USD/ha | Eggplant: 1,720 USD/ha
Strawberry: 3,430 USD/ha | Raspberry: 2,720 USD/ha | Blueberry: 3,140 USD/ha
Green Bean: 1,000 USD/ha | Potato: 1,140 USD/ha | Onion: 860 USD/ha | Garlic: 1,000 USD/ha
Lettuce: 1,290 USD/ha | Spinach: 720 USD/ha | Cabbage: 800 USD/ha | Carrot: 860 USD/ha
Zucchini: 1,140 USD/ha | Watermelon: 570 USD/ha | Melon: 630 USD/ha
Grape: 1,000 USD/ha | Cherry: 1,290 USD/ha | Peach: 1,140 USD/ha | Pear: 1,090 USD/ha
Apple: 1,430 USD/ha | Orange: 1,140 USD/ha | Lemon: 1,090 USD/ha
Olive: 720 USD/ha | Walnut: 860 USD/ha | Hazelnut: 800 USD/ha | Almond: 920 USD/ha
Fig: 570 USD/ha | Pomegranate: 860 USD/ha | Apricot: 1,000 USD/ha
Tea: 1,140 USD/ha | Sugar Beet: 630 USD/ha | Asparagus: 1,570 USD/ha
For crops not listed, estimate cost as 60% of expected revenue.

## Intercropping Revenue Analysis
- If the field has young trees (tree_age < 5) and intercropping is recommended:
  - Add the estimated revenue of the intercrop to annual cash flow
  - Example: "Walnut will reach commercial yield in year 5. Until then, strawberries planted between trees can provide ~15,000 USD/hectare annual revenue."
  - Calculate the main tree's break-even year and total intercropping revenue until then

## Rented Land Cost Analysis
- If the land is rented (tenure_type == 'Rented'):
  - Add rental_cost to annual expenses
  - If lease_end_date is near (<2 years): Long-term investments (saplings, soil improvement) are NOT RECOMMENDED
  - Recommend short-term crops with fast ROI (contract farming, annual plants)
  - Include rental cost in break-even calculation
  - Present in the format: "Net profit including rental cost: X {currency_code}/hectare"

TASKS:
1. Financially evaluate the {len(crops_to_evaluate)} crops sent by the Agronomist Agent.
2. Estimate expected yield (tons/ha) for the farmer's location.
3. Calculate estimated revenue: Use the global market price as a reference, but YOU MUST ADJUST it to reflect the real local wholesale market price in the farmer's country/location ({location}). Calculate total revenue directly in {currency_code}. Do NOT just do a blind currency exchange.
4. Calculate estimated cost: Use the baseline USD table as a reference, but YOU MUST ADJUST it to reflect the real local economic conditions in {location} (accounting for local labor, fuel, and fertilizer costs). Deduct the negotiated cooperative discount from costs. Calculate total cost directly in {currency_code}. Do NOT just do a blind currency exchange.
5. Calculate estimated profit = revenue - cost. Reflect local grants and subsidies.
6. Rank these crops by financial RETURN (highest profit first).
CRITICAL: estimated_revenue, estimated_cost, and estimated_profit MUST ALL be non-zero positive numbers IN {currency_code} reflecting LOCAL market realities in {location}. NEVER return 0 for cost or profit.
"""

    # 5. Create ADK LlmAgent
    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="EconomistAgent",
        instruction=instruction,
        output_schema=EconomistOutput
    )

    # 6. Run the Agent
    session_service = InMemorySessionService()
    session_id = f"economist_{uuid.uuid4().hex[:8]}"
    await session_service.create_session(app_name="AgriAgent", user_id="system", session_id=session_id)
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    final_text = ""
    from google.genai import types
    msg = types.Content(role='user', parts=[types.Part.from_text(text="Please generate the financial analysis in JSON format.")])
    async for event in runner.run_async(user_id="system", session_id=session_id, new_message=msg):
        if hasattr(event, "content") and event.content:
            for p in event.content.parts:
                if hasattr(p, "text") and p.text:
                    final_text += p.text
            
    if final_text:

        try:
            clean_text = final_text.strip()
            if clean_text.startswith("```json"):
                clean_text = clean_text[7:]
            if clean_text.endswith("```"):
                clean_text = clean_text[:-3]
            
            data_dict = json.loads(clean_text.strip())
            final_output = EconomistOutput(**data_dict)
            logger.info("💰 Economist Agent (ADK) completed analysis successfully.")
            return final_output
        except Exception as e:
            logger.error(f"💰 Economist Agent JSON parse error: {e}")
        
    logger.error("💰 Economist Agent (ADK) failed to produce structured output.")
    return EconomistOutput(
        market_outlook="Data could not be retrieved.",
        financial_ranking=[]
    )
