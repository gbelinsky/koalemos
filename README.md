# Koalemos

**A developer framework for building conversational AI applications with sophisticated workflows, pluggable capabilities, and stateful interactions.**

Built with Phoenix LiveView and Elixir.

---

## What is Koalemos?

Koalemos is not just an application – it's a **framework** for developers who want to build AI-powered applications with:

- **Complex Conversation Flows** - State machines (routines) that define multi-step workflows
- **Pluggable Capabilities** - Lenses provide context and tools to agents
- **Tool Execution** - Structured, validated tool calls with state management
- **Real-time Updates** - LiveView-powered UI with instant feedback
- **Multi-Provider Support** - Anthropic Claude, OpenAI, Ollama (local)

**Current Demo:** Interactive wireframe editor where an AI agent helps you build HTML prototypes through conversation.

---

## Key Concepts

### Routines (Workflows)

State machines that define conversation flows. Each routine specifies steps and transitions:

```elixir
def routine_definition do
  %{
    start: %{type: ChatUserInput, transitions: [{:process, :always}]},
    process: %{type: LLMRequest, transitions: [{:start, :always}]}
  }
end
```

**Examples:**
- `TestChatRoutine` - Simple agent loop
- `WireframeTestRoutine` - Full tool execution with feedback loop
- `PersonaTestRoutine` - Configurable AI personality

→ **Learn more:** [`docs/guides/ROUTINE_DEVELOPMENT.md`](docs/guides/ROUTINE_DEVELOPMENT.md)

### Lenses (Capabilities)

Pluggable modules that provide context and/or tools to agents:

**Context-Only Lenses:**
- `PersonaLens` - Configure AI tone, expertise, style

**Tool-Providing Lenses:**
- `SequentialThinking` - Step-by-step reasoning with visible thought process
- `WireframeEditor` - Interactive HTML editing with 9 tools (modify DOM, CSS, JavaScript, etc.)

→ **Learn more:** [`docs/guides/LENS_DEVELOPMENT.md`](docs/guides/LENS_DEVELOPMENT.md)

### Engine

GenServer-based execution engine that:
- Manages routine lifecycle
- Executes steps with state transitions
- Handles tool execution with lens state updates
- Coordinates events via PubSub

→ **Learn more:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

---

## Features (Milestone 4)

### M4 Highlights

**Advanced Lens System:**
- ✅ PersonaLens (dimensional persona configuration)
- ✅ SequentialThinking (structured reasoning chains)
- ✅ WireframeEditor (interactive HTML editing)

**Tool Execution Infrastructure:**
- ✅ 9 tools for wireframe manipulation (DOM, CSS, JavaScript)
- ✅ Tool schema validation (Anthropic format)
- ✅ Lens state management across turns
- ✅ Tool execution feedback loop

**Feedback Loop:**
- ✅ State snapshot coordination via PubSub
- ✅ Live DOM capture from browser
- ✅ Console output integration
- ✅ Screenshot capture (html2canvas)
- ✅ Designed vs running state comparison

**Developer Experience:**
- ✅ Test infrastructure (sample wireframes, interactive test pages)
- ✅ Modular architecture (clean separation of concerns)
- ✅ Comprehensive documentation (1,200+ lines of guides)
- ✅ 92.4% test coverage (782 tests)

### Core Platform Features

**Multi-Provider Support:**
- Anthropic Claude (API key + OAuth)
- OpenAI (API key)
- Ollama (local models)

**Real-time UI:**
- Phoenix LiveView with PubSub
- WebSocket-based updates
- LiveView-in-iframe pattern for previews

**Developer Tools:**
- Manual test pages at `/test/wireframe`, `/test/lens-combinator`
- Debug panel (dev environment)
- Event observer with file logging

---

## Quick Start for Developers

### Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- Node.js 18+ (for asset compilation and JavaScript parsing)
- An LLM API key (Anthropic or OpenAI) OR Ollama running locally

### Setup

1. **Clone and install dependencies:**
   ```bash
   git clone https://github.com/yourusername/koalemos.git
   cd koalemos
   mix setup
   ```

2. **Configure credentials:**
   Create `.koalemos/.credentials.json`:
   ```json
   {
     "providers": {
       "anthropic": {"api_key": "sk-...", "model": "claude-sonnet-4-5"},
       "openai": {"api_key": "sk-...", "model": "gpt-4o"},
       "ollama": {"base_url": "http://localhost:11434", "model": "qwen2.5"}
     },
     "selected_provider": "anthropic"
   }
   ```

3. **Start the server:**
   ```bash
   mix phx.server
   ```

4. **Open your browser:**
   - Main app: http://localhost:4000
   - Wireframe test: http://localhost:4000/test/wireframe
   - Lens combinator: http://localhost:4000/test/lens-combinator

### Your First Lens

Create a simple context-only lens:

```elixir
# lib/koalemos/lenses/my_lens.ex
defmodule Koalemos.Lenses.MyLens do
  @moduledoc "Provides helpful context to the agent"

  def provide_context(_context, _config) do
    [%{
      type: "text",
      text: """
      ## My Custom Context

      This information will be injected into the agent's system prompt.
      You can provide instructions, domain knowledge, or current state.
      """
    }]
  end
end
```

Use it in a routine:

```elixir
def initial_context do
  %{
    lenses: ["Koalemos.Lenses.MyLens"]
  }
end
```

→ **Learn more:** [`docs/guides/LENS_DEVELOPMENT.md`](docs/guides/LENS_DEVELOPMENT.md)

### Your First Routine

Create a simple chat routine:

```elixir
# lib/koalemos/routines/my_routine.ex
defmodule Koalemos.Routines.MyRoutine do
  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{LensRendering, LLMRequest, ResponseParsing}

  def routine_definition do
    %{
      start: %{type: ChatUserInput, transitions: [{:render, :always}]},
      render: %{type: LensRendering, transitions: [{:llm, :always}]},
      llm: %{type: LLMRequest, transitions: [{:parse, :always}]},
      parse: %{type: ResponseParsing, transitions: [{:start, :always}]}
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{
      messages: [],
      lenses: ["Koalemos.Lenses.MyLens"],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5"
    }
  end
end
```

→ **Learn more:** [`docs/guides/ROUTINE_DEVELOPMENT.md`](docs/guides/ROUTINE_DEVELOPMENT.md)

---

## Documentation

**Comprehensive Guides:**
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - Deep dive into system architecture (1,300 lines)
- [`docs/guides/LENS_DEVELOPMENT.md`](docs/guides/LENS_DEVELOPMENT.md) - How to create lenses (1,100 lines)
- [`docs/guides/ROUTINE_DEVELOPMENT.md`](docs/guides/ROUTINE_DEVELOPMENT.md) - How to create routines (1,400 lines)
- [`docs/LLM_PROVIDER_GUIDE.md`](docs/LLM_PROVIDER_GUIDE.md) - How to add LLM providers

**Other Resources:**
- [`docs/testing/MANUAL_TEST_GUIDE.md`](docs/testing/MANUAL_TEST_GUIDE.md) - Manual testing scenarios
- [`docs/milestones/M4.md`](docs/milestones/M4.md) - Milestone 4 sprint breakdown
- [`docs/BACKLOG.md`](docs/BACKLOG.md) - Development backlog and roadmap

**Example Code:**
- Context-only lens: [`lib/koalemos/lenses/persona_lens.ex`](lib/koalemos/lenses/persona_lens.ex)
- Tool-providing lens: [`lib/koalemos/lenses/sequential_thinking.ex`](lib/koalemos/lenses/sequential_thinking.ex)
- Advanced lens: [`lib/koalemos/lenses/wireframe_editor/`](lib/koalemos/lenses/wireframe_editor/)
- Simple routine: [`lib/koalemos/routines/test_chat_routine.ex`](lib/koalemos/routines/test_chat_routine.ex)
- Complex routine: [`lib/koalemos/routines/wireframe_test_routine.ex`](lib/koalemos/routines/wireframe_test_routine.ex)

---

## Architecture Overview

```
User Browser
    ↓ WebSocket
Phoenix LiveView Layer (UI, PubSub)
    ↓
Engine (GenServer)
  ├─ Orchestrator (step execution, transitions)
  ├─ EventHandler (external events, waiting)
  └─ Observer (event recording, broadcasting)
    ↓
Routines (state machines)
    ↓
┌─────────────┬─────────────┐
│   Steps     │   Lenses    │
│ (execution) │(capabilities)│
└─────────────┴─────────────┘
    ↓
Infrastructure
  ├─ LLM Providers (Anthropic, OpenAI, Ollama)
  ├─ Parsers (HTML, JavaScript, CSS)
  └─ Caches (Screenshot, DOM, Console)
```

→ **Full details:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

---

## Testing

### Run Tests

```bash
# All tests (excludes real API tests)
mix test

# With coverage
mix coveralls

# Include real API tests (requires credentials)
mix test --include real_api
```

### Manual Testing

Interactive test pages:
- **Wireframe Editor:** http://localhost:4000/test/wireframe
  - Test all 9 wireframe tools
  - Load sample wireframes (simple, medium, complex)
  - Full feedback loop demonstration

- **Lens Combinator:** http://localhost:4000/test/lens-combinator
  - Test multiple lens combinations
  - PersonaLens configuration
  - SequentialThinking reasoning

→ **Manual test guide:** [`docs/testing/MANUAL_TEST_GUIDE.md`](docs/testing/MANUAL_TEST_GUIDE.md)

---

## Project Status

**Current Milestone:** M4 (Advanced Lens System) - Sprint 8 of 8

**Completed:**
- ✅ M1: Engine Foundation (79.2% coverage, 235 tests)
- ✅ M2: UI Foundation + Simple Agent Loop (chat works)
- ✅ M3: Infrastructure (screenshots, parsers, provider config)
- ✅ M4 Sprint 1-7: Three advanced lenses, tool execution, feedback loop

**In Progress:**
- 🔄 M4 Sprint 8: Developer documentation, production roadmap

**Next:**
- M5: WireframeDesign Routine (end-to-end workflow with phases)
- M6: Polish & Production-Ready (deployment, monitoring, docs)

→ **Full roadmap:** [`docs/BACKLOG.md`](docs/BACKLOG.md)

---

## Use Cases

Koalemos framework enables:

1. **Conversational Interfaces** - Build chat applications with complex workflows
2. **Tool-Using Agents** - Agents that can execute structured operations
3. **Interactive Editors** - Collaborative editing tools (wireframes, code, documents)
4. **Task Management** - Agents that manage tasks, projects, workflows
5. **Code Analysis** - Agents that understand and modify codebases
6. **Custom Workflows** - Any multi-step conversation pattern you can imagine

**Current Demo:** Wireframe editor where you describe changes in natural language and the agent executes them through tools.

---

## Contributing

**Want to contribute?**

1. Read the comprehensive guides in `docs/guides/`
2. Study existing lenses and routines
3. Build your own lens or routine
4. Share patterns and improvements

**Areas to explore:**
- New lens types (database, API, file system, etc.)
- New routine patterns (code review, debugging, planning)
- Performance optimizations
- Additional LLM providers
- Enhanced testing utilities

---

## License

[Specify your license here]

---

## Questions?

- **Architecture:** See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- **Lens Development:** See [`docs/guides/LENS_DEVELOPMENT.md`](docs/guides/LENS_DEVELOPMENT.md)
- **Routine Development:** See [`docs/guides/ROUTINE_DEVELOPMENT.md`](docs/guides/ROUTINE_DEVELOPMENT.md)
- **Issues:** Open an issue on GitHub

---

**Built with ❤️ using Elixir, Phoenix LiveView, and Claude AI**
