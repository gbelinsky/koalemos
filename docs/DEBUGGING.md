# Debugging Guide

This guide explains how to debug specific parts of Koalemos using runtime-configurable logging.

## Log Domains

Koalemos uses domain-based logging that can be enabled/disabled at runtime without restarting the server. This allows targeted debugging of specific components.

### Available Domains

| Domain | Description | Key Modules |
|--------|-------------|-------------|
| `:llm` | LLM provider requests and responses | anthropic.ex, openai.ex, ollama.ex |
| `:context` | Context building in provide_context | wireframe_editor.ex, editor_core.ex |
| `:prompts` | Complete system prompts sent to LLM | anthropic.ex, openai.ex, ollama.ex |
| `:engine` | Engine orchestration and step execution | orchestrator.ex, engine.ex |
| `:wireframe` | Wireframe editor operations | wireframe_editor.ex, state_server.ex |
| `:lens` | Lens tool execution | sequential_thinking.ex, semantic_transition.ex |
| `:all` | Enable all domains | All modules |

## Runtime Control

### In Development (IEx)

```elixir
# Enable a domain
Koalemos.LogConfig.enable(:context)

# Enable multiple domains
Koalemos.LogConfig.enable(:context)
Koalemos.LogConfig.enable(:llm)

# Enable everything
Koalemos.LogConfig.enable(:all)

# Disable a domain
Koalemos.LogConfig.disable(:context)

# Disable all domains
Koalemos.LogConfig.disable_all()

# Check what's enabled
Koalemos.LogConfig.list()
```

### Connecting to a Running Server

If you need to debug a running server (e.g., in staging):

```bash
# Start with a named node (if not already)
elixir --sname koalemos -S mix phx.server

# Connect from another terminal
iex --sname debug --remsh koalemos@$(hostname -s)

# Then enable domains
iex> Koalemos.LogConfig.enable(:context)
```

## Common Debugging Scenarios

### Debugging Context Building

When the LLM receives unexpected context or you need to verify what's being sent:

```elixir
Koalemos.LogConfig.enable(:context)
```

This shows the **full context** from each lens (not truncated):
- Each lens's complete text context with lens name
- Image blocks noted as "screenshot included"
- Format: `[LensContext] WireframeEditor (text): <full content>`

The context is logged centrally in the LensRendering step, so you see exactly what each lens contributes.

### Debugging LLM Requests

When you need to see what's being sent to/received from the LLM:

```elixir
Koalemos.LogConfig.enable(:llm)
```

This shows:
- Request details (message count, tool count)
- System content size and block count
- Input/output token usage from response

### Debugging Prompts

When you need to see the complete prompts being sent to the LLM:

```elixir
Koalemos.LogConfig.enable(:prompts)
```

This shows the **full prompts** (not truncated):
- Complete system content (all blocks from lenses + step prompt)
- Message history summary (role + content preview)
- Available tools list

Example output:
```
[info] [Prompt] System content (3 blocks):
You are Claude Code, Anthropic's official CLI for Claude.

---

WIREFRAME EDITOR CONTEXT
...full context here...

---

Make the specific change requested. Be precise and focused.

[info] [Prompt] Messages (2):
  user: Build me a todo app
  assistant: I'll help you build a todo app...

[info] [Prompt] Tools (5):
  - modify_elements
  - manage_handlers
  - manage_css
  - trigger_interaction
  - think
```

### Debugging Engine Flow

When you need to trace routine/step execution:

```elixir
Koalemos.LogConfig.enable(:engine)
```

This shows:
- Step execution start (step name, routine module)
- Transitions between steps

### Debugging Lens Tools

When you need to trace lens tool execution:

```elixir
Koalemos.LogConfig.enable(:lens)
```

This shows:
- Tool invocation (e.g., sequential_thinking progress)

### Debugging the Full Flow

To see everything from user input to LLM response:

```elixir
Koalemos.LogConfig.enable(:all)
```

**Note:** This can be very verbose. Use sparingly.

## Log Output Format

Domain logs include source location metadata:

```
[debug] [Context] Building wireframe context file=wireframe_editor.ex line=99 domain=context
```

This helps identify exactly where a log is coming from. Regular Phoenix/framework logs won't have this metadata.

## Adding Domain Logging to New Code

When adding logging to new modules, use the domain-aware `Koalemos.Log` module:

```elixir
require Koalemos.Log
alias Koalemos.Log

# Simple message
Log.info(:context, "[Context] Building wireframe context")

# Lazy evaluation (expensive computations only run if enabled)
Log.debug(:context, fn ->
  "[Context] DOM tree: #{inspect(dom_tree, limit: 200)}"
end)
```

Available log levels:
- `Log.debug/2` - Detailed debugging info
- `Log.info/2` - General information
- `Log.warning/2` - Warning conditions
- `Log.error/2` - Error conditions

## Troubleshooting

### Logs Not Appearing

1. Check if the domain is enabled:
   ```elixir
   Koalemos.LogConfig.list()
   ```

2. Check the base log level in config:
   ```elixir
   # In dev.exs, ensure level allows debug
   config :logger, level: :debug
   ```

3. Ensure LogConfig is started (should be automatic via supervisor)

### Too Many Logs

1. Disable specific domains you don't need
2. Use `:context` instead of `:all` for context-specific debugging
3. Remember to `disable_all()` when done debugging
