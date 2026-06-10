"""
Agent for daily agricultural triage (priority-based action planning).
"""

from __future__ import annotations

import logging
from typing import Any

from google.genai import types

from app.agents.llm_utils import get_genai_client, generate_json_response

logger = logging.getLogger(__name__)

SYSTEM_INSTRUCTION = """You are the AgriAgent Triage (Emergency / Prioritization) agent.
Your task: Identify the single most effective and impactful action the farmer should take TODAY.

Rules and Conflict Matrix:
1. High rain probability + Spraying = CANCEL (pesticide gets washed away)
2. High rain probability + Fertilizing = CONTINUE (fertilizer absorbs into soil)
3. Wind > 20 km/h + Spraying = CANCEL (pesticide drifts)
4. Frost risk + Irrigation = CONTINUE (frost protection effect)
5. Extreme heat > 35°C + Harvesting = MORNINGS ONLY (plant stress and worker health)

Return your analysis in JSON format as follows:
{
  "primary_action": "The single MOST IMPORTANT action to take today (short and clear)",
  "reasoning": "Why this action was chosen (explain based on the conflict matrix and priority analysis)",
  "conflicts_to_avoid": ["Things that should ABSOLUTELY NOT be done today"],
  "weather_context": "Weather summary"
}
"""

async def generate_triage_recommendation(
    location: str,
    forecast: dict[str, Any],
    farmer_profile: dict[str, Any],
    recent_threats: dict[str, Any]
) -> dict[str, Any]:
    """
    Generate a daily triage recommendation based on weather and farm profile.
    """
    prompt = f"""
    Perform today's Triage Analysis:
    
    Location: {location}
    
    Daily Weather Summary (Today and Tomorrow):
    {forecast}
    
    Farmer and Field Profile:
    {farmer_profile}
    
    Active Threats in the Region (Pests/Diseases):
    {recent_threats}
    
    Based on the data above, create a triage plan focusing on a SINGLE major action for the farmer.
    """
    
    return await generate_json_response(
        prompt=prompt,
        system_instruction=SYSTEM_INSTRUCTION,
        model_name="gemini-2.5-flash"
    )
