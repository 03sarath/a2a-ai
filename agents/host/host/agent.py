import os
import sys
from google.adk.agents import SequentialAgent
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent
from a2a.utils.constants import AGENT_CARD_WELL_KNOWN_PATH

# Validate required env vars at startup — fail fast with a clear message
_REQUIRED = ["MARKET_SCANNER_URL", "SENTIMENT_ANALYZER_URL", "PRICING_INTEL_URL", "REPORT_GENERATOR_URL"]
_missing = [v for v in _REQUIRED if not os.environ.get(v)]
if _missing:
    sys.exit(f"Missing required environment variables: {', '.join(_missing)}")

# ── Remote specialist agents ──────────────────────────────────────────────────
# Each URL points to a deployed Cloud Run service.
# The host agent calls them over HTTPS using the A2A protocol.
# Context (previous agent outputs) is accumulated here on the host and
# forwarded automatically with each sequential call.

remote_market_scanner = RemoteA2aAgent(
    name="scan_market",
    description="Scans the web for recent competitor news and strategic moves",
    agent_card=f"{os.environ['MARKET_SCANNER_URL']}{AGENT_CARD_WELL_KNOWN_PATH}",
)

remote_sentiment_analyzer = RemoteA2aAgent(
    name="analyze_sentiment",
    description="Analyzes public sentiment and brand perception of the competitor",
    agent_card=f"{os.environ['SENTIMENT_ANALYZER_URL']}{AGENT_CARD_WELL_KNOWN_PATH}",
)

remote_pricing_intelligence = RemoteA2aAgent(
    name="analyze_pricing",
    description="Extracts and analyzes competitor pricing tiers and strategy",
    agent_card=f"{os.environ['PRICING_INTEL_URL']}{AGENT_CARD_WELL_KNOWN_PATH}",
)

remote_report_generator = RemoteA2aAgent(
    name="generate_report",
    description="Synthesizes all findings into an executive intelligence brief",
    agent_card=f"{os.environ['REPORT_GENERATOR_URL']}{AGENT_CARD_WELL_KNOWN_PATH}",
)

# ── Host agent (orchestrator) ─────────────────────────────────────────────────
# SequentialAgent runs the 4 remote agents in order.
# Each agent's output is added to the session context on this host,
# so the next agent always receives the full conversation history.
# Session is persisted in PostgreSQL via SESSION_SERVICE_URI env var —
# ADK reads this automatically when using adk deploy cloud_run.

root_agent = SequentialAgent(
    name="competitive_intel_host",
    description="Orchestrates market scan, sentiment, pricing, and report generation",
    sub_agents=[
        remote_market_scanner,
        remote_sentiment_analyzer,
        remote_pricing_intelligence,
        remote_report_generator,
    ],
)
