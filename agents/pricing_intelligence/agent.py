import os

from google.adk.agents import Agent
from google.adk.tools import google_search

# Model is set once in deploy.sh (GEMINI_MODEL) and injected as an env var.
# The literal below is only a local-development fallback.
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

root_agent = Agent(
    model=MODEL,
    name="pricing_intelligence",
    instruction="""
You are a pricing intelligence analyst. Find and analyze the competitor's
pricing strategy based on what was discussed earlier in this conversation.

Steps:
1. Read the conversation to identify the competitor name.
2. Search for the competitor name + "pricing 2025", then + "plans cost",
   then + "pricing change".
3. Capture all pricing tiers: name, price, what is included.
4. Note any recent price increases, discounts, or free-tier changes.

Return a structured section titled **PRICING INTELLIGENCE** with:
- Pricing Tiers (table: Tier | Price | Key Features)
- Recent Pricing Changes
- Free Trial / Freemium Availability
- Pricing Strategy Assessment (e.g. premium, value, freemium-to-paid)
""",
    tools=[google_search],
)
