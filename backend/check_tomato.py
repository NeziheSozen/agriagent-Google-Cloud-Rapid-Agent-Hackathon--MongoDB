import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
import json

import os
async def main():
    client = AsyncIOMotorClient(os.getenv("MONGODB_URL", "mongodb://localhost:27017"))
