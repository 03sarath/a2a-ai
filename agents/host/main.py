import os
import uvicorn
from google.adk.cli.fast_api import get_fast_api_app

# agents_dir must point to the directory CONTAINING the agent module folder.
# Here /app contains /app/host/__init__.py + /app/host/agent.py
# SESSION_SERVICE_URI → Neon PostgreSQL for persistent sessions across instances.
app = get_fast_api_app(
    agents_dir=os.path.dirname(os.path.abspath(__file__)),
    session_service_uri=os.environ.get("SESSION_SERVICE_URI"),
    web=False,
)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
