# Koalemos

A conversational AI platform with pluggable routines and lenses, built with Phoenix LiveView and Elixir.

## Features (Milestone 2)

- **Chat Interface**: Real-time chat with AI through a clean, responsive UI
- **Multi-Provider Support**: Choose between Anthropic Claude, OpenAI, or local Ollama models
- **Routine Engine**: Flexible agent loop architecture (ChatUserInput → LensRendering → LLMRequest → ResponseParsing)
- **Live Updates**: Real-time status updates, thinking indicators, and message streaming
- **Developer Tools**: Debug panel (dev only) showing config, errors, and events
- **Lens System**: Contextual information injection for AI conversations

## Getting Started

### Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- Node.js 18+ (for asset compilation)
- PostgreSQL (if using database features)

### Setup

1. Install dependencies:
   ```bash
   mix setup
   ```

2. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

3. Visit [`localhost:4000`](http://localhost:4000) from your browser

### Configuration

Provider credentials can be configured in `.koalemos/.credentials.json` (see `docs/LLM_PROVIDER_GUIDE.md` for details).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
