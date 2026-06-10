"""
Cooperative router — REST endpoints for cooperative management.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from pymongo.asynchronous.database import AsyncDatabase
import httpx

from app.database import get_db
from app.models.cooperative import CoopMachine
from app.services.cooperative_service import (
    create_cooperative,
    join_cooperative,
    leave_cooperative,
    get_cooperative,
    get_my_cooperative,
    add_machine,
    toggle_machine_sharing,
    remove_machine,
    get_shared_machines,
)

router = APIRouter(prefix="/coop", tags=["Cooperative"])


# ── Request bodies ───────────────────────────────────────────────────────


class CreateCoopRequest(BaseModel):
    name: str
    region: str
    description: str = ""
    coop_type: str = "collective"
    admin_id: str
    admin_name: str


class JoinCoopRequest(BaseModel):
    join_code: str
    user_id: str


class LeaveCoopRequest(BaseModel):
    coop_id: str
    user_id: str


class AddMachineRequest(BaseModel):
    coop_id: str
    name: str
    type: str
    owner_id: str
    owner_name: str
    shared: bool = False
    daily_rental_cost: float = 0.0
    status: str = "active"


class ToggleMachineRequest(BaseModel):
    coop_id: str
    machine_id: str
    owner_id: str
    shared: bool


# ── Endpoints ────────────────────────────────────────────────────────────


@router.post("/create")
async def create_coop_endpoint(
    body: CreateCoopRequest,
    db: AsyncDatabase = Depends(get_db),
):
    """Create a new cooperative."""
    try:
        result = await create_cooperative(
            db,
            name=body.name,
            region=body.region,
            description=body.description,
            coop_type=body.coop_type,
            admin_id=body.admin_id,
            admin_name=body.admin_name,
        )
        result.pop("_id", None)
        return {"status": "created", "cooperative": result}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/join")
async def join_coop_endpoint(
    body: JoinCoopRequest,
    db: AsyncDatabase = Depends(get_db),
):
    """Join a cooperative using a join code."""
    try:
        result = await join_cooperative(db, body.join_code, body.user_id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/leave")
async def leave_coop_endpoint(
    body: LeaveCoopRequest,
    db: AsyncDatabase = Depends(get_db),
):
    """Leave a cooperative."""
    try:
        result = await leave_cooperative(db, body.coop_id, body.user_id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/my/{user_id}")
async def get_my_coop_endpoint(
    user_id: str,
    db: AsyncDatabase = Depends(get_db),
):
    """Get the cooperative the user belongs to."""
    coop = await get_my_cooperative(db, user_id)
    if not coop:
        raise HTTPException(status_code=404, detail="No cooperative membership found.")
    coop.pop("_id", None)
    return coop


@router.get("/machines/shared/{coop_id}")
async def get_shared_machines_endpoint(
    coop_id: str,
    db: AsyncDatabase = Depends(get_db),
):
    """Get only shared machines from a cooperative."""
    machines = await get_shared_machines(db, coop_id)
    return {"coop_id": coop_id, "shared_machines": machines}


@router.get("/nearby", summary="Find nearby cooperatives using $geoNear")
async def get_nearby_cooperatives(
    lon: float,
    lat: float,
    max_distance_km: float = 50.0,
    db: AsyncDatabase = Depends(get_db)
):
    """
    Find cooperatives near a specific coordinate using MongoDB's $geoNear.
    """
    # First get from DB
    pipeline = [
        {
            "$geoNear": {
                "near": {"type": "Point", "coordinates": [lon, lat]},
                "distanceField": "dist.calculated",
                "maxDistance": max_distance_km * 1000,
                "spherical": True
            }
        },
        {"$limit": 10}
    ]
    
    cursor = await db.cooperatives.aggregate(pipeline)
    coops = []
    async for doc in cursor:
        doc.pop("_id", None)
        coops.append(doc)
        
    # If not enough, try OSM Overpass API to get REAL ones
    if len(coops) < 3:
        try:
            overpass_url = "https://overpass-api.de/api/interpreter"
            overpass_query = f"""
            [out:json];
            (
              node["name"~"(tarım|ziraat|kalkınma|üretici|agri|farm|rural).*(kooperatif|coop|genossenschaft)|(kooperatif|coop|genossenschaft).*(tarım|ziraat|kalkınma|üretici|agri|farm|rural)", i](around:{max_distance_km*1000},{lat},{lon});
            );
            out center 5;
            """
            headers = {"User-Agent": "AgriAgent-App/1.0"}
            async with httpx.AsyncClient(headers=headers, timeout=5.0) as client:
                res = await client.post(overpass_url, data={'data': overpass_query})
                if res.status_code == 200:
                    data = res.json()
                    for el in data.get('elements', []):
                        tags = el.get('tags', {})
                        name = tags.get('name')
                        if not name:
                            continue
                        
                        # Check if already exists in DB
                        existing = await db.cooperatives.find_one({"name": name})
                        if not existing:
                            import uuid
                            from datetime import datetime
                            new_coop = {
                                "coop_id": str(uuid.uuid4())[:8],
                                "name": name,
                                "region": tags.get('addr:city', 'Local Region'),
                                "description": "Real agricultural cooperative found via OpenStreetMap.",
                                "coop_type": "collective",
                                "created_at": datetime.utcnow().isoformat(),
                                "admin_id": "system",
                                "admin_name": "System",
                                "members": [],
                                "machines": [],
                                "location_geo": {
                                    "type": "Point",
                                    "coordinates": [el.get('lon'), el.get('lat')]
                                }
                            }
                            await db.cooperatives.insert_one(new_coop)
                            new_coop.pop("_id", None)
                            new_coop['dist'] = {'calculated': 0.0} # approx
                            coops.append(new_coop)
        except Exception as e:
            print(f"OSM fetch error: {e}")
            
    return coops[:10]


@router.get("/{coop_id}")
async def get_coop_endpoint(
    coop_id: str,
    db: AsyncDatabase = Depends(get_db),
):
    """Get cooperative details."""
    coop = await get_cooperative(db, coop_id)
    if not coop:
        raise HTTPException(status_code=404, detail="Cooperative not found.")
    coop.pop("_id", None)
    return coop


@router.post("/machine")
async def add_machine_endpoint(
    body: AddMachineRequest,
    db: AsyncDatabase = Depends(get_db),
):
    """Add a machine to a cooperative."""
    try:
        machine = CoopMachine(
            name=body.name,
            type=body.type,
            owner_id=body.owner_id,
            owner_name=body.owner_name,
            shared=body.shared,
            daily_rental_cost=body.daily_rental_cost,
            status=body.status,
        )
        result = await add_machine(db, body.coop_id, machine)
        return {"status": "added", "machine": result}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/machine/toggle")
async def toggle_machine_endpoint(
    body: ToggleMachineRequest,
    db: AsyncDatabase = Depends(get_db),
):
    """Toggle machine sharing status."""
    try:
        result = await toggle_machine_sharing(
            db, body.coop_id, body.machine_id, body.owner_id, body.shared
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/machine/{coop_id}/{machine_id}")
async def remove_machine_endpoint(
    coop_id: str,
    machine_id: str,
    owner_id: str = Query(...),
    db: AsyncDatabase = Depends(get_db),
):
    """Remove a machine from a cooperative."""
    try:
        result = await remove_machine(db, coop_id, machine_id, owner_id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
