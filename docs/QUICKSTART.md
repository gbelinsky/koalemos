# Quick Start

Run the wireframe editor demo in under a minute.

## Option 1: Docker (Recommended)

```bash
docker run -p 4000:4000 -e ANTHROPIC_API_KEY=sk-ant-... ghcr.io/gbelinsky/koalemos
```

Open http://localhost:4000

## Option 2: Local Ollama (Experimental)

> **Warning:** Ollama support is experimental and may not work reliably. Anthropic is recommended.

If you have Ollama running locally:

```bash
docker run -p 4000:4000 \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -e LLM_PROVIDER=ollama \
  ghcr.io/gbelinsky/koalemos
```

## What You Can Do

The wireframe editor lets you build HTML prototypes through conversation. Ask the agent to create forms, layouts, interactive elements, or games. The agent can modify HTML, CSS, and JavaScript, then test the results.

Try: "Build me a simple todo list with add and delete buttons"

## Next Steps

For detailed setup options, see [CREDENTIALS_SETUP.md](guides/CREDENTIALS_SETUP.md).

To build applications using Koalemos, see [ROUTINE_DEVELOPMENT.md](guides/ROUTINE_DEVELOPMENT.md).
