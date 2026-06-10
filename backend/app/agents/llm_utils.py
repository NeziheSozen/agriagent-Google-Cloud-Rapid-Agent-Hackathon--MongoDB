from typing import TypeVar, Type
from pydantic import BaseModel
from google import genai
import logging
from app.config import get_settings

logger = logging.getLogger(__name__)

T = TypeVar("T", bound=BaseModel)

def get_genai_client() -> genai.Client:
    """Returns an authenticated genai Client using Vertex AI."""
    settings = get_settings()
    return genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
    )

def generate_json_response(
    client: genai.Client,
    prompt: str,
    response_schema: Type[T],
    model_name: str = "gemini-2.5-flash",
    temperature: float = 0.5
) -> T:
    """Helper to generate a strictly typed JSON response from Gemini."""
    logger.debug(f"Calling LLM: {model_name} with schema {response_schema.__name__}")
    
    response = client.models.generate_content(
        model=model_name,
        contents=prompt,
        config=genai.types.GenerateContentConfig(
            temperature=temperature,
            response_mime_type="application/json",
            response_schema=response_schema,
        ),
    )
    
    return response.parsed

def generate_json_with_image(
    client: genai.Client,
    prompt: str,
    image_bytes: bytes,
    mime_type: str,
    response_schema: Type[T],
    model_name: str = "gemini-2.5-flash",
    temperature: float = 0.5
) -> T:
    """Helper to generate a strictly typed JSON response from Gemini using an image."""
    logger.debug(f"Calling LLM Vision: {model_name} with schema {response_schema.__name__}")
    
    response = client.models.generate_content(
        model=model_name,
        contents=[
            prompt,
            genai.types.Part.from_bytes(data=image_bytes, mime_type=mime_type)
        ],
        config=genai.types.GenerateContentConfig(
            temperature=temperature,
            response_mime_type="application/json",
            response_schema=response_schema,
        ),
    )
    
    return response.parsed
