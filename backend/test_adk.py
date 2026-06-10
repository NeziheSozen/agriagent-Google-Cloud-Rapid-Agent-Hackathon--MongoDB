import os
from app.config import get_settings
settings = get_settings()
os.environ["GOOGLE_CLOUD_PROJECT"] = settings.gcp_project_id
os.environ["GOOGLE_CLOUD_LOCATION"] = settings.gcp_location

from google.genai import Client
client = Client(vertexai=True)
from google.adk.agents.llm_agent import LlmAgent
agent = LlmAgent(
    model="gemini-2.5-flash",
    name="TestAgent",
    instruction="test",
    client=client
)
print("Agent created successfully!")
