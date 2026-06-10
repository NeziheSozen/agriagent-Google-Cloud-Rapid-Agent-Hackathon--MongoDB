# 🌾 AgriAgent — AI-Powered Agricultural Decision Support System

A **proactive, multi-agent agricultural advisory platform** that combines real-time climate data, pest/disease threat intelligence, market price analytics, and AI-driven crop strategy to help farmers make data-driven planting decisions.

> Built for the [**Google Cloud Rapid Agent Hackathon**](https://rapid-agent.devpost.com/) — Building Agents for Real-World Challenges  
> 🏷️ Track: [**MongoDB**](https://rapid-agent.devpost.com/details/mongodb-resources)

🌐 **Live Web App:** [https://agri-agent-app.web.app](https://agri-agent-app.web.app)  
📡 **Backend API:** [https://agriagent-backend-385185579211.us-central1.run.app](https://agriagent-backend-385185579211.us-central1.run.app)  
📖 **API Documentation (Swagger):** [https://agriagent-backend-385185579211.us-central1.run.app/docs](https://agriagent-backend-385185579211.us-central1.run.app/docs)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│       Flutter App (Cross-Platform)           │
│    iOS · Android · Web · macOS · Windows     │
│                                              │
│  Riverpod State ─── Dio HTTP ───► REST API   │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│        FastAPI Backend (Cloud Run)            │
│   16 API Routers · 7 AI Agents · RAG         │
│                                              │
│  ┌─────────────────────────────────────────┐ │
│  │        Multi-Agent Pipeline (ADK)        │ │
│  │                                         │ │
│  │  🌿 Agronomist ──► 💰 Economist         │ │
│  │  🤝 Cooperative ──► 🌍 Sustainability   │ │
│  │  📋 Policy RAG ──► 🔬 Triage            │ │
│  │  🕵️ Scout (Nightly ETL)                 │ │
│  │           │                              │ │
│  │           ▼                              │ │
│  │    🎯 Master Agent (Orchestrator)        │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────┬──────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
┌──────────────┐ ┌──────────┐ ┌──────────────┐
│  MongoDB     │ │ Vertex AI│ │ External APIs│
│  Atlas       │ │ Gemini   │ │              │
│              │ │ 2.5 Flash│ │ Open-Meteo   │
│ • farmers    │ │          │ │ EPPO / GBIF  │
│ • market_data│ │ Vector   │ │ hal.gov.tr   │
│ • reports    │ │ Search   │ │ Agromonitor  │
│ • policies   │ │ (RAG)    │ │ API Ninjas   │
│ • coops      │ │          │ │ İzmir API    │
└──────────────┘ └──────────┘ └──────────────┘
```

---

## 📦 Tech Stack

| Layer         | Technology                                              |
|---------------|---------------------------------------------------------|
| **Frontend**  | Flutter 3.x · Riverpod · fl_chart · GoRouter · Dio     |
| **Backend**   | FastAPI · PyMongo 4.13+ (Async) · Pydantic v2           |
| **AI/ML**     | Google ADK · Vertex AI · Gemini 2.5 Flash               |
| **Database**  | MongoDB Atlas (Vector Search + Atlas Search)             |
| **Hosting**   | Google Cloud Run (backend) · Firebase Hosting (web app)  |
| **APIs**      | Open-Meteo · EPPO · GBIF · Agromonitoring · hal.gov.tr  |

---

## 🤖 Multi-Agent System (7 Agents)

| Agent | Role | Data Sources |
|-------|------|--------------|
| 🌿 **Agronomist** | Crop suitability analysis (soil, climate, rotation) | Climate + Threats + Satellite |
| 💰 **Economist** | Financial analysis (revenue, cost, profit, ROI) | Market prices + Cost reference |
| 🤝 **Cooperative** | B2B synergy & bulk purchasing discounts | Cooperative registry |
| 🌍 **Sustainability** | Environmental impact & carbon footprint | Satellite + Climate |
| 📋 **Policy RAG** | Government grants & subsidies matching | MongoDB Vector Search |
| 🔬 **Triage** | Urgency scoring & actionable recommendations | All agent outputs |
| 🕵️ **Scout** | Nightly ETL — scrapes & caches market/weather data | External APIs → MongoDB |

---

## 🚀 Quick Start

### Prerequisites

- **Python 3.12+**
- **Flutter 3.24+**
- **MongoDB Atlas** account (or local MongoDB 7.0+)
- **Google Cloud** project with Vertex AI enabled

### 1. Backend Setup

```bash
cd backend
cp .env.example .env
# Edit .env with your API keys and MongoDB connection string
pip install -r requirements.txt
```

### 2. Seed the Database

```bash
python -m app.seed.seed_data
```

### 3. Start the Backend

```bash
uvicorn app.main:app --reload --port 8000
```

Open **http://localhost:8000/docs** for Swagger UI.

### 4. Run the Flutter App

```bash
cd frontend
flutter pub get
flutter run -d chrome    # Web
flutter run -d macos     # macOS
flutter run -d ios       # iOS Simulator
```

---

## 🔗 API Endpoints (16 Routers)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/profile/{user_id}` | Farmer profile + plot history |
| GET | `/climate-trend/{location}` | 5yr trends + 1yr forecast |
| GET | `/regional-threats/{region}` | Active pest/disease alerts |
| POST | `/market-forecast` | Market prices (150+ crops) |
| POST | `/agent/generate-report` | Generate full AI strategy report |
| POST | `/agent/quick-report` | Quick single-agent report |
| POST | `/agent/triage` | Emergency triage scoring |
| GET | `/reports/{user_id}` | Saved report history |
| GET | `/satellite/{farmer_id}` | NDVI satellite analysis |
| POST | `/coop/create` | Create cooperative |
| POST | `/coop/join` | Join cooperative |
| POST | `/fleet/book` | Book shared machinery |
| GET | `/irrigation/{farmer_id}` | Irrigation recommendations |
| GET | `/gdd/{location}` | Growing degree days |
| GET | `/slope/{lat}/{lon}` | Terrain slope analysis |
| GET | `/health` | Health check |

---

## 🌾 Crop Catalog

**150+ crops and varieties** with real-time market price tracking:

- **Cereals:** Wheat, Durum Wheat, Barley, Corn, Rice, Oat, Rye, Millet, Sorghum
- **Tomato Varieties:** Tomato, Cherry Tomato, Roma Tomato, Beefsteak, Cluster, Pink, Dried
- **Pepper Varieties:** Bell Pepper, Hot Pepper, Capia, Banana, Isot, Dried Red
- **Grape Varieties:** Table Grape, Wine Grape, Sultana, Raisin
- **Olive Varieties:** Table Olive, Oil Olive, Olive Oil
- **Berries:** Strawberry, Raspberry, Blueberry, Blackberry, Mulberry, Cranberry
- **Nuts:** Hazelnut, Walnut, Almond, Pistachio, Pine Nut, Chestnut
- **Herbs & Spices:** Thyme, Oregano, Cumin, Saffron, Sumac, Bay Leaf, Rosemary
- **And 80+ more** including legumes, citrus, tropical fruits, mushrooms, industrial crops

---

## 📁 Project Structure

```
agriagent/
├── backend/                        # FastAPI Backend (71 Python files)
│   ├── app/
│   │   ├── main.py                 # App entry + CORS + lifespan
│   │   ├── config.py               # Pydantic Settings (env-based)
│   │   ├── database.py             # AsyncMongoClient + lifespan
│   │   ├── agents/                 # 7 AI Agents (ADK + Gemini)
│   │   │   ├── agronomist_agent.py
│   │   │   ├── economist_agent.py
│   │   │   ├── coop_agent.py
│   │   │   ├── sustainability_agent.py
│   │   │   ├── master_agent.py
│   │   │   ├── policy_agent.py     # RAG with MongoDB Vector Search
│   │   │   ├── scout_agent.py      # Nightly ETL pipeline
│   │   │   └── triage_agent.py
│   │   ├── models/                 # Pydantic v2 data models
│   │   ├── routers/                # 16 API routers
│   │   ├── services/               # Business logic services
│   │   ├── external_apis/          # External API integrations
│   │   ├── seed/                   # Database seeders
│   │   └── tasks/                  # Background tasks
│   ├── Dockerfile
│   └── requirements.txt
│
├── frontend/                       # Flutter App (79 Dart files)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/                    # Theme, routing, responsive, l10n
│   │   ├── models/                 # Data models
│   │   ├── services/               # API client services
│   │   ├── providers/              # Riverpod state management
│   │   ├── screens/                # Full-page screens
│   │   └── widgets/                # Reusable UI components
│   └── pubspec.yaml
│
│
└── README.md

---

## 🏆 Key Features

1. **Multi-Agent AI Pipeline** — 7 specialized agents collaborate via Google ADK to produce comprehensive crop strategies
2. **150+ Crop Varieties** — Variety-level recommendations (Cherry Tomato vs Roma Tomato) based on farm conditions
3. **Real-Time Market Data** — Nightly cron job caches prices from 5+ sources into MongoDB (<1s response)
4. **Policy RAG** — Government grants & subsidies matched via MongoDB Vector Search
5. **Cooperative System** — Farmers can create/join cooperatives, share machinery, get bulk discounts
6. **Satellite Analysis** — NDVI vegetation health via Agromonitoring (Sentinel-2)
7. **Multilingual** — Full support for 11 languages (Turkish, English, Spanish, French, Chinese, Hindi, etc.) with dynamic AI-generated translations
8. **Cross-Platform** — Single Flutter codebase for iOS, Android, Web, macOS, Windows
9. **Production Architecture** — Async MongoDB, type-safe models, Cloud Run auto-scaling

---

## 🔐 Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill in your credentials:

```env
MONGODB_URL=mongodb+srv://<user>:<pass>@<cluster>.mongodb.net/
AGROMONITORING_API_KEY=your_key
API_NINJAS_KEY=your_key
GCP_PROJECT_ID=your_project_id
```

> See [.env.example](backend/.env.example) for full documentation.

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.
