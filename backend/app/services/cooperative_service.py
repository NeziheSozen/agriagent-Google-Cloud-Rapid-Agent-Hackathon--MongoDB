"""
Cooperative service — business logic for cooperative CRUD,
membership management, and machine sharing.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from pymongo.asynchronous.database import AsyncDatabase

from app.models.cooperative import Cooperative, CoopMachine

logger = logging.getLogger(__name__)


async def create_cooperative(
    db: AsyncDatabase,
    name: str,
    region: str,
    description: str,
    coop_type: str,
    admin_id: str,
    admin_name: str,
) -> dict:
    """
    Create a new cooperative, add the admin as the first member,
    and update the farmer's cooperative_id in the farmers collection.
    """
    coop = Cooperative(
        name=name,
        region=region,
        description=description,
        coop_type=coop_type,
        admin_id=admin_id,
        member_ids=[admin_id],
    )
    doc = coop.model_dump()
    doc["created_at"] = doc["created_at"].isoformat()
    # Serialize nested machines (empty on creation)
    doc["machines"] = [m if isinstance(m, dict) else m for m in doc["machines"]]

    await db.cooperatives.insert_one(doc)

    # Update the admin farmer profile
    await db.farmers.update_one(
        {"user_id": admin_id},
        {"$set": {"cooperative_id": coop.coop_id, "cooperative_name": name}},
    )

    logger.info(f"🤝 Cooperative '{name}' created by {admin_name} ({admin_id})")
    return doc


async def join_cooperative(
    db: AsyncDatabase,
    join_code: str,
    user_id: str,
) -> dict:
    """
    Join a cooperative using its unique join code.
    Validates the code, adds user to member_ids, and updates farmer profile.
    """
    coop = await db.cooperatives.find_one({"join_code": join_code})
    if not coop:
        raise ValueError(f"Invalid join code: {join_code}")

    if user_id in coop.get("member_ids", []):
        raise ValueError("You are already a member of this cooperative.")

    await db.cooperatives.update_one(
        {"coop_id": coop["coop_id"]},
        {"$addToSet": {"member_ids": user_id}},
    )

    await db.farmers.update_one(
        {"user_id": user_id},
        {"$set": {"cooperative_id": coop["coop_id"], "cooperative_name": coop["name"]}},
    )

    logger.info(f"👋 User {user_id} joined cooperative '{coop['name']}'")
    return {"coop_id": coop["coop_id"], "name": coop["name"], "status": "joined"}


async def leave_cooperative(
    db: AsyncDatabase,
    coop_id: str,
    user_id: str,
) -> dict:
    """
    Leave a cooperative. The admin cannot leave their own cooperative.
    Removes user from member_ids and clears farmer's cooperative_id.
    """
    coop = await db.cooperatives.find_one({"coop_id": coop_id})
    if not coop:
        raise ValueError(f"Cooperative not found: {coop_id}")

    if user_id not in coop.get("member_ids", []):
        raise ValueError("You are not a member of this cooperative.")

    # Remove user's individually-owned machines from the cooperative
    machines = [
        m for m in coop.get("machines", [])
        if m.get("owner_id") != user_id or m.get("ownership_type") != "individual"
    ]

    update_ops: dict = {
        "$pull": {"member_ids": user_id},
        "$set": {"machines": machines},
    }

    # If admin leaves, transfer admin role to AI
    if coop["admin_id"] == user_id:
        update_ops["$set"]["admin_id"] = "agriagent_ai"
        logger.info(f"🤖 Admin left coop {coop_id}, transferring to AI management")

    await db.cooperatives.update_one({"coop_id": coop_id}, update_ops)

    await db.farmers.update_one(
        {"user_id": user_id},
        {"$set": {"cooperative_id": None, "cooperative_name": None}},
    )

    logger.info(f"🚪 User {user_id} left cooperative '{coop['name']}'")
    return {"status": "left", "coop_id": coop_id}


async def get_cooperative(db: AsyncDatabase, coop_id: str) -> dict | None:
    """Return cooperative details by coop_id."""
    doc = await db.cooperatives.find_one({"coop_id": coop_id}, {"_id": 0})
    return doc


async def get_my_cooperative(db: AsyncDatabase, user_id: str) -> dict | None:
    """Find the cooperative that the user belongs to."""
    doc = await db.cooperatives.find_one(
        {"member_ids": user_id}, {"_id": 0}
    )
    return doc


async def add_machine(
    db: AsyncDatabase,
    coop_id: str,
    machine: CoopMachine,
) -> dict:
    """
    Add a machine to the cooperative.
    Only members can add machines (owner_id must be in member_ids).
    """
    coop = await db.cooperatives.find_one({"coop_id": coop_id})
    if not coop:
        raise ValueError(f"Cooperative not found: {coop_id}")

    if machine.owner_id not in coop.get("member_ids", []):
        raise ValueError("Machine owner is not a cooperative member.")

    machine_doc = machine.model_dump()
    await db.cooperatives.update_one(
        {"coop_id": coop_id},
        {"$push": {"machines": machine_doc}},
    )

    logger.info(f"🚜 Machine '{machine.name}' added to coop {coop_id}")
    return machine_doc


async def toggle_machine_sharing(
    db: AsyncDatabase,
    coop_id: str,
    machine_id: str,
    owner_id: str,
    shared: bool,
) -> dict:
    """
    Toggle the shared status of a machine. Only the machine owner can toggle.
    """
    coop = await db.cooperatives.find_one({"coop_id": coop_id})
    if not coop:
        raise ValueError(f"Cooperative not found: {coop_id}")

    # Find the machine and verify ownership / permissions
    machine_found = False
    for m in coop.get("machines", []):
        if m["machine_id"] == machine_id:
            ownership = m.get("ownership_type", "individual")
            if ownership == "individual" and m["owner_id"] != owner_id:
                raise ValueError("Only the machine owner can change the sharing status.")
            if ownership == "cooperative" and owner_id != coop["admin_id"]:
                raise ValueError("Only the admin can manage cooperative machines.")
            # ai_managed: any member can toggle (auto-approve)
            machine_found = True
            break

    if not machine_found:
        raise ValueError(f"Machine not found: {machine_id}")

    await db.cooperatives.update_one(
        {"coop_id": coop_id, "machines.machine_id": machine_id},
        {"$set": {"machines.$.shared": shared}},
    )

    status = "shared" if shared else "unshared"
    logger.info(f"🔄 Machine {machine_id} {status}")
    return {"machine_id": machine_id, "shared": shared, "status": status}


async def remove_machine(
    db: AsyncDatabase,
    coop_id: str,
    machine_id: str,
    owner_id: str,
) -> dict:
    """
    Remove a machine from the cooperative. Only the machine owner can remove.
    """
    coop = await db.cooperatives.find_one({"coop_id": coop_id})
    if not coop:
        raise ValueError(f"Cooperative not found: {coop_id}")

    # Verify ownership / permissions
    machine_found = False
    for m in coop.get("machines", []):
        if m["machine_id"] == machine_id:
            ownership = m.get("ownership_type", "individual")
            if ownership == "individual" and m["owner_id"] != owner_id:
                raise ValueError("Only the machine owner can remove the machine.")
            if ownership == "cooperative" and owner_id != coop["admin_id"]:
                raise ValueError("Only the admin can remove cooperative machines.")
            # ai_managed: any member can remove
            machine_found = True
            break

    if not machine_found:
        raise ValueError(f"Machine not found: {machine_id}")

    await db.cooperatives.update_one(
        {"coop_id": coop_id},
        {"$pull": {"machines": {"machine_id": machine_id}}},
    )

    logger.info(f"🗑️ Machine {machine_id} removed from coop {coop_id}")
    return {"machine_id": machine_id, "status": "removed"}


async def get_shared_machines(db: AsyncDatabase, coop_id: str) -> list[dict]:
    """Return only shared machines (shared=True) from a cooperative."""
    coop = await db.cooperatives.find_one({"coop_id": coop_id}, {"_id": 0})
    if not coop:
        return []

    return [m for m in coop.get("machines", []) if m.get("shared") is True]
