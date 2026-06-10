import os
from google import genai

client = genai.Client(vertexai=True, project="devpost-gemini-agent-hackhaton", location="us-central1")

try:
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents="Who won the super bowl in 2025?",
        config=genai.types.GenerateContentConfig(
            tools=[{"google_search": {}}]
        )
    )
    print("SUCCESS")
    print(response.text)
except Exception as e:
    print(f"FAILED: {e}")
