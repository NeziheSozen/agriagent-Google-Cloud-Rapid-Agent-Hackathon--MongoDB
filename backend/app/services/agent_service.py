"""
Agent orchestration service — the "brain" of AgriAgent.

Coordinates all data sources (farmer profile, climate, threats, market,
satellite) and feeds them to Gemini AI to generate comprehensive
strategy reports.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from pymongo.asynchronous.database import AsyncDatabase

from app.models.report import StrategyReport
from app.services import (
    climate_service,
    farmer_service,
    market_service,
    report_service,
    satellite_service,
    threat_service,
)
from google.adk.sessions.in_memory_session_service import InMemorySessionService
from app.services.mongo_session import MongoSessionService

logger = logging.getLogger(__name__)

# Default crops for market analysis
_DEFAULT_CROPS = [
    "Wheat", "Barley", "Corn", "Sunflower", "Chickpea",
    "Lentil", "Cotton", "Canola", "Soybean",
]


async def generate_full_report(
    db: AsyncDatabase,
    user_id: str,
    lang: str = "tr",
) -> StrategyReport:
    """
    Generate a complete AI-powered strategy report for a farmer.

    Orchestration flow:
    1. Fetch farmer profile → get location & region
    2. Fetch climate data (Open-Meteo) for farmer's location
    3. Fetch regional threats (EPPO) for farmer's region
    4. Fetch market forecasts for common crops
    5. Fetch satellite analysis (Agromonitoring) if available
    6. Send everything to Gemini → get StrategyReport
    7. Save report to MongoDB

    Parameters
    ----------
    db : AsyncDatabase
        Database handle.
    user_id : str
        Farmer's user ID.
    lang: str
        Target language code (e.g. 'tr', 'en', 'es')

    Returns
    -------
    StrategyReport
        AI-generated strategy report.

    Raises
    ------
    HTTPException 404
        If the farmer profile is not found.
    """
    logger.info("🧠 Starting full report generation for %s in %s", user_id, lang)

    # ── Step 1: Farmer Profile ───────────────────────────────────────
    try:
        farmer = await farmer_service.get_farmer_profile(db, user_id)
        farmer_data = farmer.model_dump()
        farmer_data['language'] = lang
        logger.info("✅ Farmer profile loaded: %s (%s)", farmer.name, farmer.location)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Farmer not found: {user_id}",
        ) from exc

    # ── Step 2: Climate Data ─────────────────────────────────────────
    climate = None
    try:
        climate = await climate_service.get_climate_trend(db, farmer.location)
        logger.info("✅ Climate data loaded for %s", farmer.location)
    except Exception:
        logger.warning("⚠️ Climate data unavailable for %s", farmer.location)

    # ── Step 3: Regional Threats ─────────────────────────────────────
    threats = None
    try:
        threats = await threat_service.get_regional_threats(db, farmer.region)
        logger.info("✅ Threat data loaded for %s", farmer.region)
    except Exception:
        logger.warning("⚠️ Threat data unavailable for %s", farmer.region)

    # ── Step 4 is now executed dynamically after Agronomist ──

    # ── Step 5: Satellite Analysis ───────────────────────────────────
    satellite_data = None
    try:
        analysis = await satellite_service.get_full_analysis(db, user_id)
        satellite_data = analysis.model_dump()
        logger.info("✅ Satellite data loaded for %s", user_id)
    except Exception:
        logger.info("ℹ️ No satellite data available for %s (no polygon registered)", user_id)

    # ── Step 5.5: Unified Memory Layer (Past Context) ────────────────
    past_reports = await db.reports.find({"user_id": user_id}).sort("created_at", -1).to_list(length=1)
    past_report_context = None
    if past_reports:
        # Pass the last recommendation to the Master Agent to maintain temporal context
        last = past_reports[0]
        past_report_context = f"Previous Season ({last.get('season')}): Best recommendation {last.get('final_recommendation')}"
        logger.info("🧠 Unified Memory: Found past report context.")

    # ── Step 6: Execute Multi-Agent System (MAS) Pipeline ─────────────
    from app.agents.agronomist_agent import analyze_biology
    from app.agents.coop_agent import analyze_synergy
    from app.agents.economist_agent import analyze_finance
    from app.agents.sustainability_agent import analyze_sustainability
    from app.agents.policy_agent import get_insurance_recommendations
    from app.agents.master_agent import synthesize_report
    
    import os
    from app.config import get_settings
    settings = get_settings()
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
    os.environ["GOOGLE_CLOUD_PROJECT"] = settings.gcp_project_id
    os.environ["GOOGLE_CLOUD_LOCATION"] = settings.gcp_location
    
    logger.info("🤖 Starting MAS Pipeline with MongoDB Data Layer...")
    
    # Check for greenhouse markers or frost risks in plots
    has_greenhouse = any("sera" in (p.name or "").lower() or "greenhouse" in (p.name or "").lower() for p in farmer.plots)
    has_frost_risk = any((p.elevation_m or 0) > 1000 for p in farmer.plots) or (climate is not None and (climate.forecast.predicted_avg_temp_celsius or 15.0) < 5.0)

    # Agent 1: Agronomist (Biology)
    agronomist_output = await analyze_biology(
        farmer_data=farmer_data,
        climate=climate,
        threats=threats,
        satellite=satellite_data
    )

    # ── Step 4: Market Forecast (Now based on Agronomist Recommendations) ──
    market = None
    try:
        recommended_crops = [c.crop for c in agronomist_output.top_3_crops]
        market = await market_service.get_market_forecast(db, recommended_crops)
        logger.info("✅ Market data loaded for recommended crops: %s", recommended_crops)
    except Exception as exc:
        logger.warning("⚠️ Market data unavailable: %s", exc)

    # Agent 2: Cooperative/Synergy (B2B Negotiation)
    coop_output = await analyze_synergy(
        db=db,
        farmer_data=farmer_data,
        agronomist_data=agronomist_output
    )
    
    # Agent 3: Economist (Finance & Policy)
    economist_output = await analyze_finance(
        db=db,
        farmer_data=farmer_data,
        agronomist_data=agronomist_output,
        coop_data=coop_output,
        market=market
    )
    
    # Agent 3.5 + 3.6: Run INDEPENDENTLY in parallel (asyncio.gather)
    sustainability_output, insurance_data = await asyncio.gather(
        analyze_sustainability(
            farmer_data=farmer_data,
            climate_trend=climate.model_dump() if climate else None
        ),
        get_insurance_recommendations(
            region=farmer.region,
            crops=recommended_crops,
            has_greenhouse=has_greenhouse,
            has_frost_risk=has_frost_risk
        ),
    )

    # Agent 4: Master (Synthesis)
    report = await synthesize_report(
        farmer_data=farmer_data,
        agronomist_data=agronomist_output,
        economist_data=economist_output,
        sustainability_data=sustainability_output,
        insurance_data=insurance_data,
        past_report_context=past_report_context
    )

    # ── Guarantee sustainability & insurance fields are never empty ────
    # The master agent LLM sometimes omits these from its JSON output.
    # Fall back to the direct agent outputs which always have real data.
    if not report.sustainability_analysis:
        eco_plan = "\n".join(f"• {a}" for a in sustainability_output.eco_action_plan)
        report.sustainability_analysis = (
            f"Toprak Sağlığı Skoru: {sustainability_output.soil_health_score}/100\n"
            f"Karbon Azaltma Potansiyeli: %{sustainability_output.carbon_reduction_potential_pct}\n\n"
            f"{eco_plan}\n\n"
            f"{sustainability_output.rotation_science_notes}"
        )
        logger.info("🌿 Sustainability filled from direct agent output (master agent missed it)")

    if not report.insurance_recommendations:
        report.insurance_recommendations = insurance_data
        logger.info("🛡️ Insurance filled from direct agent output (master agent missed it)")

    # ── Step 7: Save to MongoDB ──────────────────────────────────────
    try:
        result = await report_service.save_strategy_report(db, report)
        logger.info("💾 Report saved to MongoDB (id=%s)", result.get("id"))
    except Exception:
        logger.warning("Failed to save report to MongoDB", exc_info=True)

    logger.info("🎉 Full report generation complete for %s", user_id)
    return report

async def chat_with_agent(db: AsyncDatabase, user_id: str, message: str) -> str:
    """
    Conversational backend logic using Google's Agent Development Kit (ADK).
    Now supercharged with MongoDB MCP to autonomously query the database!
    """
    import os
    from app.config import get_settings
    from google import genai
    from google.adk.agents.llm_agent import LlmAgent
    from google.adk.tools import MCPToolset
    from google.adk.tools.mcp_tool.mcp_toolset import StdioConnectionParams
    from google.adk.tools.google_search_tool import GoogleSearchTool
    from mcp.client.stdio import StdioServerParameters
    from google.adk import Runner
    from google.genai import types

    # 1. Fetch Farmer Context
    try:
        farmer = await farmer_service.get_farmer_profile(db, user_id)
    except Exception:
        return "Sorry, I could not access your profile. Please log in first."
        
    total_ha = sum(p.size_hectares for p in farmer.plots) if farmer.plots else 0
    
    climate_info = "Climate Data: Not found."
    try:
        climate = await climate_service.get_climate_trend(db, farmer.location)
        climate_info = f"Climate: {climate.forecast.predicted_avg_temp_celsius}°C, Precipitation: {climate.forecast.predicted_rainfall_mm}mm. Analysis: {climate.analysis_notes}"
    except Exception:
        pass

    threat_info = "Threats: Not found."
    try:
        threats = await threat_service.get_regional_threats(db, farmer.region)
        if threats.active_threats:
            threat_list = ", ".join([t.threat_name_tr for t in threats.active_threats])
            threat_info = f"Active Threats: {threat_list}"
        else:
            threat_info = "Active Threats: None"
    except Exception:
        pass

    context_str = f"Farmer Name: {farmer.name}, Location: {farmer.location}, Region: {farmer.region}, Land: {total_ha} ha.\n{climate_info}\n{threat_info}\n"
    
    settings = get_settings()
    
    instruction = f"""You are the intelligent Assistant of the AgriAgent application (Agent Builder).
You can answer the farmer's questions directly from the database using the MongoDB MCP tools below (database query, etc.).
Farmer profile information: {context_str}

IMPORTANT INSTRUCTION: Before searching the database, you MUST call the `connect` tool to connect to the database.
Connection string to use: {settings.mongodb_url}

Task: Communicate with the farmer in a friendly, professional manner like an agricultural consultant.
LANGUAGE INSTRUCTION: Automatically detect the language the user types or speaks in and ALWAYS respond in THAT LANGUAGE. (e.g., if Dutch then Dutch, if Japanese then Japanese, etc.)
PRIVACY AND USAGE RULES:
1. NEVER use database names (e.g., agriagent_db), collection names, SQL/NoSQL query details, or technical expressions like "checking the collection" or "fetching data".
2. The person you are talking to is a farmer who is not familiar with technical terms and is looking for practical information. Use only simple and natural expressions like "I'm analyzing this for you" or "I've checked the system".
3. Deliver results directly as an agricultural engineer or consultant would. Never describe your internal processes (which tools you called, which tables you looked at).
"""

    env = os.environ.copy()
    env["MDB_MCP_CONNECTION_STRING"] = settings.mongodb_url
    
    # Official ADK way to enable Vertex AI
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
    os.environ["GOOGLE_CLOUD_PROJECT"] = settings.gcp_project_id
    os.environ["GOOGLE_CLOUD_LOCATION"] = settings.gcp_location
    
    # 2. Setup MCP Toolset via ADK
    server_params = StdioServerParameters(
        command="npx",
        args=["-y", "@mongodb-js/mongodb-mcp-server"],
        env=env
    )
    
    mcp_toolset = MCPToolset(
        connection_params=StdioConnectionParams(server_params=server_params)
    )

    # 3. Create ADK LlmAgent and Sub-Agents
    chat_agronomist = LlmAgent(
        model="gemini-2.5-flash",
        name="Agronomist_Expert",
        instruction="You are an Agricultural Engineering expert. You specialize in soil, plant diseases, fertilization, and crop rotation. Provide only biological recommendations.",
    )
    
    chat_economist = LlmAgent(
        model="gemini-2.5-flash",
        name="Economist_Expert",
        instruction="You are an Agricultural Economics expert. You specialize in market prices, costs, grants, and profitability.",
    )

    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="AgriAgent_Assistant",
        instruction=instruction,
        tools=[mcp_toolset],
        sub_agents=[chat_agronomist, chat_economist]
    )

    # 4. Run the Agent
    session_id = f"session_{user_id}"
    session_service = MongoSessionService(db)
    
    try:
        await session_service.create_session(app_name="AgriAgent", user_id=user_id, session_id=session_id)
    except Exception:
        pass # Session might already exist
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    final_response = ""
    genai_message = types.Content(parts=[types.Part.from_text(text=message)], role="user")
    
    async for event in runner.run_async(user_id=user_id, session_id=f"session_{user_id}", new_message=genai_message):
        content = getattr(event, 'content', None)
        author = getattr(event, 'author', '')
        if content and hasattr(content, 'parts') and author != 'user':
            text_parts = [p.text for p in content.parts if hasattr(p, 'text') and p.text]
            if text_parts:
                final_response = ''.join(text_parts)

    if final_response:
        return final_response
    
    return "An error occurred or the assistant did not respond."

async def stream_chat_with_agent(
    db: AsyncDatabase, user_id: str, message: str
):
    """
    Yields Server-Sent Events (SSE) representing the reasoning process and final text output.
    """
    import os
    import json
    from app.config import get_settings
    from google.adk.agents.llm_agent import LlmAgent
    from google.adk.tools import MCPToolset
    from google.adk.tools.mcp_tool.mcp_toolset import StdioConnectionParams
    from google.adk.tools.google_search_tool import GoogleSearchTool
    from mcp.client.stdio import StdioServerParameters
    from google.adk import Runner
    from google.genai import types

    try:
        farmer = await farmer_service.get_farmer_profile(db, user_id)
    except Exception:
        yield f"data: {json.dumps({'type': 'error', 'content': 'Sorry, I could not access your profile.'})}\n\n"
        return
        
    total_ha = sum(p.size_hectares for p in farmer.plots) if farmer.plots else 0
    
    climate_info = "Climate Data: Not found."
    try:
        climate = await climate_service.get_climate_trend(db, farmer.location)
        climate_info = f"Climate: {climate.forecast.predicted_avg_temp_celsius}°C, Precipitation: {climate.forecast.predicted_rainfall_mm}mm. Analysis: {climate.analysis_notes}"
    except Exception:
        pass

    threat_info = "Threats: Not found."
    try:
        threats = await threat_service.get_regional_threats(db, farmer.region)
        if threats.active_threats:
            threat_list = ", ".join([t.threat_name_tr for t in threats.active_threats])
            threat_info = f"Active Threats: {threat_list}"
        else:
            threat_info = "Active Threats: None"
    except Exception:
        pass

    context_str = f"Farmer Name: {farmer.name}, Location: {farmer.location}, Region: {farmer.region}, Land: {total_ha} ha.\n{climate_info}\n{threat_info}\n"
    
    settings = get_settings()
    
    instruction = f"""You are the intelligent Assistant of the AgriAgent application (Agent Builder).
You can answer the farmer's questions directly from the database using the MongoDB MCP tools below (database query, etc.).
Farmer profile information: {context_str}

IMPORTANT INSTRUCTION: Before searching the database, you MUST call the `connect` tool to connect to the database.
Connection string to use: {settings.mongodb_url}

Task: Communicate with the farmer in a friendly, professional manner like an agricultural consultant.
LANGUAGE INSTRUCTION: Automatically detect the language the user types or speaks in and ALWAYS respond in THAT LANGUAGE.
PRIVACY AND USAGE RULES:
1. NEVER use database names (e.g., agriagent_db), collection names, SQL/NoSQL query details, or technical expressions like "checking the collection" or "fetching data".
2. The person you are talking to is a farmer who is not familiar with technical terms and is looking for practical information. Use only simple and natural expressions like "I'm analyzing this for you" or "I've checked the system".
3. Deliver results directly as an agricultural engineer or consultant would. Never describe your internal processes (which tools you called, which tables you looked at).
"""

    env = os.environ.copy()
    env["MDB_MCP_CONNECTION_STRING"] = settings.mongodb_url
    
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
    os.environ["GOOGLE_CLOUD_PROJECT"] = settings.gcp_project_id
    os.environ["GOOGLE_CLOUD_LOCATION"] = settings.gcp_location
    
    server_params = StdioServerParameters(
        command="npx",
        args=["-y", "@mongodb-js/mongodb-mcp-server"],
        env=env
    )
    
    mcp_toolset = MCPToolset(
        connection_params=StdioConnectionParams(server_params=server_params)
    )

    # 3. Create ADK LlmAgent and Sub-Agents
    chat_agronomist = LlmAgent(
        model="gemini-2.5-flash",
        name="Agronomist_Expert",
        instruction="You are an Agricultural Engineering expert. You specialize in soil, plant diseases, fertilization, and crop rotation. Provide only biological recommendations.",
    )
    
    chat_economist = LlmAgent(
        model="gemini-2.5-flash",
        name="Economist_Expert",
        instruction="You are an Agricultural Economics expert. You specialize in market prices, costs, grants, and profitability.",
    )

    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="AgriAgent_Assistant",
        instruction=instruction,
        tools=[mcp_toolset],
        sub_agents=[chat_agronomist, chat_economist]
    )

    session_id = f"session_{user_id}"
    session_service = MongoSessionService(db)
    
    try:
        await session_service.create_session(app_name="AgriAgent", user_id=user_id, session_id=session_id)
    except Exception:
        pass
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    genai_message = types.Content(parts=[types.Part.from_text(text=message)], role="user")
    
    final_text = ""
    
    try:
        async for event in runner.run_async(user_id=user_id, session_id=f"session_{user_id}", new_message=genai_message):
            # Log every event for debugging
            logger.info("🔍 ADK Event: type=%s, author=%s, has_content=%s",
                        type(event).__name__,
                        getattr(event, 'author', 'N/A'),
                        hasattr(event, 'content') and getattr(event, 'content', None) is not None)
            
            # Extract text content from the event
            content = getattr(event, 'content', None)
            if content and hasattr(content, 'parts'):
                text_parts = []
                for part in content.parts:
                    if hasattr(part, 'text') and part.text:
                        text_parts.append(part.text)
                
                if text_parts:
                    text = ''.join(text_parts)
                    author = getattr(event, 'author', '')
                    
                    # Only yield agent responses, not user echo
                    if author != 'user' and text.strip():
                        final_text += text + "\n"
                        yield f"data: {json.dumps({'type': 'chunk', 'content': text + '\n\n'})}\n\n"
    except Exception as e:
        logger.error("❌ ADK stream error: %s", str(e), exc_info=True)
        yield f"data: {json.dumps({'type': 'error', 'content': f'Agent error: {str(e)}'})}\n\n"
        return
    
    if not final_text:
        yield f"data: {json.dumps({'type': 'message', 'content': 'An error occurred or the assistant did not respond.'})}\n\n"

async def voice_chat_with_agent(
    db: AsyncDatabase, user_id: str, audio_bytes: bytes, mime_type: str
) -> str:
    """
    Sends voice input to the ADK LlmAgent.
    """
    import os
    from app.config import get_settings
    from google import genai
    from google.adk.agents.llm_agent import LlmAgent
    from google.adk.tools import MCPToolset
    from google.adk.tools.mcp_tool.mcp_toolset import StdioConnectionParams
    from google.adk.tools.google_search_tool import GoogleSearchTool
    from mcp.client.stdio import StdioServerParameters
    from google.adk import Runner
    from google.genai import types

    try:
        farmer = await farmer_service.get_farmer_profile(db, user_id)
    except Exception:
        return "Sorry, I could not access your profile. Please log in first."
        
    total_ha = sum(p.size_hectares for p in farmer.plots) if farmer.plots else 0
    
    climate_info = "Climate Data: Not found."
    try:
        climate = await climate_service.get_climate_trend(db, farmer.location)
        climate_info = f"Climate: {climate.forecast.predicted_avg_temp_celsius}°C, Precipitation: {climate.forecast.predicted_rainfall_mm}mm. Analysis: {climate.analysis_notes}"
    except Exception:
        pass

    threat_info = "Threats: Not found."
    try:
        threats = await threat_service.get_regional_threats(db, farmer.region)
        if threats.active_threats:
            threat_list = ", ".join([t.threat_name_tr for t in threats.active_threats])
            threat_info = f"Active Threats: {threat_list}"
        else:
            threat_info = "Active Threats: None"
    except Exception:
        pass

    context_str = f"Farmer Name: {farmer.name}, Location: {farmer.location}, Region: {farmer.region}, Land: {total_ha} ha.\n{climate_info}\n{threat_info}\n"
    
    settings = get_settings()
    instruction = f"""You are the intelligent Assistant of the AgriAgent application (Agent Builder).
You can answer the farmer's questions directly from the database using the MongoDB MCP tools below (database query, etc.).
Farmer profile information: {context_str}

IMPORTANT INSTRUCTION: Before searching the database, you MUST call the `connect` tool to connect to the database.
Connection string to use: {settings.mongodb_url}

Task: Communicate with the farmer in a friendly, professional manner like an agricultural consultant.
LANGUAGE INSTRUCTION: Detect the language of the audio recording and ALWAYS respond in THAT LANGUAGE.
PRIVACY AND USAGE RULES:
1. NEVER use database names (e.g., agriagent_db), collection names, SQL/NoSQL query details, or technical expressions like "checking the collection" or "fetching data".
2. The person you are talking to is a farmer who is not familiar with technical terms and is looking for practical information. Use only simple and natural expressions like "I'm analyzing this for you" or "I've checked the system".
3. Deliver results directly as an agricultural engineer or consultant would. Never describe your internal processes (which tools you called, which tables you looked at).
"""

    env = os.environ.copy()
    env["MDB_MCP_CONNECTION_STRING"] = settings.mongodb_url
    
    # Official ADK way to enable Vertex AI
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
    os.environ["GOOGLE_CLOUD_PROJECT"] = settings.gcp_project_id
    os.environ["GOOGLE_CLOUD_LOCATION"] = settings.gcp_location
    
    server_params = StdioServerParameters(
        command="npx",
        args=["-y", "@mongodb-js/mongodb-mcp-server"],
        env=env
    )
    
    mcp_toolset = MCPToolset(
        connection_params=StdioConnectionParams(server_params=server_params)
    )

    chat_agronomist = LlmAgent(
        model="gemini-2.5-flash",
        name="Agronomist_Expert",
        instruction="You are an Agricultural Engineering expert. You specialize in soil, plant diseases, fertilization, and crop rotation.",
    )
    
    chat_economist = LlmAgent(
        model="gemini-2.5-flash",
        name="Economist_Expert",
        instruction="You are an Agricultural Economics expert. You specialize in market prices, costs, grants, and profitability.",
    )

    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="AgriAgent_Voice_Assistant",
        instruction=instruction,
        tools=[mcp_toolset],
        sub_agents=[chat_agronomist, chat_economist]
    )

    session_id = f"session_voice_{user_id}"
    session_service = MongoSessionService(db)
    
    try:
        await session_service.create_session(app_name="AgriAgent", user_id=user_id, session_id=session_id)
    except Exception:
        pass
    
    runner = Runner(
        agent=agent,
        app_name="AgriAgent",
        session_service=session_service
    )
    
    final_response = ""
    genai_message = types.Content(parts=[
        types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
        types.Part.from_text(text="Please listen to this audio and reply in the exact same language the user is speaking.")
    ], role="user")
    
    async for event in runner.run_async(user_id=user_id, session_id=f"session_voice_{user_id}", new_message=genai_message):
        if getattr(event, "type", None) == "run_completed":
            final_response = getattr(event, "message", "")
            break
        elif hasattr(event, "message"):
            final_response = event.message

    if final_response:
        if hasattr(final_response, "parts"):
            return "".join([getattr(p, "text", "") for p in final_response.parts])
        elif isinstance(final_response, str):
            return final_response
        else:
            return str(final_response)
    
    return "An error occurred or the assistant did not respond."

async def calculate_urgency_radar(db: AsyncDatabase, user_id: str) -> list[dict]:
    """
    Real-time AI urgency calculation based on actual weather and threats.
    """
    import json
    from google import genai
    from pydantic import BaseModel
    from app.config import get_settings
    
    # 1. Fetch real context
    try:
        farmer = await farmer_service.get_farmer_profile(db, user_id)
        if not farmer or not farmer.plots:
            return []
    except Exception:
        return []
        
    climate = None
    try:
        climate = await climate_service.get_climate_trend(db, farmer.location)
    except Exception:
        pass
        
    threats = None
    try:
        threats = await threat_service.get_regional_threats(db, farmer.region)
    except Exception:
        pass
    
    # 2. Extract context
    climate_info = f"Weather: {climate.forecast.predicted_avg_temp_celsius}C, {climate.forecast.predicted_rainfall_mm}mm rain." if climate else "No weather data."
    threat_info = "No threats"
    if threats and threats.active_threats:
        threat_info = ", ".join([t.threat_name_tr for t in threats.active_threats])
        
    plots_info = "\n".join([f"Plot ID: {p.plot_id}, Crop: {p.crop_history[-1].crop if p.crop_history else 'Unknown'}, Soil: {p.soil_analysis.texture if p.soil_analysis else 'Unknown'}" for p in farmer.plots])

    prompt = f"""You are an Agronomist AI. Evaluate the operational urgency of the following farm plots based on REAL weather and threats.
Weather: {climate_info}
Active Regional Threats: {threat_info}
Plots:
{plots_info}

For each plot, provide a score (0-100) indicating how urgent intervention is needed today, a short reason in Turkish (e.g. "Pas hastalığı riski"), a hex color code (e.g. #FF0000 for critical, #FFA500 for warning, #4CAF50 for safe), and a Flutter material icon name string (e.g. "warning_amber_rounded", "water_drop_outlined", "check_circle_outline", "bolt").
Return ONLY a valid JSON array of objects with keys: plot_id, score, reason, color, icon. Do not use markdown tags like ```json.
"""
    from app.agents.llm_utils import get_genai_client
    client = get_genai_client()
    
    try:
        response = await client.aio.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        text = response.text.strip()
        if text.startswith("```json"):
            text = text[7:-3]
        if text.startswith("```"):
            text = text[3:-3]
            
        data = json.loads(text.strip())
        return data
    except Exception as e:
        logger.error(f"Failed to generate real AI urgency radar: {e}")
        return []
