#!/bin/bash
set -e

# =============================================================================
# STUDENTS: ONLY CHANGE VALUES IN THIS SECTION
# =============================================================================
GCP_PROJECT="your-gcp-project-id"       # Your GCP project ID
GCP_REGION="us-central1"                # Cloud Run region
GOOGLE_API_KEY="your-gemini-api-key"    # From https://aistudio.google.com/apikey
DATABASE_URL="postgresql+asyncpg://USER:PASSWORD@HOST/DBNAME?sslmode=require"
# =============================================================================

echo "================================================"
echo " Competitive Intelligence A2A — Full Deployment"
echo "================================================"

# ── Step 1: Enable required GCP APIs ─────────────────────────────────────────
echo "[1/7] Enabling GCP APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  --project="$GCP_PROJECT"

# ── Step 2: Install ADK + fix PATH ───────────────────────────────────────────
echo "[2/7] Installing ADK..."
pip install -q google-adk==1.9.0 a2a-sdk==0.3.0

# ~/.local/bin is where pip installs scripts — add it so adk is found
export PATH="$HOME/.local/bin:$PATH"

# Resolve full paths once — these work inside subshells and functions
ADK="$HOME/.local/bin/adk"
GCLOUD=$(which gcloud)

# ADK deploy reads these env vars internally
export GOOGLE_CLOUD_PROJECT="$GCP_PROJECT"
export GOOGLE_CLOUD_LOCATION="$GCP_REGION"
export GOOGLE_GENAI_USE_VERTEXAI="FALSE"

# ── Step 3: Store API key in Secret Manager ───────────────────────────────────
echo "[3/7] Storing API key in Secret Manager..."
echo "$GOOGLE_API_KEY" | $GCLOUD secrets create GOOGLE_API_KEY \
  --project="$GCP_PROJECT" \
  --data-file=- 2>/dev/null || \
echo "$GOOGLE_API_KEY" | $GCLOUD secrets versions add GOOGLE_API_KEY \
  --project="$GCP_PROJECT" \
  --data-file=-

# ── Step 4: Grant Cloud Run permission to read the secret ─────────────────────
echo "[4/7] Granting Cloud Run access to Secret Manager..."
PROJECT_NUMBER=$($GCLOUD projects describe "$GCP_PROJECT" --format="value(projectNumber)")
$GCLOUD secrets add-iam-policy-binding GOOGLE_API_KEY \
  --project="$GCP_PROJECT" \
  --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# ── Step 5: Deploy the 4 specialist agents ────────────────────────────────────
echo "[5/7] Deploying specialist agents..."

deploy_specialist() {
  local NAME=$1
  local SERVICE=$2
  local AGENT_PATH=$3   # renamed from PATH to avoid shadowing the system $PATH

  echo "  → Deploying $NAME..."
  $ADK deploy cloud_run \
    --project="$GCP_PROJECT" \
    --region="$GCP_REGION" \
    --service_name="$SERVICE" \
    "$AGENT_PATH"

  $GCLOUD run services update "$SERVICE" \
    --region="$GCP_REGION" \
    --update-secrets="GOOGLE_API_KEY=GOOGLE_API_KEY:latest" \
    --set-env-vars="GOOGLE_GENAI_USE_VERTEXAI=FALSE"

  # Allow unauthenticated access (public endpoint for learning/demo)
  $GCLOUD run services add-iam-policy-binding "$SERVICE" \
    --region="$GCP_REGION" \
    --member="allUsers" \
    --role="roles/run.invoker"

  $GCLOUD run services describe "$SERVICE" \
    --region="$GCP_REGION" \
    --format="value(status.url)"
}

MARKET_SCANNER_URL=$(deploy_specialist     "market_scanner"       "market-scanner"     ./agents/market_scanner)
SENTIMENT_ANALYZER_URL=$(deploy_specialist "sentiment_analyzer"   "sentiment-analyzer" ./agents/sentiment_analyzer)
PRICING_INTEL_URL=$(deploy_specialist      "pricing_intelligence" "pricing-intel"      ./agents/pricing_intelligence)
REPORT_GENERATOR_URL=$(deploy_specialist   "report_generator"     "report-generator"   ./agents/report_generator)

echo "  ✓ market_scanner     → $MARKET_SCANNER_URL"
echo "  ✓ sentiment_analyzer → $SENTIMENT_ANALYZER_URL"
echo "  ✓ pricing_intel      → $PRICING_INTEL_URL"
echo "  ✓ report_generator   → $REPORT_GENERATOR_URL"

# ── Step 6: Deploy the host agent ─────────────────────────────────────────────
# Host uses PostgreSQL (Neon) so sessions persist across restarts and instances.
echo "[6/7] Deploying host agent..."
$ADK deploy cloud_run \
  --project="$GCP_PROJECT" \
  --region="$GCP_REGION" \
  --service_name="competitive-intel-host" \
  ./agents/host

$GCLOUD run services update competitive-intel-host \
  --region="$GCP_REGION" \
  --update-secrets="GOOGLE_API_KEY=GOOGLE_API_KEY:latest" \
  --set-env-vars="\
GOOGLE_GENAI_USE_VERTEXAI=FALSE,\
SESSION_SERVICE_URI=$DATABASE_URL,\
MARKET_SCANNER_URL=$MARKET_SCANNER_URL,\
SENTIMENT_ANALYZER_URL=$SENTIMENT_ANALYZER_URL,\
PRICING_INTEL_URL=$PRICING_INTEL_URL,\
REPORT_GENERATOR_URL=$REPORT_GENERATOR_URL"

$GCLOUD run services add-iam-policy-binding competitive-intel-host \
  --region="$GCP_REGION" \
  --member="allUsers" \
  --role="roles/run.invoker"

HOST_URL=$($GCLOUD run services describe competitive-intel-host \
  --region="$GCP_REGION" --format="value(status.url)")

# ── Step 7: Print summary ─────────────────────────────────────────────────────
echo "[7/7] Done!"
echo ""
echo "================================================"
echo " All 5 agents deployed successfully!"
echo "================================================"
echo " Host URL : $HOST_URL"
echo " Open UI  : ui/index.html → paste the Host URL"
echo "================================================"
