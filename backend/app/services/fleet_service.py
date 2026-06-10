"""
Fleet sharing engine — generates machine schedules from real cooperative data.

Queries the cooperatives collection for shared machines and the fleet_bookings
collection for existing reservations. Uses Open-Meteo for weather blocking.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from pymongo.asynchronous.database import AsyncDatabase

from app.models.fleet import FleetBooking, FleetSchedule, FleetScheduleItem
from app.external_apis.geocoding import geocode
from app.external_apis.open_meteo import get_forecast

logger = logging.getLogger(__name__)


async def generate_fleet_schedule(
    db: AsyncDatabase,
    region: str,
    farmer_name: str = "Siz",
    machine_type: str | None = None,
    coop_id: str | None = None,
) -> FleetSchedule:
    """
    Fleet sharing engine.

    Uses real cooperative machines from ``db.cooperatives``.
    Falls back gracefully if no coop_id is provided.
    Weather blocking via Open-Meteo forecast.
    """
    # ── Weather forecast ─────────────────────────────────────────────────
    forecast = None
    try:
        lat, lon, _ = await geocode(region)
        forecast = await get_forecast(lat, lon)
    except Exception as e:
        logger.warning(f"Could not fetch weather for fleet schedule: {e}")

    # ── Resolve machine from cooperative ─────────────────────────────────
    machine_name = machine_type or "Machine"
    machine_id = "unknown"
    synergy_discount_percent = 0.0

    if coop_id:
        coop = await db.cooperatives.find_one({"coop_id": coop_id})
        if coop:
            shared_machines = [
                m for m in coop.get("machines", [])
                if m.get("shared") is True and m.get("status") == "active"
            ]
            if machine_type:
                # Try to find a machine matching the requested type
                matched = [m for m in shared_machines if m["type"] == machine_type]
                if matched:
                    chosen = matched[0]
                    machine_name = chosen["name"]
                    machine_id = chosen["machine_id"]
                else:
                    # Fall back to first shared machine
                    if shared_machines:
                        chosen = shared_machines[0]
                        machine_name = chosen["name"]
                        machine_id = chosen["machine_id"]
            elif shared_machines:
                chosen = shared_machines[0]
                machine_name = chosen["name"]
                machine_id = chosen["machine_id"]

            # Calculate synergy discount based on member count
            member_count = len(coop.get("member_ids", []))
            synergy_discount_percent = min(member_count * 3.0, 25.0)
    else:
        # No coop_id — return a minimal schedule with a hint
        return FleetSchedule(
            machine="No cooperative machine found",
            region=region,
            synergy_discount_percent=0.0,
            schedule=[
                FleetScheduleItem(
                    date=datetime.now(timezone.utc).strftime("%Y-%m-%d"),
                    status="unavailable",
                    assignee="—",
                    reason="Join a cooperative or provide a coop_id parameter.",
                    is_current_user=False,
                )
            ],
        )

    # ── Build 5-day schedule ─────────────────────────────────────────────
    today = datetime.now(timezone.utc)
    schedule_items: list[FleetScheduleItem] = []

    for i in range(5):
        date = today + timedelta(days=i)
        date_str = date.strftime("%Y-%m-%d")

        # Check weather blocking
        weather_blocked = False
        weather_reason = ""

        if forecast:
            for daily in forecast.forecast:
                if daily.date == date_str:
                    if daily.precipitation_sum_mm > 5.0:
                        weather_blocked = True
                        weather_reason = (
                            f"Soil not suitable due to expected precipitation "
                            f"({daily.precipitation_sum_mm}mm)"
                        )
                    break

        if weather_blocked:
            schedule_items.append(
                FleetScheduleItem(
                    date=date_str,
                    status="weather_blocked",
                    assignee="Autonomous System (Cancelled)",
                    reason=weather_reason,
                    is_current_user=False,
                )
            )
            continue

        # Check existing bookings
        booking_doc = await db.fleet_bookings.find_one(
            {"machine_id": machine_id, "date": date_str}
        )

        if booking_doc:
            is_current = booking_doc.get("farmer_name") == farmer_name
            schedule_items.append(
                FleetScheduleItem(
                    date=date_str,
                    status=booking_doc.get("status", "confirmed"),
                    assignee=booking_doc.get("farmer_name", "Unknown"),
                    reason=booking_doc.get("reason", ""),
                    is_current_user=is_current,
                )
            )
        else:
            schedule_items.append(
                FleetScheduleItem(
                    date=date_str,
                    status="available",
                    assignee="Idle (Available for Rent)",
                    reason="Machine is currently available in the cooperative pool",
                    is_current_user=False,
                )
            )

    return FleetSchedule(
        machine=machine_name,
        region=region,
        synergy_discount_percent=synergy_discount_percent,
        schedule=schedule_items,
    )


async def book_machine(
    db: AsyncDatabase,
    machine_id: str,
    farmer_name: str,
    date: str,
    coop_id: str,
    reason: str = "Machine Usage",
) -> dict:
    """
    Create a booking for a shared machine.

    Validates that the machine exists in the cooperative, is shared, and
    the date is not already booked.
    """
    # Verify the machine exists and is shared
    coop = await db.cooperatives.find_one({"coop_id": coop_id})
    if not coop:
        raise ValueError(f"Cooperative not found: {coop_id}")

    machine_found = False
    for m in coop.get("machines", []):
        if m["machine_id"] == machine_id and m.get("shared") is True:
            machine_found = True
            break

    if not machine_found:
        raise ValueError(
            f"Machine {machine_id} is not shared in the cooperative."
        )

    # Check if date is already booked
    existing = await db.fleet_bookings.find_one(
        {"machine_id": machine_id, "date": date}
    )
    if existing:
        raise ValueError(
            f"Machine {machine_id} is already booked on this date ({date})."
        )

    booking_id = str(uuid.uuid4())[:8]
    booking_doc = {
        "booking_id": booking_id,
        "machine_id": machine_id,
        "coop_id": coop_id,
        "farmer_name": farmer_name,
        "date": date,
        "status": "confirmed",
        "reason": reason,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    await db.fleet_bookings.insert_one(booking_doc)
    logger.info(f"📅 Booking {booking_id}: {farmer_name} → {machine_id} on {date}")

    booking_doc.pop("_id", None)
    return booking_doc


async def cancel_booking(db: AsyncDatabase, booking_id: str) -> dict:
    """Cancel an existing fleet booking."""
    result = await db.fleet_bookings.delete_one({"booking_id": booking_id})
    if result.deleted_count == 0:
        raise ValueError(f"Booking not found: {booking_id}")

    logger.info(f"🗑️ Booking {booking_id} cancelled")
    return {"booking_id": booking_id, "status": "cancelled"}
