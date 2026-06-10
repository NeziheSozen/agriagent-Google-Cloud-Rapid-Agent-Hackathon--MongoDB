"""
AgriAgent — AI-Powered Agricultural Advisory API.

Main FastAPI application entry point. Assembles middleware, routers,
and the database lifespan into a production-ready ASGI app.

Run locally::

    uvicorn app.main:app --reload

Or with Docker::

    docker compose up --build
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import lifespan
from app.routers import (
    agent, climate, market, profile, reports, satellite, threats, internal, fleet,
    chilling, gdd, slope, triage, cooperative, irrigation, sensor
)

# ── Application factory ─────────────────────────────────────────────────
app = FastAPI(
    title="AgriAgent API",
    description=(
        "🌾 **AgriAgent** — AI-powered agricultural advisory platform.\n\n"
        "Provides farmer profiles, climate trends, pest/disease alerts, "
        "commodity price forecasts, and personalised crop-rotation strategy "
        "reports for global agriculture.\n\n"
        "🏆 Built for the **[Google Cloud Rapid Agent Hackathon](https://rapid-agent.devpost.com/)**\n"
        "🏷️ Track: **[MongoDB](https://rapid-agent.devpost.com/details/mongodb-resources)**"
    ),
    version="2.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS (wide-open for hackathon demo; tighten in production) ───────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ──────────────────────────────────────────────────────────────
app.include_router(internal.router)
app.include_router(profile.router)
app.include_router(climate.router)
app.include_router(market.router)
app.include_router(threats.router)
app.include_router(satellite.router)
app.include_router(reports.router)
app.include_router(agent.router)
app.include_router(fleet.router)
app.include_router(chilling.router)
app.include_router(gdd.router)
app.include_router(slope.router)
app.include_router(triage.router)
app.include_router(cooperative.router)
app.include_router(irrigation.router)
app.include_router(sensor.router)


# ── Health check ─────────────────────────────────────────────────────────
@app.get(
    "/health",
    tags=["System"],
    summary="Health check",
    description="Returns 200 if the API is alive.",
)
async def health_check() -> dict:
    """Lightweight liveness probe for orchestrators and load balancers."""
    return {
        "status": "healthy",
        "service": "AgriAgent API",
        "version": "2.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
