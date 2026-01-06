# Koalemos

Koalemos is a framework for building conversational AI applications in Elixir. It provides routines (state machines that define conversation flows), lenses (pluggable modules that give agents context and tools), and an execution engine that coordinates everything. The included wireframe editor demo shows these concepts in action.

## Quick Start

### Run the Demo

```bash
docker run -p 4000:4000 -e ANTHROPIC_API_KEY=sk-ant-... ghcr.io/gbelinsky/koalemos
```

Open http://localhost:4000

See [docs/QUICKSTART.md](docs/QUICKSTART.md) for Ollama and other options.

### Build from Source

Requirements: Elixir 1.14+, Erlang/OTP 25+, Node.js 18+

```bash
git clone https://github.com/gbelinsky/koalemos.git
cd koalemos
mix setup
```

Create `.koalemos/.credentials.json`:

```json
{
  "providers": {
    "anthropic": {"api_key": "sk-ant-..."}
  },
  "selected_provider": "anthropic"
}
```

Start the server:

```bash
mix phx.server
```

Open http://localhost:4000

## Documentation

### Building Applications

| Guide | Description |
|-------|-------------|
| [Routine Development](docs/guides/ROUTINE_DEVELOPMENT.md) | Create conversation flows with state machines |
| [Lens Development](docs/guides/LENS_DEVELOPMENT.md) | Add context and tools to agents |
| [Semantic Routing](docs/guides/SEMANTIC_ROUTING.md) | Let agents choose their own paths |
| [LLM Providers](docs/guides/LLM_PROVIDER_GUIDE.md) | Add support for new LLM APIs |

### Setup and Operations

| Guide | Description |
|-------|-------------|
| [Credentials Setup](docs/guides/CREDENTIALS_SETUP.md) | Configure API keys for Anthropic, OpenAI, Ollama |
| [Docker Guide](docs/guides/DOCKER_GUIDE.md) | Container deployment and configuration |
| [Debugging](docs/DEBUGGING.md) | Runtime logging and troubleshooting |

### Reference

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | System design and component overview |
| [Patterns](docs/PATTERNS.md) | Code conventions and common patterns |
| [Contributing](docs/CONTRIBUTING.md) | How to contribute to Koalemos |

## The Wireframe Editor

The wireframe editor is a reference application that demonstrates Koalemos capabilities. It lets you build HTML prototypes through conversation with an AI agent. The agent can create and modify DOM elements, CSS styles, and JavaScript handlers, then test interactions and see the results.

The editor uses several routines working together:

- `WireframeDesignRoutine` routes requests to specialized sub-routines
- `BuildWireframeRoutine` creates new wireframes through a multi-stage process
- `PlayRoutine` provides a tight interaction loop for testing

The `WireframeEditor` lens gives the agent tools for DOM manipulation, CSS management, and interaction testing, plus context about the current wireframe state.

## License

MIT License. See [LICENSE](LICENSE) for details.
