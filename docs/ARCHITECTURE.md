# Koalemos - System Architecture

**Last Updated:** November 11, 2025
**Status:** Living Document

---

## Overview

Koalemos is a conversational AI platform built on Phoenix LiveView and a custom execution engine. While the current application focus is wireframe design, the architecture is designed as a **developer framework** for building any conversational AI application with complex workflows, tool execution, and stateful interactions.

**Key Philosophy:** Koalemos is not just an application – it's a framework for building AI-powered applications with sophisticated conversation flows, pluggable capabilities (lenses), and reusable workflows (routines).

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         User Browser                        │
│  ┌──────────────────┐               ┌───────────────────┐   │
│  │   Chat Interface │◄───LiveView──►│  Preview/Output   │   │
│  │  (User messages) │               │   (Visual state)  │   │
│  └──────────────────┘               └───────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
                    WebSocket (Phoenix)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Phoenix LiveView Layer                   │
│  - RoutineChatLive: Main chat interface                     │
│  - WireframeTestLive, WireframePreviewLive: Domain UI       │
│  - PubSub: Real-time event broadcasting                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      Koalemos.Engine                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Main GenServer: Routine lifecycle & message routing │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  Orchestrator: Step execution & transitions          │   │
│  │  EventHandler: External events & waiting logic       │   │
│  │  Observer: Event recording & PubSub broadcasting     │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  RoutineRegistry: Process lookup (via Registry)      │   │
│  │  EngineManager: Convenience API for routine mgmt     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Routines (Workflows)                      │
│  State machines that define conversation flows              │
│                                                             │
│  Examples:                                                  │
│  - TestChatRoutine: Simple agent loop                       │
│  - WireframeTestRoutine: Agent loop with tool execution     │
│  - PersonaTestRoutine: Agent with persona configuration     │
└─────────────────────────────────────────────────────────────┘
                    ┌──────┴──────┐
                    │             │
                    ▼             ▼
        ┌──────────────────┬─────────────────┐
        │      Steps       │     Lenses      │
        │  Composable      │   Pluggable     │
        │  execution       │   capabilities  │
        │  units           │                 │
        │                  │                 │
        │ Agent:           │ Context-only:   │
        │ - LensRendering  │ - PersonaLens   │
        │ - LLMRequest     │                 │
        │ - ToolExecution  │ Tool-providing: │
        │                  │ - SequentialTh  │
        │ User:            │ - WireframeEd   │
        │ - ChatUserInput  │                 │
        │                  │                 │
        │ Core:            │                 │
        │ - Config         │                 │
        │ - Action         │                 │
        └──────────────────┴─────────────────┘
                    │
                    ▼
        ┌─────────────────────────┐
        │   Infrastructure        │
        │ - LLM Providers         │
        │   (Anthropic, OpenAI,   │
        │    Ollama)              │
        │ - HTML/JS Parsers       │
        │ - Caches (Screenshot,   │
        │   DOM, Console)         │
        │ - Credential Manager    │
        └─────────────────────────┘
```

---

## Core Components

### Engine Layer

The Engine layer is the heart of Koalemos, responsible for executing routines, managing state, handling events, and coordinating between all system components.

#### Koalemos.Engine

**File:** `lib/koalemos/engine.ex` (300 lines)

**Purpose:** Main GenServer that manages a single routine's execution lifecycle.

**Key Responsibilities:**
- Start and initialize routines from routine modules
- Route messages to Orchestrator and EventHandler
- Maintain routine state (context, step, stack, status)
- Register with RoutineRegistry for process lookup
- Auto-execute or manual step-by-step execution

**Process Lifecycle:**
1. **Start** via `Engine.start/1` or `Engine.start_link/1`
2. **Init** - Load routine definition, merge initial_context, call setup/1, record routine_started
3. **Execution** - Delegate to Orchestrator (step execution) and EventHandler (event waiting)
4. **Completion** - Routine reaches :end or :error state

**State Structure:**
```elixir
%{
  routine_id: "routine-123",              # Unique identifier
  module: MyRoutine,                      # Root routine module
  routine_definitions: %{...},            # Loaded routine definitions
  current_routine_module: MyRoutine,      # Current routine (for sub-routines)
  current_step: :init,                    # Current step name
  context: %{...},                        # Routine context (data)
  routine_status: :running,               # :running | :completed | :error
  auto_execute: true,                     # Auto-transition flag
  event_buffer: %EventBuffer{},           # Buffered external events
  waiting_for: nil | %{...},              # Waiting state
  execution_stack: []                     # Sub-routine stack
}
```

**Public API:**
- `start_link/1`, `start/1` - Start routine with supervision or standalone
- `handle_event/4` - Wait for specific event types (synchronous call)
- `send_external_event/3` - Send event to routine (asynchronous cast)

**Message Routing:**
- Info: `:continue_routine`, `{:event, :step_complete, result}`, `{:external_event, :timeout, types}`
- Call: `{:get_event, types, timeout, diff}`
- Cast: `{:external_event, type, data}`

---

#### Engine.Orchestrator

**File:** `lib/koalemos/engine/orchestrator.ex` (495 lines)

**Purpose:** Handles step execution lifecycle and routine transitions.

**Key Responsibilities:**
- Execute steps (setup, async execution, completion handling)
- Apply context diffs from step results
- Evaluate transition conditions
- Manage sub-routine execution (push/pop execution stack)
- Record lifecycle events (step_started, step_completed, transition_taken)

**Step Execution Flow:**
```
execute_current_step/1
  ↓
Step setup (optional :setup/2)
  ↓
Async execution (:execute/2 in Task)
  ↓
Step completion → handle_step_success/2 or handle_step_error/2
  ↓
Apply context diff
  ↓
Check transitions (evaluate conditions)
  ↓
Handle transition (next step, :end, :error, sub-routine)
```

**Sub-Routine Support:**
When a step is itself a routine (has `:routine_definition/0`):
1. Push current state onto execution_stack
2. Load sub-routine definition
3. Set current_routine_module and current_step to sub-routine's start
4. On sub-routine completion (:end), pop stack and continue parent

**Key Functions:**
- `execute_current_step/1` - Main entry point for step execution
- `handle_step_success/2`, `handle_step_error/2` - Process step completion
- `get_current_step_config/1` - Lookup step config from routine definition
- `enter_sub_routine/2`, `exit_sub_routine/1` - Sub-routine management

**LLM Workflow Transitions:**
Special support for cross-routine transitions initiated by LLMs (see WireframeEditor for usage).

---

#### Engine.EventHandler

**File:** `lib/koalemos/engine/event_handler.ex` (310 lines)

**Purpose:** Handles external events and event waiting logic for routines.

**Key Responsibilities:**
- Buffer external events when no step is waiting
- Match events to waiting steps
- Manage timeouts for event waiting
- Call step's `handle_event/3` when event matches

**Event Flow:**

**When External Event Arrives:**
1. Add to EventBuffer
2. If step is waiting for this type:
   - Find and remove from buffer
   - Call step's `handle_event/3`
   - Apply context diff
   - Reply to waiting caller
3. Else: keep buffered

**When Step Waits for Event:**
1. Apply context diff first
2. Try to find event in buffer
3. If found: call `handle_event/3` and reply immediately
4. Else: set up wait state, set timer if timeout specified

**When Timeout Expires:**
1. If still waiting for these types: call `handle_event/3` with `:timeout`
2. Else: ignore (stale timeout)

**Key Functions:**
- `handle_external_event/3` - Process incoming events
- `handle_get_event/5` - Handle routine waiting for events
- `handle_timeout_event/2` - Handle timeout expiry

---

#### Engine.Observer

**File:** `lib/koalemos/engine/observer.ex` (312 lines, 80.5% coverage)

**Purpose:** Event recording and PubSub broadcasting for UI updates.

**Key Responsibilities:**
- Record all routine lifecycle events
- Broadcast events via Phoenix.PubSub
- Track message changes and broadcast new messages only
- Serialize complex data structures for JSON storage
- Write events to file logs (optional)

**Event Types Recorded:**
- `routine_started`, `routine_completed`
- `step_started`, `step_setup`, `step_completed`
- `context_changed`, `transition_taken`
- `error_occurred`, `external_event_received`

**PubSub Topics:**
- `routine:#{routine_id}` - All routine events
- `routine:#{routine_id}:messages` - Message-only events

**Message Tracking:**
Observer intelligently broadcasts only NEW messages by comparing message arrays between events, avoiding redundant broadcasts to UI.

---

#### EngineManager

**File:** `lib/koalemos/engine_manager.ex` (290 lines, 83.3% coverage)

**Purpose:** Convenience API for managing routine processes.

**Note:** Not a GenServer itself – just a collection of helper functions that work with Engine and RoutineRegistry.

**Key Functions:**
- `start_routine/3` - Start a new routine via Engine
- `stop_routine/1` - Terminate a running routine
- `list_routines/0` - Get all active routines
- `get_routine/1` - Get detailed info about a specific routine
- `get_routine_state/1` - Get raw GenServer state (for debugging)

**RoutineInfo Struct:**
```elixir
%RoutineInfo{
  id: "routine-123",
  module: MyRoutine,
  pid: #PID<0.123.0>,
  status: :running,
  current_step: :processing,
  started_at: nil,  # TODO: track start time
  context: %{...},
  execution_stack: [],
  messages: [...],
  lens_state: %{...}
}
```

---

#### RoutineRegistry

**Implementation:** Elixir Registry (built-in)
**Name:** `Koalemos.RoutineRegistry`

**Purpose:** Track running routine processes by routine_id.

**Usage:**
```elixir
# Engine registers itself during start
{:via, Registry, {Koalemos.RoutineRegistry, routine_id}}

# Lookup by routine_id
Registry.lookup(Koalemos.RoutineRegistry, "routine-123")
# => [{pid, _value}] or []

# Send message to routine
GenServer.cast(
  {:via, Registry, {Koalemos.RoutineRegistry, routine_id}},
  {:external_event, :user_input, "hello"}
)
```

---

### Routines Layer

Routines are state machines that define conversation flows. They specify steps, transitions, and conditions.

#### Routine Definition Pattern

**Core Concept:** A routine is a module that implements `routine_definition/0`, returning a map of step configurations.

**Minimal Example:**
```elixir
defmodule MyRoutine do
  @moduledoc """
  A simple routine that loops: user input → agent response.
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{LensRendering, LLMRequest, ResponseParsing}

  def routine_definition do
    %{
      # Wait for user input
      start: %{
        type: ChatUserInput,
        transitions: [{:render_lens, :always}]
      },

      # Get context from lenses
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Make LLM request
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Parse response and add to messages
      parse_response: %{
        type: ResponseParsing,
        transitions: [{:start, :always}]  # Loop back
      }
    }
  end

  # Condition check (required by Engine)
  def check_condition(:always, _context), do: true

  # Optional: Provide default context
  def initial_context do
    %{
      messages: [],
      lenses: ["MyLens"],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5"
    }
  end
end
```

**Step Configuration Structure:**
```elixir
step_name: %{
  type: StepModule,                    # Required: module to execute
  config: %{...},                      # Optional: static config
  transitions: [                       # Required: list of transitions
    {next_step, condition_name},
    {:end, :always}                    # Special: end routine
  ]
}
```

**Transition Evaluation:**
1. After step completes successfully, Orchestrator calls `check_transitions/1`
2. Evaluates each transition's condition via `check_condition/2`
3. Takes first valid transition (order matters)
4. If no transitions valid, goes to `:end`
5. If transition is `:end` and execution_stack is empty, routine completes
6. If transition is `:end` and execution_stack not empty, pops stack (sub-routine completion)

---

#### TestChatRoutine

**File:** `lib/koalemos/routines/test_chat_routine.ex` (75 lines)

**Purpose:** Simplest possible routine – demonstrates basic agent loop without tools.

**Loop:** ChatUserInput → LensRendering → LLMRequest → ResponseParsing → (back to start)

**Use Case:** Testing basic conversation with context-only lenses (like PersonaLens).

---

#### WireframeTestRoutine

**File:** `lib/koalemos/routines/wireframe_test_routine.ex` (274 lines)

**Purpose:** Full agent loop with tool execution for WireframeEditor lens.

**Loop:** ChatUserInput → ToolSchema → LensRendering → LLMRequest → ResponseParsing → (if tools) ToolLookup → ToolExecution → (back to ToolSchema) → (if no tools) back to start

**Features:**
- Load sample wireframes (simple, medium, complex)
- Full WireframeEditor lens integration
- Tool execution infrastructure (9 tools)
- Designed vs running state tracking
- Console output monitoring

**Initial Context:**
- `wireframe_sample`: Load sample HTML ("simple", "medium", "complex")
- `wireframe_html`: Direct HTML content
- Higher token limit (64,000) for wireframe context

**Setup Function:**
Loads sample HTML if specified, parses with `ParsingIntegration.parse_wireframe/2`, initializes lens_state with designed DOM tree, styles, scripts, functions, variables, handlers.

---

#### PersonaTestRoutine

**File:** `lib/koalemos/routines/persona_test_routine.ex` (110 lines)

**Purpose:** Interactive testing of PersonaLens with configurable personas.

**Features:**
- Configure persona dimensions (tone, expertise, style)
- Test single or multiple persona combinations
- Full test coverage (21 tests)

---

#### Routine Patterns

**Optional Callbacks:**

1. **`initial_context/0`** - Provide default context
   Engine auto-calls and merges with user-provided context.

2. **`setup/1`** - Initialize routine after context merge
   Called once during init. Returns `{:ok, diff}` to modify context before first step.

3. **`start/0`** - Specify starting step
   Defaults to `:start` if not provided.

**Condition Functions:**

`check_condition/2` is required for all condition names used in transitions:

```elixir
def check_condition(:always, _context), do: true

def check_condition(:when_has_tool_calls, context) do
  tool_calls = Map.get(context, :tool_calls, [])
  length(tool_calls) > 0
end

def check_condition(:when_error, context) do
  Map.has_key?(context, :error)
end
```

**Sub-Routine Pattern:**

Any step can be a routine itself. If `step.type` implements `routine_definition/0`, Engine enters it as a sub-routine:

```elixir
%{
  complex_task: %{
    type: ComplexSubRoutine,  # This is also a routine!
    transitions: [{:next_step, :always}]
  }
}
```

---

### Steps Layer

Steps are composable execution units. Each step performs a specific task and returns a context diff.

#### Step Categories

**Agent Steps** (`lib/koalemos/steps/agent/`):
Autonomous operations that don't require user input.

- `LensRendering` - Query lenses for context blocks
- `LLMRequest` - Make API calls to LLM providers
- `ResponseParsing` - Parse LLM responses, extract tool calls
- `ToolSchema` - Build tool schemas from lens tools
- `ToolLookup` - Resolve tool calls to executable format
- `ToolExecution` - Execute tools one at a time

**User Steps** (`lib/koalemos/steps/user/`):
Operations that wait for user interaction.

- `ChatUserInput` - Wait for user messages, handle screenshots

**Core Steps** (`lib/koalemos/steps/system/`):
System-level operations.

- `Config` - Configure routine parameters
- `Action` - System actions

---

#### Step Interface Pattern

**Required Function:**

```elixir
@spec execute(config_sources :: map(), state :: map()) ::
  {:ok, ContextManager.diff()} | {:error, String.t()}
```

**Optional Functions:**

```elixir
@spec setup(config_sources :: map(), state :: map()) ::
  {:ok, ContextManager.diff()} | {:error, String.t()}

@spec handle_event(event_type :: atom(), data :: term(), state :: map()) ::
  {:ok, ContextManager.diff()} | {:error, String.t()}
```

**Config Sources Pattern (Hybrid Config):**

Steps receive both static config and runtime config:

```elixir
config_sources = %{
  static: step_config[:config] || %{},        # From routine definition
  runtime: context[:config][step_name] || %{} # From context (dynamic)
}
```

Use `ConfigMerge.get_key/3` to merge:

```elixir
model = ConfigMerge.get_key(config_sources, :model, "default-model")
# runtime overrides static, with fallback default
```

---

#### ChatUserInput

**File:** `lib/koalemos/steps/user/chat_user_input.ex` (203 lines)

**Purpose:** Wait for user input events and format them into messages.

**Execution:**
1. Calls `Engine.handle_event([:user_input], nil, [], routine_id)` – blocks until event
2. Engine routes event to `handle_event/3` callback
3. `handle_event/3` formats input and returns diff

**Supported Input Formats:**
- Direct string: `"Hello world"`
- Structured: `%{user_input: "Hello world"}`
- Pre-formatted: `%{messages: [%{role: "user", content: [...]}]}`
- With images: `%{text: "Hello", images: [...]}`
- Images only: `%{images: [...]}`

**Screenshot Request:**
If input includes `include_screenshot: true`, sets lens_state flag so next `LensRendering` will capture screenshot.

**Output:**
Appends formatted user message to `context.messages` using `MessageBuilder.build_user_message/2`.

---

#### LensRendering

**File:** `lib/koalemos/steps/agent/lens_rendering.ex` (127 lines)

**Purpose:** Query active lenses for their current context blocks.

**Hybrid Config Pattern:**
Merges base lenses from `context[:lenses]` with config lenses using `ConfigMerge.merge_lenses/2`.

**Execution:**
1. Collect context blocks from all lens modules via `provide_context/2`
2. Separate into text blocks and image blocks
3. Store in context as:
   - `lens_text_contexts` - For LLM system prompt
   - `lens_image_contexts` - Prepended as user messages (not saved to history)

**Lens Context Format:**
- Text: `%{type: "text", text: "..."}`
- Image: `%{type: "image", source: %{type: "base64", media_type: "image/png", data: "..."}}`

---

#### LLMRequest

**File:** `lib/koalemos/steps/agent/llm_request.ex` (150 lines)

**Purpose:** Router step that delegates to appropriate LLM provider.

**Execution:**
1. Resolve provider name from `context[:llm_provider]` (default: "anthropic")
2. Get credentials via `get_credentials/2`
3. Extract messages, tool_descriptions, lens_contexts from context
4. Build config map (model, max_tokens, temperature, base_url)
5. Delegate to provider's `call/6` function
6. Provider returns `{:ok, [{:add_or_update, %{llm_response: response}}]}`

**Provider Resolution:**
- `"anthropic"` → `Koalemos.LLMProviders.Anthropic`
- `"openai"` → `Koalemos.LLMProviders.OpenAI`
- `"ollama"` → `Koalemos.LLMProviders.Ollama`

---

#### ResponseParsing

**File:** `lib/koalemos/steps/agent/response_parsing.ex` (94 lines, 100% coverage)

**Purpose:** Parse LLM response and extract assistant message and tool calls.

**Execution:**
1. Extract `llm_response` from context
2. Parse response format (Anthropic native format)
3. Extract assistant message content
4. Extract tool calls (if any)
5. Build assistant message using `MessageBuilder`
6. Return diff:
   - Append assistant message to messages
   - Add tool_calls to context (if any)
   - Remove llm_response from context

**Tool Call Format:**
```elixir
%{
  id: "toolu_123",
  name: "sequential_thinking",
  input: %{"thought" => "...", "thought_number" => 1}
}
```

---

#### ToolLookup

**File:** `lib/koalemos/steps/agent/tool_lookup.ex` (122 lines, 100% coverage)

**Purpose:** Resolve tool calls from names to executable module/function references.

**Execution:**
1. Get tool_calls from context
2. Get tool_registry from context (populated by ToolSchema)
3. For each tool call, lookup in registry:
   ```elixir
   tool_registry[tool_name] → {module, function_atom}
   ```
4. Build executable format:
   ```elixir
   %{
     id: tool_call.id,
     module: module,
     function: function_atom,
     input: tool_call.input
   }
   ```
5. Store as `to_execute` in context

---

#### ToolExecution

**File:** `lib/koalemos/steps/agent/tool_execution.ex` (131 lines, 100% coverage)

**Purpose:** Execute one tool from the queue and manage execution state.

**Execution (Consume Pattern):**
1. Pop first tool from `to_execute` queue
2. Execute via `apply(tool.module, tool.function, [tool.input, context])`
3. Normalize tool result (handles multiple formats)
4. Build tool result message
5. Update context:
   - Append tool result message
   - Update `to_execute` (remove processed tool)
   - Apply lens_updates if provided

**Tool Result Formats:**
- Simple string: `"result text"`
- With lens updates: `{"result text", [lens_key: value]}`
- With metadata: `{"result text", [lens_key: value], %{metadata}}`
- Content blocks: `{[{:text, "result"}, {:image, base64, type}], lens_updates}`

**Lens State Updates:**
If tool returns lens_updates, merges them into `context[:lens_state]`:

```elixir
updated_lens_state = Enum.reduce(lens_updates, existing_lens_state, fn {key, value}, acc ->
  Map.put(acc, key, value)
end)
```

---

### Lenses Layer

Lenses are pluggable capabilities that provide context and/or tools to the agent.

#### Lens Patterns

**Two Types of Lenses:**

1. **Context-Only Lenses** - Provide information to system prompt, no tools
   - Example: PersonaLens
   - Implement: `provide_context/2`

2. **Tool-Providing Lenses** - Provide both context and executable tools
   - Example: SequentialThinking, WireframeEditor
   - Implement: `provide_context/2`, `tools/0`, `execute/3`, `info/1`

---

#### Lens Interface

**Required for Context-Only:**

```elixir
@spec provide_context(state :: map(), config :: map()) :: [context_block()]

# Context block types:
# Text: %{type: "text", text: "..."}
# Image: %{type: "image", source: %{type: "base64", media_type: "...", data: "..."}}
```

**Additional for Tool-Providing:**

```elixir
@spec tools() :: [{module(), tool_atom()}]
@spec info(tool_atom()) :: tool_schema()
@spec execute(tool_atom(), args :: map(), context :: map()) ::
  tool_result()

# Tool result formats:
# - string: "Result message"
# - {string, lens_updates}: {"Result", [key: value]}
# - {string, lens_updates, metadata}: {"Result", [key: value], %{}}
# - {content_blocks, lens_updates}: {[{:text, "..."}, {:image, base64, type}], []}
```

**Tool Schema Format (Anthropic):**

```elixir
%{
  name: "tool_name",
  description: "What the tool does...",
  input_schema: %{
    type: "object",
    properties: %{
      param1: %{type: "string", description: "..."},
      param2: %{type: "integer", minimum: 1}
    },
    required: ["param1"]
  }
}
```

---

#### PersonaLens

**File:** `lib/koalemos/lenses/persona_lens.ex` (317 lines, 100% coverage)

**Type:** Context-only lens

**Purpose:** Provides dimensional persona configuration for AI communication style.

**Dimensions:**
- **tone** (single): professional, casual, friendly, empathetic
- **expertise** (list): technical, creative, business, analytical, ux
- **style** (single): concise, detailed, balanced, storytelling

**Configuration:**
```elixir
lenses: [
  ["Koalemos.Lenses.PersonaLens", %{
    tone: :professional,
    expertise: [:technical, :ux],
    style: :balanced
  }]
]
```

**Implementation:**
Builds text context blocks for each configured dimension. Expertise supports multiple values (multi-perspective).

---

#### SequentialThinking

**File:** `lib/koalemos/lenses/sequential_thinking.ex` (314 lines, 100% coverage)

**Type:** Tool-providing lens

**Purpose:** Step-by-step reasoning with visible thought process.

**Attribution:** Ported from Anthropic's Sequential Thinking MCP server (MIT license) and adapted to Koalemos lens architecture.

**Tool:** `sequential_thinking` - Manages structured thought processes

**Parameters:**
- `thought` (required): Current thinking step
- `next_thought_needed` (required): Whether more thinking needed
- `thought_number` (required): Current thought number (1-indexed)
- `total_thoughts` (required): Estimated total (can adjust)
- `is_revision` (optional): Revising previous thinking
- `revises_thought` (optional): Which thought is reconsidered
- `branch_from_thought`, `branch_id` (optional): For branching

**Context Strategy:**
Shows only current/active reasoning chain. When `thought_number == 1`, previous chain is cleared (fresh start).

**State Management:**
Tracks `thought_history` and `branches` in `context[:lens_state]`.

**Tool Result:**
Brief JSON with progress indication. Thought text stored in lens_state, shown in context – not echoed in tool result to reduce redundancy.

---

#### WireframeEditor

**Files:** Modular architecture (~1,590 lines total across multiple files)
- `lib/koalemos/lenses/wireframe_editor/core.ex` - Main interface, coordination
- `lib/koalemos/lenses/wireframe_editor/dom_handler.ex` - HTML/DOM manipulation

**Type:** Tool-providing lens

**Purpose:** Interactive HTML wireframe editing with full feedback loop.

**9 Tools Provided:**

**Structure Tools:**
1. `modify_classes` - Add/remove CSS classes
2. `modify_elements` - Add/replace/remove elements
3. `manage_attributes` - Modify element attributes

**Behavior Tools:**
4. `manage_handlers` - Add/remove event handlers
5. `manage_functions` - Define JavaScript functions
6. `manage_variables` - Define JavaScript variables
7. `manage_css` - Define CSS rules
8. `manage_init_scripts` - Add initialization scripts

**Testing Tool:**
9. `trigger_interaction` - Simulate user interactions (click, fill, submit, execute JS)

**Two-State Model:**
- **Designed**: Source being edited (DOM tree, styles, scripts, functions, variables, handlers, init scripts)
- **Running**: Live preview state (captured from browser)

**Feedback Loop (M4 Sprint 7):**
- Before each LLM request, captures current state from preview
- Includes console output, DOM differences, screenshots
- Agent sees results of previous interactions

**State Snapshot:**
Captures complete state via PubSub coordination:
1. `provide_context/2` requests snapshot from preview
2. Preview captures DOM (via `captureCompleteState` in JS hook)
3. Returns designed vs running comparison with diff status

**Console Integration:**
- Infrastructure logs use `INFRASTRUCTURE_CONSOLE` (isolated)
- Wireframe logs captured and shown to agent
- Error/warning highlighting in context

**Screenshot Integration:**
- Screenshots captured automatically in state snapshots
- Reuses Sprint 2's html2canvas infrastructure
- Blocking capture for state consistency

---

### Infrastructure Layer

#### LLM Providers

**Plugin Architecture:** Providers implement `Koalemos.LLMProvider` behavior.

**Available Providers:**
- **Anthropic** (`llm_providers/anthropic.ex`) - Native format, API key + OAuth, progressive retry
- **OpenAI** (`llm_providers/openai.ex`) - Message format conversion, system prompt handling
- **Ollama** (`llm_providers/ollama.ex`) - Local server, OpenAI-compatible format

**Provider Behavior:**
```elixir
@callback call(
  messages :: list(),
  credentials :: map(),
  tool_descriptions :: list(),
  lens_contexts :: map(),
  config :: map(),
  routine_id :: String.t()
) :: {:ok, keyword()} | {:error, String.t()}
```

**Common Utilities:** `Koalemos.LLMProvider.Utils`
- `strip_metadata/1` - Remove internal metadata before API calls
- `filter_empty_assistant_messages/1` - Remove empty assistant messages

**See:** `docs/LLM_PROVIDER_GUIDE.md` for creating new providers.

---

#### Parsers

**HTMLParser** (`lib/koalemos/integrations/parsing_integration.ex`):
- Parses HTML into DOM tree structure
- Extracts inline styles and scripts
- Uses Floki for HTML parsing
- Generates auto-IDs for elements without IDs

**JavaScriptParser** (`lib/koalemos/integrations/javascript_integration.ex`):
- Node.js-based parser using esprima
- Extracts functions, variables, event handlers
- Unwraps DOMContentLoaded blocks
- Validates JavaScript syntax

**CSSParser** (Integrated into HTMLParser):
- Extracts CSS rules from `<style>` tags
- Parses selector and declarations

---

#### Caches

All caches are ETS-based GenServers with TTL and cleanup.

**ScreenshotCache** (`lib/koalemos/caches/screenshot_cache.ex`):
- Stores Base64 PNG screenshots by routine_id
- 5-minute TTL per screenshot
- Used by screenshot capture system

**WireframeStateCache** (`lib/koalemos/caches/wireframe_state_cache.ex`):
- Stores lens_state by routine_id
- Solves timing issue (PubSub before iframe mount)
- 1-hour TTL, auto-cleanup

**ConsoleCache** (`lib/koalemos/caches/console_cache.ex`):
- Stores JavaScript console output
- Rate limiting: 15 messages/second, max 500
- Messages persist entire session (no TTL)
- Duplicate detection

---

#### Credentials

**DemoCredentialStore** (`lib/koalemos/demo_credential_store.ex`):
- File-based credential storage (`.koalemos/.credentials.json`)
- Supports multiple providers (Anthropic, OpenAI, Ollama)
- Selected provider configuration
- GenServer with file watching (future)

**SimpleCredentialManager** (`lib/koalemos/simple_credential_manager.ex`):
- OAuth token management for Anthropic
- Token refresh, storage, retrieval
- Used by API key providers as well

**Format:**
```json
{
  "providers": {
    "anthropic": {"api_key": "sk-...", "model": "claude-haiku-4-5"},
    "openai": {"api_key": "sk-...", "model": "gpt-4"},
    "ollama": {"base_url": "http://localhost:11434", "model": "qwen2.5"}
  },
  "selected_provider": "anthropic"
}
```

---

## Context Management

### ContextManager

**File:** `lib/koalemos/engine/context_manager.ex` (193 lines, 100% coverage)

**Purpose:** Apply diffs to context maps with proper conflict handling.

**Diff Operations:**

```elixir
# Add keys (error if exists)
{:add, %{new_key: "value"}}

# Update keys (error if not exists)
{:update, %{existing_key: "new_value"}}

# Add or update (no error)
{:add_or_update, %{key: "value"}}

# Append to lists
{:append_to, %{messages: [new_message]}}

# Remove keys
{:remove, [:key_to_remove]}
```

**Usage:**
```elixir
diff = [
  add_or_update: %{step: :processing},
  append_to: %{messages: [message]},
  remove: [:temporary_data]
]

{:ok, new_context} = ContextManager.apply_diff(context, diff)
```

**Validation:**
All operations validated before applying. Atomic – either all succeed or all fail.

---

## Message System

### Message Format (Anthropic-Compatible)

All messages follow Anthropic's format:

```elixir
%{
  role: "user" | "assistant",
  content: [
    %{type: "text", text: "..."},
    %{type: "image", source: %{type: "base64", media_type: "image/png", data: "..."}},
    %{type: "tool_use", id: "toolu_123", name: "tool_name", input: %{...}},
    %{type: "tool_result", tool_use_id: "toolu_123", content: "..."}
  ],
  metadata: %{
    id: "msg_123",
    source: :user | :assistant | :tool_result,
    routine_id: "routine-123",
    timestamp: DateTime.utc_now()
  }
}
```

### MessageBuilder

**File:** `lib/koalemos/utils/message_builder.ex` (230 lines, 92.1% coverage)

**Purpose:** Build and validate messages in consistent format.

**Key Functions:**
- `build_user_message/2` - Simple text user message
- `build_user_message_with_content/2` - Multi-part content (text + images)
- `build_assistant_message/2` - Assistant text response
- `build_assistant_message_with_tool_calls/2` - Assistant with tool calls
- `build_tool_result_message/3` - Tool execution result
- `validate_message/1` - Validate message structure

**Content Block Types:**
- `{:text, string}` - Plain text
- `{:image, base64_data, media_type}` - Image (PNG, JPEG, etc.)
- `{:tool_use, id, name, input}` - Tool call
- `{:tool_result, id, content}` - Tool result

---

## Event System

### Observer Pattern

**PubSub Topics:**
- `routine:#{routine_id}` - All events for this routine
- `routine:#{routine_id}:messages` - Message-only events

**Event Structure:**
```elixir
%{
  routine_id: "routine-123",
  event_type: "step_completed",
  timestamp: DateTime.utc_now(),
  routine_module: MyRoutine,
  current_step: :processing,
  metadata: %{...},
  context_diff: [...]  # If applicable
}
```

**Subscription:**
```elixir
Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")

# In LiveView
def handle_info({:event, event}, socket) do
  # Handle event
  {:noreply, socket}
end
```

---

## Configuration System

### Hybrid Config Pattern

Steps receive config from two sources:

1. **Static Config** - Defined in routine definition, unchanging
2. **Runtime Config** - Stored in context, can change during execution

**Example:**

```elixir
# Routine definition (static)
%{
  my_step: %{
    type: MyStep,
    config: %{model: "claude-haiku-4-5"},  # Static
    transitions: [...]
  }
}

# Runtime (in context)
context = %{
  config: %{
    my_step: %{model: "claude-sonnet-4-5"}  # Overrides static
  }
}

# In step
def execute(config_sources, state) do
  model = ConfigMerge.get_key(config_sources, :model, "default")
  # Uses runtime if present, else static, else default
end
```

**ConfigMerge Module:**
- `get_key/3` - Get merged config value
- `merge_lenses/2` - Merge lens configurations

---

## Testing

### Test Infrastructure

**Coverage:** 92.4% overall (782 tests)

**Test Categories:**
- Unit tests for all engine components
- Integration tests for agent loops
- Real API tests (marked `@moduletag :real_api`)
- Manual test pages (`/test/screenshot`, `/test/wireframe`, `/test/lens-combinator`)

**Test Routines:**
- `TestChatRoutine` - Basic agent loop (no tools)
- `WireframeTestRoutine` - Full agent loop with tools
- `PersonaTestRoutine` - Persona testing
- `ThinkingTestRoutine` - Sequential thinking testing

**Manual Test Guide:**
`docs/testing/MANUAL_TEST_GUIDE.md` - 5 scenarios for WireframeEditor validation.

---

## Key Design Decisions

### Why Phoenix LiveView?
- Real-time updates without custom WebSocket code
- Server-side rendering with client-side feel
- Built-in PubSub for event broadcasting
- Elixir/OTP for robust process management

### Why Custom Engine?
- Need for complex, stateful conversation flows
- Dynamic routing between phases
- Tool execution with state management
- Reusable patterns (sub-routines)
- Framework approach (not just an app)

### Why Lenses?
- Separation of concerns (context vs. tools vs. execution)
- Composable perspectives on same data
- Easy to add new capabilities without changing engine
- Clear API for LLM tool use
- Plugin architecture for extensibility

### Why GenServer-Based Engine?
- Natural fit for stateful, long-running processes
- OTP supervision for fault tolerance
- Process isolation (one routine = one process)
- Easy debugging via `:sys.get_state/1`

### Why Context Diff Pattern?
- Explicit about what changes
- Easier to debug (see exactly what each step does)
- Supports atomic updates (all or nothing)
- Enables event recording (record diffs, not full context)

---

## M4 Features (Current State)

**Milestone 4:** Advanced Lens System (Sprint 7 of 8 complete)

**Completed Lenses:**
1. ✅ **PersonaLens** - Context-only dimensional persona configuration
2. ✅ **SequentialThinking** - Step-by-step reasoning with thought chains
3. ✅ **WireframeEditor** - Interactive wireframe editing with full feedback loop

**Key M4 Achievements:**
- Test infrastructure (sample wireframes, interactive test pages)
- Modular WireframeEditor architecture (core + handlers)
- Tool execution infrastructure (9 tools functional)
- Feedback loop (console, screenshots, state capture)
- Real-time preview with LiveView-in-iframe pattern
- JavaScript rendering and execution
- State snapshot coordination via PubSub

**Sprint 8 Remaining:**
- Comprehensive developer documentation (this file + guides)
- Production roadmap
- Final integration polish

---

## Future Architecture

**Potential improvements (not committed):**

- Persistent storage layer (PostgreSQL + Ecto)
- Multi-routine support (parallel execution)
- Routine builder/editor (visual workflow design)
- Plugin system for custom lenses (marketplace)
- Distributed execution (for scaling)
- Event sourcing for routine replay (time-travel debugging)
- Enhanced observability (telemetry, tracing)
- Performance optimizations (caching, lazy loading)

---

## Developer Resources

**Guides:**
- `docs/guides/LENS_DEVELOPMENT.md` - How to create lenses
- `docs/guides/ROUTINE_DEVELOPMENT.md` - How to create routines
- `docs/LLM_PROVIDER_GUIDE.md` - How to add LLM providers

**Example Code:**
- `lib/koalemos/lenses/persona_lens.ex` - Context-only lens
- `lib/koalemos/lenses/sequential_thinking.ex` - Tool-providing lens
- `lib/koalemos/routines/test_chat_routine.ex` - Simple routine
- `lib/koalemos/routines/wireframe_test_routine.ex` - Complex routine with tools

**Testing:**
- `test/koalemos/engine/` - Engine unit tests
- `test/koalemos/integration/` - Integration tests
- `docs/testing/MANUAL_TEST_GUIDE.md` - Manual testing scenarios

---

## Notes

**Last Major Update:** November 11, 2025 (M4 Sprint 8 - Phase 2 Documentation)

**Status:** This document is now comprehensive and reflects the complete M4 architecture. Future updates should maintain this level of detail.

**For Developers:** This architecture document, combined with the lens and routine development guides, provides everything needed to extend Koalemos with new capabilities.
