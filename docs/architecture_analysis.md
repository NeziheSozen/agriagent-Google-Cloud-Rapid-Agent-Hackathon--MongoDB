# 🏗️ AgriAgent — Complete Architecture Analysis

> **Reverse-engineered from source code** — Every dependency verified through imports, constructor injection, and runtime wiring.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [C4 Context Diagram](#output-1-c4-context-diagram)
3. [C4 Container Diagram](#output-2-c4-container-diagram)
4. [Component Diagrams](#output-3-component-diagrams)
5. [Sequence Diagrams](#output-4-sequence-diagrams)
6. [Architecture Decision Summary](#output-5-architecture-decision-summary)
7. [Mermaid Diagrams](#output-6-mermaid-diagrams)

---

## 1. System Overview

AgriAgent is a **Multi-Agent System (MAS)** for smallholder farmers, built for the **Google Cloud Rapid Agent Hackathon**. It combines predictive climate models, real-time pest intelligence, futures market forecasting, and cooperative logistics into a single AI-powered advisory platform.

| Dimension | Detail |
|-----------|--------|
| **Architectural Style** | Layered Service Architecture + Multi-Agent AI Pipeline |
| **Backend** | FastAPI 0.115+ · Python 3.12+ · PyMongo 4.13+ (AsyncMongoClient) |
| **Frontend** | Flutter 3.24+ · Dart 3.5+ · Riverpod · GoRouter |
| **Database** | MongoDB 7.0 (Atlas) |
| **AI Engine** | Google Gemini 2.5 Flash (Vertex AI) + Google ADK |
| **On-Device AI** | Gemma 4 E2B (LiteRT via flutter_gemma) |
| **Hosting** | Google Cloud Run (Backend) · Firebase Hosting (Landing Page) |
| **Total Endpoints** | ~45 across 16 routers |
| **Total Screens** | 14 Flutter screens |
| **Languages** | 11 (en, tr, nl, es, it, ja, ko, fr, pt, hi, zh) |

---

# Output 1: C4 Context Diagram

## Users

| User | Description |
|------|-------------|
| **Smallholder Farmer** | Primary user — views dashboard, scans pests, reads AI reports, chats with AI assistant |
| **Cooperative Admin** | Creates/manages cooperatives, shares machinery |
| **System Admin** | Triggers internal webhooks (Scout Agent, Backfill) via `/internal/` endpoints |

## External Systems

| System | Type | Purpose |
|--------|------|---------|
| **Google Gemini 2.5 Flash** | LLM API (Vertex AI) | All AI generation — reports, chat, pest scanning, triage, logistics advice |
| **Google text-embedding-004** | Embedding API (Vertex AI) | Vector embeddings for RAG (policy documents) |
| **MongoDB Atlas** | Database | Primary persistence — 12 collections |
| **Open-Meteo** | Weather API (Free) | Historical climate, forecasts, soil moisture, ET₀, chilling hours, GDD |
| **EPPO Data Service** | Pest API | Pest/disease identification and regional threat data |
| **Agromonitoring** | Satellite API | NDVI, soil moisture, field polygon management |
| **FAO / CollectAPI / API Ninjas** | Market APIs | Commodity price data (multi-source with fallback) |
| **OSM Overpass** | Geospatial API | Nearby cooperative discovery |
| **Firebase Cloud Messaging** | Push Notifications | Farmer alerts |
| **MongoDB MCP Server** | MCP Tool | Gives AI chat agent direct DB query capability |

## Main Application

| Component | Technology | Deployment |
|-----------|------------|------------|
| **Flutter Mobile App** | Flutter 3.24 + Riverpod | iOS / Android / macOS / Windows |
| **FastAPI Backend** | Python 3.12 + FastAPI | Google Cloud Run |
| **Landing Page** | Vanilla HTML/CSS/JS | Firebase Hosting |

## Relationships

```
Farmer ──── uses ────► Flutter App
Flutter App ──── REST/SSE ────► FastAPI Backend
FastAPI Backend ──── queries ────► MongoDB Atlas
FastAPI Backend ──── calls ────► Gemini 2.5 Flash (Vertex AI)
FastAPI Backend ──── fetches ────► Open-Meteo, EPPO, Agromonitoring, FAO
FastAPI Backend ──── spawns ────► MongoDB MCP Server (stdio subprocess)
Flutter App ──── offline inference ────► Gemma 4 E2B (on-device)
Flutter App ──── push notifications ────► Firebase Cloud Messaging
```

---

# Output 2: C4 Container Diagram

## Containers

| Container | Technology | Responsibility |
|-----------|------------|----------------|
| **Flutter App** | Dart 3.5, Flutter 3.24, Riverpod, GoRouter | Cross-platform UI, offline-first caching, on-device AI fallback |
| **FastAPI Backend** | Python 3.12, FastAPI, Pydantic v2 | REST API, AI agent orchestration, external API aggregation |
| **MongoDB** | MongoDB 7.0 (Atlas) | Document storage, vector search, change streams, time series |
| **AI Agent Pipeline** | Google ADK, Gemini 2.5 Flash | Multi-agent report generation, conversational chat |
| **MCP Server** | `@mongodb-js/mongodb-mcp-server` (Node.js) | Gives chat agent direct database query tools |
| **Nightly Scheduler** | asyncio background task | Scout Agent ETL + Report backfill at 03:00 daily |


## Communication Paths

| From | To | Protocol | Format |
|------|----|----------|--------|
| Flutter App | FastAPI Backend | HTTPS | REST JSON + SSE streams + Multipart uploads |
| FastAPI Backend | MongoDB | TCP | PyMongo AsyncMongoClient |
| FastAPI Backend | Gemini | HTTPS | google-genai SDK (Vertex AI) |
| FastAPI Backend | Open-Meteo | HTTPS | REST JSON |
| FastAPI Backend | EPPO | HTTPS | REST JSON |
| FastAPI Backend | Agromonitoring | HTTPS | REST JSON |
| FastAPI Backend | MCP Server | stdio | JSON-RPC (Model Context Protocol) |
| Flutter App | Gemma 4 E2B | In-process | flutter_gemma (LiteRT) |
| Flutter App | FCM | HTTPS | Firebase Messaging SDK |

---

# Output 3: Component Diagrams

## 3.1 Backend Components

### Router Layer (16 routers, ~45 endpoints)

| Router | File | Endpoints | Dependencies |
|--------|------|-----------|--------------|
| `agent` | [agent.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/agent.py) | 7 | agent_service, llm_utils |
| `profile` | [profile.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/profile.py) | 7 | farmer_service, soil_service |
| `climate` | [climate.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/climate.py) | 2 | climate_service |
| `market` | [market.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/market.py) | 1 | market_service |
| `threats` | [threats.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/threats.py) | 1 | threat_service |
| `satellite` | [satellite.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/satellite.py) | 4 | satellite_service |
| `reports` | [reports.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/reports.py) | 2 | report_service |
| `fleet` | [fleet.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/fleet.py) | 3 | fleet_service |
| `cooperative` | [cooperative.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/cooperative.py) | 10 | cooperative_service, OSM Overpass |
| `chilling` | [chilling.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/chilling.py) | 1 | chilling_service |
| `gdd` | [gdd.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/gdd.py) | 1 | gdd_service |
| `slope` | [slope.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/slope.py) | 1 | slope_service |
| `triage` | [triage.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/triage.py) | 1 | triage_agent |
| `irrigation` | [irrigation.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/irrigation.py) | 1 | irrigation_service |
| `sensor` | [sensor.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/sensor.py) | 4 | llm_utils (Gemini Vision) |
| `internal` | [internal.py](file:///Users/nezihes/Desktop/agrticulture%20agent/backend/app/routers/internal.py) | 3 | scout_agent, backfill_reports |

### Service Layer (17 services)

| Service | Responsibility | External Deps | Depended-on-by |
|---------|---------------|---------------|----------------|
| **agent_service** | AI orchestration brain | All agents, all services, ADK, MCP | agent router |
| **farmer_service** | Farmer CRUD | MongoDB | profile router, agent_service |
| **climate_service** | Climate data fetch + cache | Open-Meteo, Geocoding, MongoDB | climate router, agent_service |
| **threat_service** | Pest/disease intelligence | EPPO, GBIF, Gemini, MongoDB | threats router, agent_service |
| **market_service** | Price aggregation | FAO, CollectAPI, API Ninjas, MongoDB | market router, agent_service |
| **satellite_service** | Satellite imagery analysis | Agromonitoring, MongoDB | satellite router, agent_service |
| **report_service** | Report CRUD | MongoDB | reports router, agent_service |
| **cooperative_service** | Coop membership + machines | MongoDB | cooperative router |
| **fleet_service** | Machine scheduling | Open-Meteo, Geocoding, MongoDB | fleet router |
| **irrigation_service** | Irrigation assessment | Open-Meteo, Geocoding | irrigation router |
| **chilling_service** | Chilling hours | Open-Meteo, Geocoding | chilling router |
| **gdd_service** | Growing degree days | Open-Meteo, Geocoding | gdd router |
| **slope_service** | Slope/erosion analysis | Open-Meteo Elevation | slope router |
| **soil_service** | Soil report OCR | Gemini Vision | profile router |
| **coop_service** | B2B synergy calculation | MongoDB aggregation | coop_agent |
| **mongo_session** | ADK chat persistence | MongoDB | agent_service |

### Agent Layer (9 agents)

| Agent | Type | Model | Input | Output |
|-------|------|-------|-------|--------|
| **Agronomist** | ADK LlmAgent | gemini-2.5-flash | farmer, climate, threats, satellite | `AgronomistOutput` |
| **Coop** | ADK LlmAgent | gemini-2.5-flash | farmer, agronomist output, DB synergy | `CoopOutput` |
| **Economist** | ADK LlmAgent | gemini-2.5-flash | farmer, agronomist, coop, market | `EconomistOutput` |
| **Sustainability** | ADK LlmAgent | gemini-2.5-flash | farmer, climate | `SustainabilityOutput` |
| **Master** | ADK LlmAgent | gemini-2.5-flash | ALL agent outputs + memory | `MasterAgentReport` → `StrategyReport` |
| **Policy** | Direct genai.Client | gemini-2.5-flash + text-embedding-004 | region, crops | Grants/insurance strings |
| **Scout** | Direct genai.Client | text-embedding-004 | Web scraping results | MongoDB policy documents |
| **Triage** | Direct genai.Client | gemini-2.5-flash | Weather + activities | Priority JSON |
| **Chat (Root)** | ADK LlmAgent | gemini-2.5-flash | User message + MCP + GoogleSearch | Free-text reply |

### External API Clients (7 clients)

| Client | File | APIs Called |
|--------|------|------------|
| **open_meteo** | `open_meteo.py` | `api.open-meteo.com`, `archive-api.open-meteo.com` |
| **geocoding** | `geocoding.py` | `geocoding-api.open-meteo.com` + 25-city static lookup |
| **elevation** | `elevation.py` | `api.open-meteo.com/v1/elevation` |
| **eppo_client** | `eppo_client.py` | `data.eppo.int` + hardcoded pest knowledge base |
| **gbif_client** | `gbif_client.py` | GBIF occurrence API |
| **agromonitoring** | `agromonitoring.py` | `api.agromonitoring.com` |
| **market_data** | `market_data.py` | FAO, CollectAPI, API Ninjas + hardcoded fallback |

---

## 3.2 Frontend Components

### Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SCREENS (14)                          │
│  HomeScreen · ChatbotScreen · FarmerScreen · Climate     │
│  Threats · Market · Report · Cooperatives · Logistics    │
│  Settings · Login · Onboarding · ProfileEdit · Offline   │
├─────────────────────────────────────────────────────────┤
│                    WIDGETS (15)                          │
│  ResponsiveScaffold · GlassCard · StatTile · ThreatBadge │
│  TrendChart · PriceRow · RiskGauge · CropTimeline        │
│  DailyBriefingCard · FleetCalendarCard · UrgencyRadar    │
│  ShimmerLoading · DeveloperConsole · EditPlotDialog       │
│  LocationSearchDialog                                    │
├─────────────────────────────────────────────────────────┤
│                  PROVIDERS (25)                          │
│  State Management via Riverpod (auto-dispose + keepAlive)│
│  FutureProviders for async data · Notifiers for state    │
├─────────────────────────────────────────────────────────┤
│                   SERVICES (8)                          │
│  ApiClient (Dio) · AgentApi · FarmerApi · ClimateApi     │
│  MarketApi · ThreatApi · ReportApi · PushNotification    │
├─────────────────────────────────────────────────────────┤
│                    MODELS (8)                           │
│  FarmerProfile · ClimateTrend · RegionalThreats          │
│  MarketForecast · StrategyReport · Cooperative           │
│  FleetSchedule · PlotDraft                               │
├─────────────────────────────────────────────────────────┤
│                 INFRASTRUCTURE                          │
│  GoRouter · AgriAgentTheme (M3) · L10n (11 langs)        │
│  Responsive breakpoints · SharedPreferences cache        │
│  OfflineQueue · Gemma 4 E2B · Firebase Messaging         │
└─────────────────────────────────────────────────────────┘
```

---

# Output 4: Sequence Diagrams

## 4.1 Application Startup

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant SP as SharedPreferences
    participant FB as Firebase
    participant API as FastAPI Backend
    participant DB as MongoDB
    participant BG as Background Tasks

    U->>App: Launch App
    App->>FB: Firebase.initializeApp()
    App->>SP: Get logged_in_user_id
    alt User logged in
        App->>API: GET /profile/{userId}
        API->>DB: farmers.find_one({user_id})
        DB-->>API: FarmerProfile
        API-->>App: 200 OK
        App->>App: Navigate to "/" (Dashboard)
    else Not logged in
        App->>App: Navigate to "/login"
    end

    Note over API,BG: Backend Startup (Lifespan)
    API->>DB: Ping + Create Indexes
    API->>BG: asyncio.create_task(watch_policies)
    API->>BG: asyncio.create_task(backfill_reports)
    API->>BG: asyncio.create_task(nightly_scheduler)
    BG->>DB: Change Stream on policies collection
```

## 4.2 Main User Workflow — AI Strategy Report Generation

```mermaid
sequenceDiagram
    participant U as Farmer
    participant App as Flutter App
    participant API as FastAPI Backend
    participant FS as FarmerService
    participant CS as ClimateService
    participant TS as ThreatService
    participant MS as MarketService
    participant SS as SatelliteService
    participant AG as Agronomist Agent
    participant CO as Coop Agent
    participant EC as Economist Agent
    participant SU as Sustainability Agent
    participant PO as Policy Agent
    participant MA as Master Agent
    participant GM as Gemini 2.5 Flash
    participant DB as MongoDB

    U->>App: Tap "Generate AI Report"
    App->>API: POST /agent/generate-report/{userId}
    
    par Data Fetching
        API->>FS: get_farmer(userId)
        FS->>DB: farmers.find_one()
        API->>CS: get_climate(location)
        CS->>CS: Open-Meteo API
        API->>TS: get_threats(region)
        TS->>TS: EPPO API
        API->>MS: get_market(crops)
        MS->>MS: FAO/CollectAPI
        API->>SS: get_satellite(userId)
        SS->>SS: Agromonitoring API
        API->>DB: Past reports (Unified Memory)
    end

    Note over API: Sequential Agent Pipeline
    API->>AG: analyze(farmer, climate, threats, satellite)
    AG->>GM: LlmAgent.run_async()
    GM-->>AG: AgronomistOutput (top 3 crops)

    API->>CO: analyze(farmer, agronomist_output)
    CO->>DB: coop_service.calculate_synergy()
    CO->>GM: LlmAgent.run_async()
    GM-->>CO: CoopOutput (B2B discounts)

    API->>EC: analyze(farmer, agronomist, coop, market)
    EC->>PO: get_policy_grants(region, crops)
    PO->>GM: Google Search Grounding
    EC->>GM: LlmAgent.run_async()
    GM-->>EC: EconomistOutput (financial ranking)

    par Independent Agents
        API->>SU: analyze(farmer, climate)
        SU->>GM: LlmAgent.run_async()
        GM-->>SU: SustainabilityOutput
        API->>PO: get_insurance(region, crops)
        PO->>GM: Google Search Grounding
        GM-->>PO: Insurance recommendations
    end

    API->>MA: synthesize(ALL outputs + memory)
    MA->>GM: LlmAgent.run_async()
    GM-->>MA: MasterAgentReport → StrategyReport

    API->>DB: strategy_reports.insert_one()
    API-->>App: StrategyReport JSON
    App->>U: Display Report with CropOptions
```

## 4.3 Data Persistence Workflow — Offline-First Caching

```mermaid
sequenceDiagram
    participant Screen as Flutter Screen
    participant Provider as Riverpod Provider
    participant Service as API Service
    participant API as FastAPI Backend
    participant SP as SharedPreferences
    participant Queue as OfflineQueue

    Screen->>Provider: ref.watch(climateTrendProvider)
    Provider->>Service: ClimateApi.getClimateTrend(location)
    
    alt Online
        Service->>API: GET /climate-trend/{location}
        API-->>Service: ClimateTrend JSON
        Service-->>Provider: ClimateTrend
        Provider->>SP: cache_climate_{location} = JSON + timestamp
        Provider-->>Screen: AsyncValue.data(ClimateTrend)
    else Offline / API Error
        Provider->>SP: Read cache_climate_{location}
        alt Cache exists
            SP-->>Provider: Cached JSON
            Provider-->>Screen: AsyncValue.data(ClimateTrend) [from cache]
        else No cache
            Provider-->>Screen: AsyncValue.error()
        end
    end

    Note over Screen,Queue: Mutation (Offline Queue)
    Screen->>Queue: enqueue(POST /coop/create, payload)
    Queue->>SP: Persist PendingJob list
    
    Note over Queue: When connectivity restored
    Queue->>API: Replay all pending jobs
    Queue->>SP: Remove completed jobs
```

## 4.4 API Request Workflow — Pest Scanning (Multimodal)

```mermaid
sequenceDiagram
    participant U as Farmer
    participant App as Flutter App
    participant Cam as Camera/Gallery
    participant API as FastAPI Backend
    participant GM as Gemini 2.5 Flash
    participant DB as MongoDB

    U->>App: Tap "Scan Pest"
    App->>Cam: ImagePicker (camera or gallery)
    Cam-->>App: Image file
    App->>API: POST /agent/scan-pest/{userId}?lang=tr (multipart: image)
    
    API->>GM: generate_json_with_image()
    Note over API,GM: Prompt: Identify pest, severity,<br/>mitigation in English + local lang
    GM-->>API: ThreatAlert JSON (parsed via Pydantic)
    
    API->>DB: regional_threats.update_one()
    Note over API,DB: Push alert to region's active_threats
    
    API-->>App: ThreatAlert JSON
    App->>U: Display pest name, severity, mitigation
    Note over App: Shows local_name_{lang} with<br/>English fallback
```

---

# Output 5: Architecture Decision Summary

## Architectural Style

| Aspect | Classification |
|--------|---------------|
| **Overall** | **Layered Service Architecture** with Multi-Agent AI Pipeline |
| **Backend** | Router → Service → Repository (MongoDB direct) → External APIs |
| **Frontend** | **MVVM** via Riverpod (Model → Provider/Notifier → ConsumerWidget) |
| **AI System** | **Sequential Multi-Agent Pipeline** (report) + **Hierarchical Sub-Agent** (chat) |
| **Data Strategy** | **Offline-First** with cache-then-network + offline mutation queue |

## Design Patterns Catalog

| Pattern | Where | Implementation |
|---------|-------|----------------|
| **Dependency Injection** | Backend | FastAPI `Depends(get_db)` for database access |
| **Dependency Injection** | Frontend | Riverpod `ref.read()` / `ref.watch()` |
| **Service Layer** | Backend | Thin routers delegate to service modules |
| **Repository** | Backend | Services query MongoDB directly (no ORM) |
| **MVVM** | Frontend | Models ↔ Providers (ViewModel) ↔ Screens (View) |
| **Cache-First + Graceful Degradation** | Both | Try API → cache on success → fallback to cache on failure |
| **Offline Queue** | Frontend | `OfflineQueueProvider` stores pending mutations in SharedPreferences |
| **Multi-Agent System (MAS)** | Backend | 5 ADK LlmAgents in sequential pipeline with typed Pydantic outputs |
| **RAG (Retrieval-Augmented Generation)** | Backend | MongoDB `$vectorSearch` + `text-embedding-004` for policy lookup |
| **ETL Pipeline** | Backend | Scout Agent scrapes gov sites → embeds → loads into MongoDB nightly |
| **Change Streams** | Backend | Real-time MongoDB watcher for policy insert → push notification trigger |
| **MCP (Model Context Protocol)** | Backend | `@mongodb-js/mongodb-mcp-server` gives chat agent DB query tools |
| **Structured Output** | Backend | Gemini `response_mime_type="application/json"` + `response_schema` |
| **Observer Pattern** | Frontend | Riverpod reactive providers + Connectivity stream listeners |
| **Strategy Pattern** | Backend | Multi-source market data with fallback chain (FAO → CollectAPI → API Ninjas → hardcoded) |
| **Adapter Pattern** | Frontend | `ApiClient` wraps Dio with generic `get<T>()` / `post<T>()` + parser callbacks |
| **Shell Pattern** | Frontend | GoRouter `ShellRoute` wraps screens with `ResponsiveScaffold` |
| **State Machine** | Frontend | Gemma download states: `notDownloaded → downloading → ready → error` |

## Potential Architectural Weaknesses

> [!WARNING]
> ### 1. Authentication Gap
> No JWT/OAuth/session tokens. User identity is passed as `user_id` path parameter. Login is a simple email lookup. Acceptable for hackathon, but not production-ready.

> [!WARNING]
> ### 2. Sequential Pipeline Bottleneck
> Sustainability and Insurance agents are independent of the Economist agent but run sequentially. Could be parallelized with `asyncio.gather()` to reduce report generation time by ~30%.

> [!WARNING]
> ### 3. Hardcoded Session IDs
> Pipeline agents use fixed session IDs like `"agronomist_session"`. Under concurrent requests, these could collide and produce corrupted results.

> [!CAUTION]
> ### 4. Auth Method Inconsistency
> `calculate_urgency_radar()` uses `api_key` auth while all other Gemini calls use Vertex AI. This is likely an oversight that could cause failures if the API key is not set.

> [!NOTE]
> ### 5. ADK output_schema Underutilized
> All ADK agents set `output_schema` but then manually strip markdown fences and call `json.loads()`. The native ADK auto-parsing is bypassed, adding fragility.

> [!NOTE]
> ### 6. Triage Agent Appears Unused in Pipeline
> `triage_agent.py` is defined and has a router, but it is never called from `agent_service.generate_full_report()`. It only runs via the `/triage/{user_id}` endpoint.

---

# Output 6: Mermaid Diagrams

## 6.1 System Architecture Overview

```mermaid
graph TB
    subgraph Users
        F["👨‍🌾 Farmer<br/>(Flutter App)"]
        A["🔧 Admin<br/>(Internal API)"]
    end

    subgraph "Google Cloud Run"
        API["⚡ FastAPI Backend<br/>Python 3.12"]
    end

    subgraph "AI Engine"
        GEM["🧠 Gemini 2.5 Flash<br/>(Vertex AI)"]
        EMB["📐 text-embedding-004<br/>(Vertex AI)"]
        ADK["🔧 Google ADK<br/>(Agent Framework)"]
        MCP["🔌 MongoDB MCP Server<br/>(stdio subprocess)"]
    end

    subgraph "Data Layer"
        MDB[("🍃 MongoDB Atlas<br/>12 Collections")]
    end

    subgraph "External APIs"
        OM["🌤️ Open-Meteo"]
        EP["🐛 EPPO"]
        AG["🛰️ Agromonitoring"]
        MK["📈 FAO / CollectAPI"]
        OSM["🗺️ OSM Overpass"]
    end

    subgraph "On-Device"
        GEMMA["💎 Gemma 4 E2B<br/>(Offline LLM)"]
    end

    F -->|REST/SSE| API
    A -->|Internal webhooks| API
    API -->|PyMongo Async| MDB
    API -->|google-genai SDK| GEM
    API -->|google-genai SDK| EMB
    API -->|ADK Runner| ADK
    ADK -->|stdio JSON-RPC| MCP
    MCP -->|Direct queries| MDB
    API -->|httpx| OM
    API -->|httpx| EP
    API -->|httpx| AG
    API -->|httpx| MK
    API -->|httpx| OSM
    F -.->|flutter_gemma| GEMMA
```

## 6.2 Container Diagram

```mermaid
graph LR
    subgraph "Mobile / Desktop"
        FL["📱 Flutter App<br/>Dart 3.5 · Riverpod · GoRouter<br/>14 Screens · 25 Providers"]
    end

    subgraph "Cloud"
        BE["⚡ FastAPI Backend<br/>16 Routers · 17 Services<br/>9 AI Agents"]
        DB[("🍃 MongoDB 7.0<br/>12 Collections<br/>Vector Search + Change Streams")]
        FB["🌐 Firebase Hosting<br/>Landing Page"]
    end

    subgraph "AI Platform"
        VA["🧠 Vertex AI<br/>Gemini 2.5 Flash<br/>text-embedding-004"]
    end

    FL -->|"HTTPS REST + SSE<br/>JSON + Multipart"| BE
    BE -->|"PyMongo 4.13+<br/>AsyncMongoClient"| DB
    BE -->|"google-genai SDK<br/>Structured Output"| VA
    FL -.->|"Read-only"| FB
```

## 6.3 Backend Component Diagram

```mermaid
graph TB
    subgraph "Router Layer"
        R1["agent"]
        R2["profile"]
        R3["climate"]
        R4["market"]
        R5["threats"]
        R6["satellite"]
        R7["reports"]
        R8["fleet"]
        R9["cooperative"]
        R10["sensor"]
        R11["chilling/gdd/slope"]
        R12["irrigation"]
        R13["triage"]
        R14["internal"]
    end

    subgraph "Service Layer"
        S1["agent_service<br/>(THE BRAIN)"]
        S2["farmer_service"]
        S3["climate_service"]
        S4["market_service"]
        S5["threat_service"]
        S6["satellite_service"]
        S7["report_service"]
        S8["cooperative_service"]
        S9["fleet_service"]
        S10["irrigation_service"]
        S11["coop_service"]
        S12["mongo_session"]
    end

    subgraph "Agent Layer"
        A1["🌱 Agronomist"]
        A2["🤝 Coop"]
        A3["💰 Economist"]
        A4["🌍 Sustainability"]
        A5["📜 Policy"]
        A6["👑 Master"]
        A7["🔍 Scout (Nightly)"]
        A8["⚠️ Triage"]
    end

    subgraph "External API Clients"
        E1["open_meteo"]
        E2["eppo_client"]
        E3["agromonitoring"]
        E4["market_data"]
        E5["geocoding"]
        E6["elevation"]
    end

    R1 --> S1
    R2 --> S2
    R3 --> S3
    R4 --> S4
    R5 --> S5
    R6 --> S6
    R7 --> S7
    R8 --> S9
    R9 --> S8
    R13 --> A8

    S1 --> A1 & A2 & A3 & A4 & A5 & A6
    S1 --> S2 & S3 & S4 & S5 & S6 & S7 & S11 & S12

    A2 --> S11
    A3 --> A5

    S3 --> E1 & E5
    S5 --> E2
    S6 --> E3
    S4 --> E4
    S9 --> E1 & E5
```

## 6.4 Frontend Dependency Graph

```mermaid
graph TB
    subgraph "Screens"
        SC1["HomeScreen"]
        SC2["ChatbotScreen"]
        SC3["FarmerScreen"]
        SC4["ClimateScreen"]
        SC5["ThreatsScreen"]
        SC6["MarketScreen"]
        SC7["ReportScreen"]
        SC8["CooperativesScreen"]
        SC9["LogisticsScreen"]
        SC10["SettingsScreen"]
    end

    subgraph "Providers"
        P1["currentFarmerProvider"]
        P2["currentClimateTrendProvider"]
        P3["currentThreatsProvider"]
        P4["marketForecastProvider"]
        P5["chatNotifierProvider"]
        P6["gemmaNotifierProvider"]
        P7["offlineQueueProvider"]
        P8["themeProvider"]
        P9["localeProvider"]
        P10["previousReportsProvider"]
        P11["fleetProvider"]
    end

    subgraph "Services"
        SV1["AgentApi"]
        SV2["FarmerApi"]
        SV3["ClimateApi"]
        SV4["MarketApi"]
        SV5["ThreatApi"]
        SV6["ReportApi"]
    end

    subgraph "Infrastructure"
        I1["ApiClient (Dio)"]
        I2["SharedPreferences"]
        I3["Gemma 4 E2B"]
    end

    SC1 --> P1 & P2 & P3 & P4 & P11
    SC2 --> P1 & P5 & P6 & SV1
    SC3 --> P1 & SV2
    SC4 --> P2
    SC5 --> P3 & SV1
    SC6 --> P4
    SC7 --> P1 & P10 & SV1
    SC8 --> P1 & P7
    SC9 --> SV1
    SC10 --> P8 & P9 & P6

    P1 --> SV2
    P2 --> SV3
    P3 --> SV5
    P4 --> SV4
    P10 --> SV6
    P5 --> I2
    P6 --> I2 & I3
    P7 --> I2

    SV1 & SV2 & SV3 & SV4 & SV5 & SV6 --> I1
```

## 6.5 AI Agent Pipeline Dependency Graph

```mermaid
graph LR
    subgraph "Data Sources"
        D1["Farmer Profile"]
        D2["Climate Data"]
        D3["Threat Data"]
        D4["Market Data"]
        D5["Satellite Data"]
        D6["Past Reports<br/>(Unified Memory)"]
    end

    subgraph "Agent Pipeline"
        A1["🌱 Agronomist<br/>Agent"]
        A2["🤝 Coop<br/>Agent"]
        A3["💰 Economist<br/>Agent"]
        A4["🌍 Sustainability<br/>Agent"]
        A5["📜 Policy<br/>Agent"]
        A6["👑 Master<br/>Agent"]
    end

    subgraph "Output"
        O1["📄 StrategyReport<br/>(saved to MongoDB)"]
    end

    D1 & D2 & D3 & D5 --> A1
    D1 --> A2
    A1 -->|"top_3_crops"| A2
    A1 -->|"bio analysis"| A3
    A2 -->|"B2B discounts"| A3
    D4 --> A3
    A5 -->|"grant data"| A3
    D1 & D2 --> A4
    D1 --> A5

    A1 & A3 & A4 & A5 --> A6
    D6 -->|"temporal context"| A6
    A6 --> O1
```

---

## Database Schema Map

| Collection | Key Fields | Indexes | Access Pattern |
|------------|------------|---------|----------------|
| `farmers` | user_id, name, location, region, plots[], crops[] | user_id (unique), region, location_geo (2dsphere) | Read-heavy, profile CRUD |
| `climate_trends` | location, region, historical[], forecast | location (unique), region | Cache-first, TTL refresh |
| `regional_threats` | region, active_threats[], overall_risk_level | region, active_threats.reported_date | Cache-first, push on scan |
| `market_data` | crop, current_price, predicted_price, trend | crop (unique) | Nightly refresh |
| `strategy_reports` | user_id, season, recommendations[], created_at | (user_id, created_at) compound | Append-only, read for memory |
| `field_polygons` | user_id, agro_polygon_id, coordinates | user_id, agro_polygon_id (sparse) | Satellite integration |
| `cooperatives` | coop_id, name, region, member_ids[], machines[] | coop_id (unique), join_code (unique), location_geo (2dsphere) | CRUD + geospatial queries |
| `fleet_bookings` | machine_id, date, assignee, status | (machine_id, date) compound unique | 5-day rolling window |
| `sensor_data` | plot_id, timestamp, temperature, humidity, soil_moisture | Time Series (timestamp, plot_id meta) | IoT ingestion + trends |
| `policies` | title, text, embedding[], source, date | Vector index on embedding | RAG via $vectorSearch |
| `adk_sessions` | app_name, user_id, id, events[] | (app_name, user_id, id) | Chat persistence |

---

