import os
import uvicorn
from agent import root_agent

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.adk.artifacts import InMemoryArtifactService
from google.adk.memory.in_memory_memory_service import InMemoryMemoryService
from google.adk.a2a.executor.a2a_agent_executor import A2aAgentExecutor, A2aAgentExecutorConfig
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import AgentCard, AgentCapabilities, AgentSkill, TransportProtocol

SERVICE_URL = os.environ.get("SERVICE_URL", "http://localhost:8080")

agent_card = AgentCard(
    name="Report Generator Agent",
    url=SERVICE_URL,
    description="Synthesizes all findings into an executive intelligence brief",
    version="1.0",
    capabilities=AgentCapabilities(streaming=True),
    default_input_modes=["text/plain"],
    default_output_modes=["text/plain"],
    preferred_transport=TransportProtocol.jsonrpc,
    skills=[
        AgentSkill(
            id="generate_report",
            name="Generate Report",
            description="Synthesizes competitive intelligence into an executive brief",
            tags=["report", "competitive intelligence"],
            examples=["Generate competitive report for Anthropic"],
        )
    ],
)

runner = Runner(
    app_name=root_agent.name,
    agent=root_agent,
    artifact_service=InMemoryArtifactService(),
    session_service=InMemorySessionService(),
    memory_service=InMemoryMemoryService(),
)

executor = A2aAgentExecutor(runner=runner, config=A2aAgentExecutorConfig())
handler = DefaultRequestHandler(agent_executor=executor, task_store=InMemoryTaskStore())
app = A2AStarletteApplication(agent_card=agent_card, http_handler=handler).build()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
