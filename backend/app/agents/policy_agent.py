import logging
from pymongo.asynchronous.database import AsyncDatabase
from pydantic import BaseModel
from google import genai
from app.config import get_settings

logger = logging.getLogger(__name__)

class PolicyMatch(BaseModel):
    title: str
    content: str
    match_score: float

async def search_web_for_grants(region: str, age: int, crops: list[str], gender: str = "Prefer not to say") -> str | None:
    """
    Autonomous Web Search Agent: Uses Gemini's Google Search Grounding
    to fetch real-time live grants from the internet.
    """
    settings = get_settings()
    client = genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
    )
    
    def get_domains(loc: str) -> str:
        loc_lower = loc.lower()
        if "hollanda" in loc_lower or "netherlands" in loc_lower:
            return "site:rijksoverheid.nl OR site:rvo.nl"
        elif "ispanya" in loc_lower or "spain" in loc_lower:
            return "site:mapa.gob.es"
        elif "italya" in loc_lower or "italy" in loc_lower:
            return "site:politicheagricole.it"
        elif "kore" in loc_lower or "korea" in loc_lower:
            return "site:mafra.go.kr"
        elif "japonya" in loc_lower or "japan" in loc_lower:
            return "site:maff.go.jp"
        elif "avustralya" in loc_lower or "australia" in loc_lower:
            return "site:agriculture.gov.au"
        elif "yeni zelanda" in loc_lower or "new zealand" in loc_lower:
            return "site:mpi.govt.nz"
        return "site:.gov OR site:.org"

    target_domains = get_domains(region)
    query_target = " OR ".join(crops)
    prompt = (
        f"Search Query: '{target_domains} {region} {query_target} agriculture farming grant subsidy 2026'\n\n"
        f"Please search the specified official government/ministry websites in real-time and summarize the most current "
        f"government subsidies, grants, and incentives for '{', '.join(crops)}' farming in the {region} region. "
        f"IMPORTANT: Our farmer is {age} years old and their gender is '{gender}'. If they qualify as a 'Young Farmer' "
        "according to their country's rules, make sure to include and report special young farmer additional grants.\n"
        f"Additionally, if the farmer is Female, strongly highlight any special scoring and grants provided to women entrepreneurs/farmers by local Ministry of Agriculture or agricultural funds!\n"
        "If you find a specific rate (e.g., 25%), make sure to state it. Write the information as a short and clear paragraph."
    )
    
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                temperature=0.3,
                tools=[{"google_search": {}}]
            )
        )
        if response.text:
            return response.text
    except Exception as e:
        logger.warning(f"Live Web Search (Grounding) failed: {e}")
        return None
    return None

async def search_mongodb_rag(db: AsyncDatabase, region: str, age: int, crops: list[str], gender: str = "Prefer not to say") -> str | None:
    """Fallback: Uses MongoDB Vector Search (RAG) against internal PDFs."""
    settings = get_settings()
    client = genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
    )
    
    query_text = f"Government subsidies and grants for {' and '.join(crops)} farming in the {region} region. Farmer age: {age} (including young farmer subsidies). Gender: {gender} (including women farmer subsidies)"
    
    try:
        response = client.models.embed_content(
            model="text-embedding-004",
            contents=query_text
        )
        query_vector = response.embeddings[0].values
        
        pipeline = [
            {
                "$vectorSearch": {
                    "index": "vector_index",
                    "path": "embedding",
                    "queryVector": query_vector,
                    "numCandidates": 10,
                    "limit": 2
                }
            },
            {
                "$project": {
                    "_id": 0,
                    "title": 1,
                    "content": 1,
                    "score": {"$meta": "vectorSearchScore"}
                }
            }
        ]
        
        cursor = await db.policies.aggregate(pipeline)
        docs = await cursor.to_list(length=2)
        
        if docs:
            grants = []
            for doc in docs:
                grants.append(f"Document: {doc.get('title')} -> {doc.get('content')}")
            return "\n".join(grants)
    except Exception as e:
        logger.warning(f"MongoDB Vector Search fallback failed: {e}")
    return None

async def get_policy_grants(db: AsyncDatabase, region: str, age: int, crops: list[str], gender: str = "Prefer not to say") -> str:
    """
    Policy Agent Master Function:
    1. Primarily uses MongoDB Vector Search (RAG) since Scout Agent populates it nightly.
    2. Falls back to live Autonomous Web Search if MongoDB has no data.
    """
    if not crops:
        return "No relevant grants found."
        
    logger.info(f"🏛️ Policy Agent querying MongoDB for grants: {region} - Age {age} - Gender {gender} - {crops}")
    
    # 1. Primary: MongoDB Vector Search (RAG)
    rag_results = await search_mongodb_rag(db, region, age, crops, gender)
    if rag_results:
        logger.info("📡 MongoDB Vector Search successful.")
        return f"[From Our Database (Verified Government Source)]: {rag_results}"
        
    # 2. Fallback 1: In-Memory RAG (Direct DB fetch + Gemini) in case Atlas Vector Index is missing
    logger.info("📡 Vector Search failed or empty. Falling back to In-Memory RAG...")
    try:
        docs = await db.policies.find().to_list(length=10)
        if docs:
            combined_text = "\n".join([d.get("content", "") for d in docs])
            
            settings = get_settings()
            client = genai.Client(
                vertexai=True,
                project=settings.gcp_project_id,
                location=settings.gcp_location,
            )
            prompt = (
                f"Using the following official Ministry of Agriculture document, extract the current subsidies and grants "
                f"for {' and '.join(crops)} farming in the {region} region. The farmer is {age} years old (young farmer?) and their gender is {gender} (woman farmer?). Highlight any special additional scoring and subsidies if available.\n\n"
                f"Official Document:\n{combined_text}"
            )
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
                config=genai.types.GenerateContentConfig(temperature=0.3)
            )
            if response.text:
                return f"[From Our Database (In-Memory Government RAG)]: {response.text}"
    except Exception as e:
        logger.warning(f"In-Memory RAG failed: {e}")
        
    # 2. Fallback: Live Web Search (Google Grounding)
    logger.info("🌐 MongoDB failed or empty. Falling back to Live Web Search...")
    web_results = await search_web_for_grants(region, age, crops, gender)
    if web_results:
        return f"[Live Web Search (Fallback)]: {web_results}"
        
    # 3. Final Fallback
    return "[Static Fallback]: Standard agricultural grants for greenhouse and area-based support."

async def get_insurance_recommendations(
    region: str,
    crops: list[str],
    has_greenhouse: bool = False,
    has_frost_risk: bool = False
) -> str:
    """
    Search agricultural, greenhouse, or frost insurance options globally or locally.
    Uses Gemini Google Search Grounding to fetch the most up-to-date insurance programs.
    """
    logger.info(f"🛡️ Policy Agent fetching agricultural insurance options: {region} - Greenhouse={has_greenhouse} - Frost Risk={has_frost_risk}")
    
    settings = get_settings()
    client = genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gcp_location,
    )
    
    prompt = (
        f"Search agricultural crop insurance options in region: '{region}' for crops: {crops}. "
        f"Greenhouse coverage needed: {has_greenhouse}. High frost/weather hazard: {has_frost_risk}.\n\n"
        f"Find real active insurance programs (e.g. TARSIM in Turkey, USDA Crop Insurance in USA, EU agricultural insurance elsewhere). "
        f"Outline the subsidy levels, standard deductible rates, greenhouse structural coverages, and frost/freeze hazard guidelines. "
        f"Format the output as a friendly, professional summary in the user's language (defaulting to Turkish if located in Turkey, or English globally)."
    )
    
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                temperature=0.3,
                tools=[{"google_search": {}}]
            )
        )
        if response.text:
            return response.text
    except Exception as e:
        logger.warning(f"Agricultural Insurance Search (Grounding) failed: {e}")
        
    return "Standard agricultural crop and greenhouse multi-peril risk coverage is recommended for frost and storm damage."

