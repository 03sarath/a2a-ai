import os
import uvicorn
from google.adk.cli.fast_api import get_fast_api_app

# get_fast_api_app exposes /run and /run_sse endpoints.
# SESSION_SERVICE_URI points to Neon PostgreSQL — sessions persist across
# container restarts and multiple Cloud Run instances.
app = get_fast_api_app(
    agents_dir=os.path.dirname(os.path.abspath(__file__)),
    session_service_uri=os.environ.get("SESSION_SERVICE_URI"),
    allow_origins=["*"],
)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
