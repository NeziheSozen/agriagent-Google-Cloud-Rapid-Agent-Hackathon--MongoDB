import os
from google import genai

_original_client_init = genai.Client.__init__
def _patched_client_init(self, *args, **kwargs):
    kwargs['vertexai'] = True
    _original_client_init(self, *args, **kwargs)
genai.Client.__init__ = _patched_client_init

from app.config import get_settings
settings = get_settings()
os.environ["GOOGLE_CLOUD_PROJECT"] = settings.gcp_project_id
os.environ["GOOGLE_CLOUD_LOCATION"] = settings.gcp_location

from google.adk.agents.llm_agent import LlmAgent
try:
    agent = LlmAgent(
        model="gemini-2.5-flash",
        name="TestAgent",
        instruction="test"
    )
    print("Agent created with patched vertexai=True")
except Exception as e:
    print(f"Failed: {e}")
