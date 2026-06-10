import uuid
from typing import Any, Optional
import time

from pymongo.asynchronous.database import AsyncDatabase
from google.adk.sessions.base_session_service import BaseSessionService, GetSessionConfig, ListSessionsResponse
from google.adk.sessions.session import Session
from google.adk.events.event import Event
from google.adk.sessions import _session_util

class MongoSessionService(BaseSessionService):
    """
    MongoDB backed SessionService for Google ADK.
    Provides persistent chat history and unified memory across sessions.
    """

    def __init__(self, db: AsyncDatabase):
        self.db = db
        self.sessions = db.adk_sessions

    async def create_session(
        self,
        *,
        app_name: str,
        user_id: str,
        state: Optional[dict[str, Any]] = None,
        session_id: Optional[str] = None,
    ) -> Session:
        session_id = session_id.strip() if session_id and session_id.strip() else str(uuid.uuid4())
        
        # Check if exists
        existing = await self.sessions.find_one({
            "app_name": app_name,
            "user_id": user_id,
            "id": session_id
        })
        
        if existing:
            # Already exists, just return it
            existing.pop('_id', None)
            return Session.model_validate(existing)
            
        state_deltas = _session_util.extract_state_delta(state)
        # Note: We are keeping it simple for Hackathon. In a full production we'd 
        # separate app_state, user_state and session_state globally like InMemory does.
        # Here we just put all of it in session.state for simplicity.
        session_state = state_deltas['session'] or {}
        
        session = Session(
            app_name=app_name,
            user_id=user_id,
            id=session_id,
            state=session_state,
            last_update_time=time.time(),
            events=[]
        )
        
        await self.sessions.insert_one(session.model_dump(by_alias=False))
        return session

    async def get_session(
        self,
        *,
        app_name: str,
        user_id: str,
        session_id: str,
        config: Optional[GetSessionConfig] = None,
    ) -> Optional[Session]:
        doc = await self.sessions.find_one({
            "app_name": app_name,
            "user_id": user_id,
            "id": session_id
        })
        
        if not doc:
            return None
            
        doc.pop('_id', None)
        session = Session.model_validate(doc)
        
        if config:
            if config.num_recent_events is not None:
                if config.num_recent_events == 0:
                    session.events = []
                else:
                    session.events = session.events[-config.num_recent_events:]
            if config.after_timestamp:
                session.events = [e for e in session.events if e.timestamp >= config.after_timestamp]
                
        return session

    async def list_sessions(
        self, *, app_name: str, user_id: Optional[str] = None
    ) -> ListSessionsResponse:
        query = {"app_name": app_name}
        if user_id:
            query["user_id"] = user_id
            
        cursor = self.sessions.find(query)
        sessions = []
        async for doc in cursor:
            # We don't return events in list_sessions
            doc["events"] = []
            doc.pop('_id', None)
            sessions.append(Session.model_validate(doc))
            
        return ListSessionsResponse(sessions=sessions)

    async def delete_session(
        self, *, app_name: str, user_id: str, session_id: str
    ) -> None:
        await self.sessions.delete_one({
            "app_name": app_name,
            "user_id": user_id,
            "id": session_id
        })

    async def append_event(self, session: Session, event: Event) -> Event:
        if event.partial:
            return event
            
        # Call base method to apply/trim temp state
        await super().append_event(session=session, event=event)
        session.last_update_time = event.timestamp
        
        # Save the new event and state to DB
        await self.sessions.update_one(
            {
                "app_name": session.app_name,
                "user_id": session.user_id,
                "id": session.id
            },
            {
                "$push": {"events": event.model_dump(by_alias=False)},
                "$set": {
                    "last_update_time": session.last_update_time,
                    "state": session.state
                }
            }
        )
        return event
