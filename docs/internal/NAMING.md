# Koalemos - Naming Conventions

**Last Updated:** October 27, 2024

---

## Philosophy

We deliberately moved away from corporate/technical jargon ("workflows", "nodes") toward cognitive/mental process terminology that reflects what the system actually does: executing thinking routines with discrete steps through different lenses.

---

## Core Concepts

### Routines
**What it is:** Process definitions (formerly "workflows")
**Why:** Mental routines, thinking patterns, procedures
**Location:** `lib/koalemos/routines/`
**Module:** `Koalemos.Routines.*`
**Example:** `Koalemos.Routines.WireframeDesign`

**Rationale:** "Routine" captures the procedural, repeatable nature without the corporate baggage of "workflow". It's how you routinely approach a problem.

### Subroutines
**What it is:** Reusable patterns (formerly "chunks")
**Why:** Subroutines are called within routines
**Location:** `lib/koalemos/subroutines/`
**Module:** `Koalemos.Subroutines.*`
**Example:** `Koalemos.Subroutines.TemplatedSemanticAgent`

**Rationale:** Classic programming concept - a reusable piece of logic that routines call. Clear hierarchy.

### Steps
**What it is:** Building blocks (formerly "nodes")
**Why:** Individual steps in a routine
**Location:** `lib/koalemos/steps/`
**Module:** `Koalemos.Steps.*`
**Sub-modules:**
- `Koalemos.Steps.Agent.*` - LLM interactions
- `Koalemos.Steps.User.*` - User interactions
- `Koalemos.Steps.Core.*` - System operations

**Example:** `Koalemos.Steps.Agent.LLMRequest`

**Rationale:** "Step" is clear and approachable. You take steps in a routine, not "execute nodes".

### Lenses
**What it is:** Perspectives/tools (unchanged)
**Why:** Looking at problems through different lenses
**Location:** `lib/koalemos/lenses/`
**Module:** `Koalemos.Lenses.*`
**Example:** `Koalemos.Lenses.WireframeEditor`

**Rationale:** This metaphor was already perfect. Lenses let you see/manipulate the world differently.

### Engine
**What it is:** Core execution system (formerly "workflow engine")
**Why:** The engine that runs everything
**Location:** `lib/koalemos/engine/`
**Module:** `Koalemos.Engine`
**Sub-modules:**
- `Koalemos.Engine.Orchestrator` - State management
- `Koalemos.Engine.Observer` - Event broadcasting
- `Koalemos.Engine.Registry` - Process registry

**Rationale:** Clean, direct, no controversy. Engines execute things.

---

## File Naming

### Routines
- File: `wireframe_design.ex`
- Module: `Koalemos.Routines.WireframeDesign`
- Definition function: `def routine_definition do`

### Subroutines
- File: `templated_semantic_agent.ex`
- Module: `Koalemos.Subroutines.TemplatedSemanticAgent`

### Steps
- File: `llm_request.ex` (in `steps/agent/`)
- Module: `Koalemos.Steps.Agent.LLMRequest`
- Execute function: `def execute(config, state)`

### Lenses
- File: `wireframe_editor.ex`
- Module: `Koalemos.Lenses.WireframeEditor`
- Tool functions: `def tools(context)`

---

## Migration Map

From Flo → To Koalemos:

```
Flo.WorkflowEngine              → Koalemos.Engine
Flo.WorkflowOrchestrator        → Koalemos.Engine.Orchestrator
Flo.WorkflowObserver            → Koalemos.Engine.Observer
Flo.WorkflowRegistryAdapter     → Koalemos.Engine.Registry

Flo.Workflows.*                 → Koalemos.Routines.*
Flo.Chunks.*                    → Koalemos.Subroutines.*
Flo.Nodes.*                     → Koalemos.Steps.*
Flo.Lenses.*                    → Koalemos.Lenses.* (unchanged)
```

### Specific Examples

```
# Routines
Flo.Workflows.WireframeEditorWorkflow     → Koalemos.Routines.WireframeDesign
Flo.Workflows.Demo.WireframeDesignWorkflow → Koalemos.Routines.WireframeDesign

# Subroutines
Flo.Chunks.TemplatedSemanticAgent         → Koalemos.Subroutines.TemplatedSemanticAgent
Flo.Chunks.SemanticAgentLoop              → Koalemos.Subroutines.SemanticAgentLoop

# Steps
Flo.Nodes.Agent.LLMRequestNode            → Koalemos.Steps.Agent.LLMRequest
Flo.Nodes.User.ChatUserInputNode          → Koalemos.Steps.User.ChatUserInput
Flo.Nodes.Core.ConfigNode                 → Koalemos.Steps.Core.Config
Flo.Nodes.Wireframe.CombinedInputNode     → Koalemos.Steps.User.CombinedInput

# Lenses (mostly unchanged, but namespaced)
Flo.Lenses.WireframeEditor                → Koalemos.Lenses.WireframeEditor
Flo.Lenses.Scratchpad                     → Koalemos.Lenses.Scratchpad
```

---

## Function Naming

### In Routines
```elixir
def routine_definition do
  %{
    start: %{
      type: Koalemos.Steps.Core.Config,
      transitions: [...]
    }
  }
end

def start_step, do: :start

def check_condition(:always, _context), do: true
```

### In Steps
```elixir
def execute(config, state) do
  # Step execution logic
  {:ok, context_diff}
end
```

### In Lenses
```elixir
def tools(context) do
  # Return available tools
end

def handle_tool_result(tool_name, result, context) do
  # Process tool execution
end
```

---

## Why This Matters

Clear naming:
- Makes the codebase approachable
- Reflects actual purpose (mental processes, not pipelines)
- Avoids corporate buzzwords
- Tells a story about what the system does

When someone reads `Koalemos.Routines.WireframeDesign`, they understand it's a routine/process for wireframe design. When they see `Koalemos.Steps.Agent.LLMRequest`, they know it's a step that makes an LLM request.

---

## Future Considerations

- Keep naming consistent as we add features
- Document any new conventions here
- Avoid the urge to slip back into "workflow" terminology
- When in doubt, use the cognitive/mental process framing
