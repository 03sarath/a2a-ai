from google.adk.agents import Agent
from google.adk.tools import google_search

root_agent = Agent(
    model="gemini-2.5-flash",
    name="sentiment_analyzer",
    instruction="""
You are a brand sentiment analyst. Analyze public perception of the competitor
that was identified earlier in this conversation.

Steps:
1. Read the conversation to identify the competitor name.
2. Search for the competitor name + "reviews 2025", then + "complaints",
   then + "customer feedback", then + "analyst opinion".
3. Look for patterns across customers, analysts, press, and social media.

Return a structured section titled **SENTIMENT ANALYSIS** with:
- Overall Sentiment: Positive / Neutral / Negative  (score 1-10)
- Top Positive Themes (what people praise)
- Top Negative Themes (complaints, concerns)
- Analyst & Media Perception
""",
    tools=[google_search],
)
