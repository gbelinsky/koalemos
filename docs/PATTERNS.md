# Koalemos Code Patterns

This document describes the coding conventions and patterns used in the Koalemos codebase.

## Map Key Conventions

**Rule:** Use atom keys for internal context, string keys for external/LLM data.

### Internal Context (atom keys)
Engine context, step state, and internal data structures use atom keys:

```elixir
# Context passed between steps
%{
  messages: [],
  llm_provider: "anthropic",
  llm_model: "claude-sonnet-4-5",
  max_tokens: 16384
}

# Accessing context in steps
messages = Map.get(state.context, :messages, [])
provider = Map.get(state.context, :llm_provider, "anthropic")
```

### External Data (string keys)
Data from LLM responses, tool parameters, and JSON APIs use string keys:

```elixir
# Tool parameters from LLM
def execute(:modify_classes, params, context, _config) do
  element_id = params["element_id"]
  add_classes = params["add"] || []
  remove_classes = params["remove"] || []
end

# LLM API responses
content = response["content"]
tool_calls = response["tool_use"]
```

### Why This Matters
- Atom keys are efficient for known, bounded sets (our internal structures)
- String keys are safe for unbounded external input (prevents atom table exhaustion)
- Consistent patterns make code predictable

---

## Lens Interface

Lenses provide context and tools to routines. All lenses should follow this interface:

### Required Functions

```elixir
@doc "Return context blocks for LLM prompts"
@spec provide_context(state :: map(), config :: map()) :: list()
def provide_context(state, config \\ %{})
```

### Optional Functions (for lenses that provide tools)

```elixir
@doc "Return list of tool definitions"
@spec tools(config :: map()) :: list()
def tools(config \\ %{})

@doc "Return info about a specific tool"
@spec info(tool_name :: atom()) :: map()
def info(tool_name)

@doc "Execute a tool"
@spec execute(tool_name :: atom(), params :: map(), context :: map(), config :: map()) ::
  {result_string, lens_updates :: keyword()} | result_string
def execute(tool_name, params, context, config \\ %{})
```

### Return Conventions

- `provide_context/2`: Returns list of content blocks (text, images, etc.)
- `tools/1`: Returns list of tool schemas (empty list if no tools)
- `info/1`: Returns map with `:name`, `:description`, `:parameters`
- `execute/4`: Returns either:
  - `{result_string, lens_updates}` - result with state updates
  - `result_string` - simple result, no state updates

### Example Lens

```elixir
defmodule MyLens do
  def provide_context(_state, _config \\ %{}) do
    [%{type: "text", text: "Context from MyLens"}]
  end

  def tools(_config \\ %{}) do
    [%{
      name: "my_tool",
      description: "Does something",
      input_schema: %{type: "object", properties: %{}}
    }]
  end

  def info(:my_tool) do
    %{name: "my_tool", description: "Does something", parameters: %{}}
  end

  def execute(:my_tool, params, _context, _config \\ %{}) do
    {"Tool executed", [some_state: "updated"]}
  end
end
```

---

## Step Parameters

Steps use a consistent 2-argument `execute/2` signature:

```elixir
@spec execute(config_sources :: map(), state :: map()) :: {:ok, map()} | {:error, term()}
def execute(config_sources, state) do
  # config_sources may contain :static and :runtime config
  # state contains :context and other routine state
end
```

**Naming convention:** Use `config_sources` (not `_config` or `config`) for clarity.

When the config is unused, prefix with underscore: `_config_sources`

---

## Error Handling

### In Steps
Steps return tagged tuples:

```elixir
# Success
{:ok, updated_state}

# Failure
{:error, "Human-readable error message"}
{:error, {:validation_error, details}}
```

### In Lens Tool Execution
Tool execution should catch errors and return friendly messages:

```elixir
def execute(:my_tool, params, context, _config) do
  # Validation can raise - will be caught
  validated = validate_params!(params)

  # Do work
  result = process(validated)
  {result, []}
rescue
  error ->
    Logger.error("[MyLens] Tool failed: #{Exception.message(error)}")
    "Tool failed: #{Exception.message(error)}"
end
```

### In LLM Providers
Providers return tagged tuples with structured errors:

```elixir
{:ok, %{content: "...", ...}}
{:error, "API error 429: Rate limited"}
{:error, "Connection refused - check base_url"}
```

---

## LLM Provider Retries

Currently, only the Anthropic provider has retry logic with exponential backoff:

- Retries on: 429 (rate limit), 500, 502, 503, 504, 529 (overloaded)
- Backoff: exponential with jitter, max 30 seconds
- Attempts: up to 3 with increasing timeouts (45s, 90s, 180s)

OpenAI and Ollama providers use single-attempt requests with 120s timeout.

**Future enhancement:** Standardize retry logic across all providers.

---

## LiveView Component Patterns

### File Uploads
Use the `progress` callback in `allow_upload/3` for processing completed uploads:

```elixir
def mount(socket) do
  {:ok,
   socket
   |> allow_upload(:my_file,
     accept: ~w(.txt),
     max_entries: 1,
     auto_upload: true,
     progress: &handle_upload_progress/3
   )}
end

defp handle_upload_progress(:my_file, entry, socket) do
  if entry.done? do
    result = consume_uploaded_entry(socket, entry, fn %{path: path} ->
      {:ok, File.read!(path)}
    end)
    {:noreply, assign(socket, file_content: result)}
  else
    {:noreply, socket}
  end
end
```

### Async Operations in Components
For network calls or slow operations, use Task + send_update pattern:

```elixir
defp start_async_check(socket) do
  component_id = socket.assigns.id
  parent_pid = self()

  Task.start(fn ->
    result = do_slow_operation()
    send(parent_pid, {:async_complete, component_id, result})
  end)

  assign(socket, status: :checking)
end

# In parent LiveView:
def handle_info({:async_complete, component_id, result}, socket) do
  send_update(MyComponent, id: component_id, async_result: result)
  {:noreply, socket}
end
```

### Sensitive Data in Forms
Never send sensitive data (API keys, tokens) to the browser. Use write-only inputs:

```elixir
# Good: placeholder indicates status, doesn't reveal key
<input type="password" placeholder={if @has_key, do: "Key saved", else: "Enter key"} />

# Bad: sends actual key to browser
<input type="password" value={@api_key} />
```
