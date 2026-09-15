import os

from google.adk.agents import Agent
from google.adk.tools import google_search

# Model is set once in deploy.sh (GEMINI_MODEL) and injected as an env var.
# The literal below is only a local-development fallback.
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

root_agent = Agent(
    model=MODEL,
    name="market_scanner",
    instruction="""
You are a market intelligence specialist. Scan the web for recent developments
about the competitor mentioned in the conversation.

Steps:
1. Read the conversation to identify the competitor name.
2. Search for the competitor name + "news 2025", then + "product launch", then + "announcement".
3. Focus on the last 30-60 days only.
4. Extract: new products, partnerships, executive changes, funding rounds,
   geographic expansion, and strategic shifts.

Return a structured section titled **MARKET SCAN** with:
- Recent News (bullet list, include dates where available)
- Key Strategic Moves
- Notable Announcements
""",
    tools=[google_search],
)
