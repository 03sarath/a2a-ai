# Competitive Intelligence — A2A Multi-Agent System

4 specialist agents deployed as independent Cloud Run services, orchestrated by a host agent using Google's A2A protocol.

## Architecture

```
User → host-agent (Cloud Run + PostgreSQL session)
         → market_scanner     (Cloud Run, stateless)
         → sentiment_analyzer (Cloud Run, stateless)
         → pricing_intel      (Cloud Run, stateless)
         → report_generator   (Cloud Run, stateless)
         ← final report returned to user
```

## Prerequisites

1. **GCP project** with billing enabled
2. **Gemini API key** → https://aistudio.google.com/apikey
3. **Neon PostgreSQL** (free) → https://neon.tech → create project → copy connection string
4. **Tools installed**:
   ```bash
   pip install google-adk==1.9.0 a2a-sdk==0.3.0
   gcloud auth login
   gcloud auth application-default login
   ```

## Student Setup (Only 4 values to change)

Open `deploy.sh` and update the top section:

```bash
GCP_PROJECT="your-gcp-project-id"
GCP_REGION="us-central1"
GOOGLE_API_KEY="your-gemini-api-key"
DATABASE_URL="postgresql+asyncpg://user:pass@host/db?sslmode=require"
```

## Deploy

```bash
chmod +x deploy.sh
./deploy.sh
```

Script deploys all 5 services in order and prints the final host URL.

## Test

```bash
curl -X POST https://YOUR-HOST-URL/run \
  -H "Content-Type: application/json" \
  -d '{"message": "Analyze competitor: OpenAI"}'
```

## Why DatabaseSessionService on the host?

Cloud Run scales horizontally — multiple container instances can handle requests.
Without a shared database, each instance has its own memory and sessions don't
persist across restarts. PostgreSQL (Neon) gives all instances a single shared
session store. ADK reads `SESSION_SERVICE_URI` automatically.

Specialist agents use `InMemorySessionService` because they are truly stateless —
each A2A call is a single short task with no state to preserve.
