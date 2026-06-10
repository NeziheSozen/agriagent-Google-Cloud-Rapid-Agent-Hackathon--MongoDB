"""
Application configuration via Pydantic Settings.

Loads environment variables from .env file with sensible defaults
for local development. Use ``get_settings()`` to obtain a cached
singleton — never instantiate ``Settings`` directly in application code.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central configuration sourced from environment / .env file."""

    mongodb_url: str = "mongodb://localhost:27017"
    database_name: str = "agriagent_db"
    debug: bool = True

    # ── External API Keys ────────────────────────────────────────────
    agromonitoring_api_key: str = ""
    collectapi_key: str = ""
    api_ninjas_key: str = ""

    # ── Google Cloud ─────────────────────────────────────────────────
    gcp_project_id: str = ""
    gcp_location: str = "us-central1"

    # ── External API Base URLs ───────────────────────────────────────
    open_meteo_base_url: str = "https://api.open-meteo.com"
    open_meteo_archive_url: str = "https://archive-api.open-meteo.com"
    agromonitoring_base_url: str = "https://api.agromonitoring.com/agro/1.0"
    eppo_base_url: str = "https://data.eppo.int/api/rest/1.0"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Return a cached ``Settings`` instance (created once per process)."""
    return Settings()
