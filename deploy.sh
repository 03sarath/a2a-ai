#!/bin/bash
set -e

# =============================================================================
# STUDENTS: ONLY CHANGE VALUES IN THIS SECTION
# =============================================================================
GCP_PROJECT="your-gcp-project-id"       # Your GCP project ID
GCP_REGION="us-central1"                # Cloud Run region
GOOGLE_API_KEY="your-gemini-api-key"    # From https://aistudio.google.com/apikey
DATABASE_URL="postgresql://USER:PASSWORD@HOST/DBNAME?sslmode=require"
# =============================================================================

GCLOUD=$(which gcloud)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "================================================"
echo " Competitive Intelligence A2A — Full Deployment"
echo "================================================"

# ── Step 1: Enable required GCP APIs ─────────────────────────────────────────
echo "[1/7] Enabling GCP APIs..."
$GCLOUD services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com \
  --project="$GCP_PROJECT"

# Grant compute service account storage access (required for Cloud Build source upload)
PROJECT_NUMBER=$($GCLOUD projects describe "$GCP_PROJECT" --format="value(projectNumber)")
$GCLOUD projects add-iam-policy-binding "$GCP_PROJECT" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# ── Step 2: Store secrets in Secret Manager ──────────────────────────────────
echo "[2/7] Storing secrets in Secret Manager..."
echo "$GOOGLE_API_KEY" | $GCLOUD secrets create GOOGLE_API_KEY \
  --project="$GCP_PROJECT" \
  --data-file=- 2>/dev/null || \
echo "$GOOGLE_API_KEY" | $GCLOUD secrets versions add GOOGLE_API_KEY \
  --project="$GCP_PROJECT" \
  --data-file=-

echo "$DATABASE_URL" | $GCLOUD secrets create SESSION_SERVICE_URI \
  --project="$GCP_PROJECT" \
  --data-file=- 2>/dev/null || \
echo "$DATABASE_URL" | $GCLOUD secrets versions add SESSION_SERVICE_URI \
  --project="$GCP_PROJECT" \
  --data-file=-

# ── Step 3: Grant Cloud Run permission to read the secrets ───────────────────
echo "[3/7] Granting Cloud Run access to Secret Manager..."
PROJECT_NUMBER=$($GCLOUD projects describe "$GCP_PROJECT" --format="value(projectNumber)")
SA="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
$GCLOUD secrets add-iam-policy-binding GOOGLE_API_KEY \
  --project="$GCP_PROJECT" \
  --member="$SA" \
  --role="roles/secretmanager.secretAccessor"
$GCLOUD secrets add-iam-policy-binding SESSION_SERVICE_URI \
  --project="$GCP_PROJECT" \
  --member="$SA" \
  --role="roles/secretmanager.secretAccessor"

# ── Step 4: Helper function — deploy one specialist agent ─────────────────────
deploy_specialist() {
  local SERVICE=$1
  local AGENT_DIR=$2

  echo "  → Deploying $SERVICE..." >&2
  cd "$SCRIPT_DIR/$AGENT_DIR"

  $GCLOUD run deploy "$SERVICE" \
    --source . \
    --region="$GCP_REGION" \
    --project="$GCP_PROJECT" \
    --allow-unauthenticated \
    --update-secrets="GOOGLE_API_KEY=GOOGLE_API_KEY:latest,SESSION_SERVICE_URI=SESSION_SERVICE_URI:latest" \
    --set-env-vars="GOOGLE_GENAI_USE_VERTEXAI=FALSE" >&2

  # Pass the service's own URL back to it (needed for AgentCard)
  local URL
  URL=$($GCLOUD run services describe "$SERVICE" \
    --region="$GCP_REGION" \
    --project="$GCP_PROJECT" \
    --format="value(status.url)")

  $GCLOUD run services update "$SERVICE" \
    --region="$GCP_REGION" \
    --project="$GCP_PROJECT" \
    --set-env-vars="GOOGLE_GENAI_USE_VERTEXAI=FALSE,SERVICE_URL=$URL" >&2

  echo "$URL"
}

# ── Step 5: Deploy the 4 specialist agents ────────────────────────────────────
echo "[5/7] Deploying specialist agents..."

MARKET_SCANNER_URL=$(deploy_specialist     "market-scanner"     "agents/market_scanner")
SENTIMENT_ANALYZER_URL=$(deploy_specialist "sentiment-analyzer" "agents/sentiment_analyzer")
PRICING_INTEL_URL=$(deploy_specialist      "pricing-intel"      "agents/pricing_intelligence")
REPORT_GENERATOR_URL=$(deploy_specialist   "report-generator"   "agents/report_generator")

echo "  ✓ market_scanner     → $MARKET_SCANNER_URL"
echo "  ✓ sentiment_analyzer → $SENTIMENT_ANALYZER_URL"
echo "  ✓ pricing_intel      → $PRICING_INTEL_URL"
echo "  ✓ report_generator   → $REPORT_GENERATOR_URL"

# ── Step 6: Deploy the host agent ─────────────────────────────────────────────
echo "[6/7] Deploying host agent..."
cd "$SCRIPT_DIR/agents/host"

$GCLOUD run deploy competitive-intel-host \
  --source . \
  --region="$GCP_REGION" \
  --project="$GCP_PROJECT" \
  --allow-unauthenticated \
  --update-secrets="GOOGLE_API_KEY=GOOGLE_API_KEY:latest,SESSION_SERVICE_URI=SESSION_SERVICE_URI:latest" \
  --set-env-vars="GOOGLE_GENAI_USE_VERTEXAI=FALSE,MARKET_SCANNER_URL=$MARKET_SCANNER_URL,SENTIMENT_ANALYZER_URL=$SENTIMENT_ANALYZER_URL,PRICING_INTEL_URL=$PRICING_INTEL_URL,REPORT_GENERATOR_URL=$REPORT_GENERATOR_URL"

HOST_URL=$($GCLOUD run services describe competitive-intel-host \
  --region="$GCP_REGION" \
  --project="$GCP_PROJECT" \
  --format="value(status.url)")

# ── Step 7: Done ──────────────────────────────────────────────────────────────
echo "[7/7] Done!"
echo ""
echo "================================================"
echo " All 5 agents deployed successfully!"
echo "================================================"
echo " Host URL : $HOST_URL"
echo " Open UI  : ui/index.html → paste the Host URL"
echo "================================================"
