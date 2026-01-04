# Semantic Routing Guide

**Last Updated:** November 12, 2025
**Milestone:** M5 Sprint 1

---

## What is Semantic Routing?

Semantic routing allows agents to intelligently analyze user requests and choose execution paths based on natural language understanding, rather than following hardcoded conditions or fixed phase sequences.

**Traditional Approach (Fixed Phases):**
```
User Request → Discovery → Structure → Behavior → Polish
```

**Semantic Routing Approach:**
```
User Request → Agent Analysis → Intelligent Path Choice
  ├─ Answer directly (read-only)
  ├─ Targeted change (specific modification)
  └─ Build from scratch (comprehensive creation)
```

### Key Benefits

1. **More Natural:** Users don't think in phases, they think in goals
2. **Context-Aware:** Agent chooses path based on understanding the request
3. **Flexible:** Can add/remove/modify paths without changing core logic
4. **Generalizable:** Pattern works for any routine type
5. **Composable:** Routes can contain sub-routes for nested decisions

---

## Core Components

### 1. TemplatedSemanticAgent

A reusable agent loop step that combines EEx templating with configurable lenses.

**Purpose:** Eliminate agent loop duplication while providing rich context access

**Key Features:**
- Renders EEx template with full `@context` access
- Configures lenses per step
- Executes complete agent loop (tool_schema → render_lens → llm → parse → tool_execution)
- Acts as sub-routine (pushes onto execution stack)

**Example Usage:**
```elixir
routing: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: """
    Analyze the user's request and route to the appropriate action.

    User request: <%= List.last(@context[:messages])[:content] %>
    Current wireframe: <%= if @context[:wireframe_exists], do: "exists", else: "empty" %>

    Available paths:
    - answer_directly: For questions without making changes
    - targeted_change: For specific modifications
    - build_from_scratch: For comprehensive creation

    Choose the best path for this request.
    """,
    lenses: [
      ["WireframeEditor", %{readonly: true}],  # Override to readonly
      "SequentialThinking",                     # Keep from base
      "SemanticTransition"                      # Add new lens
    ]
  },
  transitions: [
    {:answer_directly, "Answer questions without making changes"},
    {:targeted_change, "Make a specific focused modification"},
    {:build_from_scratch, "Create new wireframe from scratch"}
  ]
}
```

### 2. SemanticTransition Lens

Enables agents to choose transitions using natural language descriptions.

**Purpose:** Convert semantic transition choices into workflow_transition signals

**How It Works:**
1. Reads parent routine's `transitions` from execution stack
2. Filters for semantic transitions (description is string)
3. Builds dynamic `choose_transition` tool with enum
4. Agent calls tool with choice and reason
5. Returns `{:workflow_transition, {target_step, reason}}` in lens_state
6. Engine pops execution stack and applies transition at parent level

**Transition Format:**
```elixir
transitions: [
  # Semantic transitions (description is string)
  {:answer_directly, "Answer questions without making changes"},
  {:targeted_change, "Make a specific focused modification"},

  # Regular transitions (condition is atom)
  {:next_step, :always},
  {:error_handler, :when_error}
]
```

**Tool Schema (Generated Dynamically):**
```json
{
  "name": "choose_transition",
  "description": "Choose the next workflow transition based on analysis",
  "input_schema": {
    "type": "object",
    "properties": {
      "transition": {
        "type": "string",
        "enum": ["answer_directly", "targeted_change", "build_from_scratch"],
        "description": "The transition to take"
      },
      "reason": {
        "type": "string",
        "description": "Explanation of why this transition is best"
      }
    },
    "required": ["transition", "reason"]
  }
}
```

### 3. Lens Scoping System

Manages lens configuration across routine branches with proper inheritance and isolation.

**Purpose:** Prevent lens modifications from leaking across branches while allowing proper inheritance

**Three Configuration Levels:**
1. **Base Lenses:** Inherited from parent context (routine-level)
2. **Config Lenses:** Specified in step config (step-level)
3. **Merged Lenses:** Result of merge-with-override

**Merge-with-Override Semantics:**
```elixir
# Base lenses from context
base = ["WireframeEditor", "SequentialThinking"]

# Step configures
config = [
  ["WireframeEditor", %{readonly: true}],  # Same module → override
  "SemanticTransition"                      # New module → add
]

# Result
merged = [
  ["WireframeEditor", %{readonly: true}],  # Overridden config
  "SequentialThinking",                     # Kept from base
  "SemanticTransition"                      # Added from config
]
```

**Scope Isolation:**
```elixir
# Workflow starts with base lenses
context: %{lenses: ["WireframeEditor", "SequentialThinking"]}

# Routing step (first in routine)
# Saves: _routine_base_lenses = ["WireframeEditor", "SequentialThinking"]
# Merges config: [WireframeEditor(readonly), SequentialThinking, SemanticTransition]

# Agent chooses: targeted_change

# targeted_change step (has config)
# Merges with saved base (not current!)
# Result: [WireframeEditor(full), SequentialThinking]
# (No SemanticTransition - was only in routing)

# Agent chooses: build_from_scratch

# build_from_scratch step (no config)
# Restores saved base
# Result: [WireframeEditor, SequentialThinking]
# (Back to original - clean slate)
```

---

## Common Patterns

### Pattern 1: Simple Semantic Routing

**Use Case:** Choose between 2-4 distinct actions based on user intent

```elixir
defmodule MyRoutine do
  def routine_definition do
    %{
      start: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Analyze: <%= @context[:user_request] %>

          Choose the best action.
          """,
          lenses: ["SemanticTransition"]
        },
        transitions: [
          {:create, "Create new content"},
          {:modify, "Modify existing content"},
          {:analyze, "Analyze without changes"}
        ]
      },

      create: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: "Create content based on request.",
          lenses: ["ContentEditor"]
        },
        transitions: [{:end, :always}]
      },

      modify: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: "Modify existing content.",
          lenses: ["ContentEditor"]
        },
        transitions: [{:end, :always}]
      },

      analyze: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: "Analyze and respond.",
          lenses: [["ContentEditor", %{readonly: true}]]
        },
        transitions: [{:end, :always}]
      }
    }
  end
end
```

### Pattern 2: Readonly During Routing

**Use Case:** Agent should see context but not have modification tools during routing

```elixir
routing: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: "Analyze and route...",
    lenses: [
      ["WireframeEditor", %{readonly: true}],  # Can see, can't modify
      "SequentialThinking",
      "SemanticTransition"
    ]
  },
  transitions: [...]
},

# Action step gets full tools
action: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: "Make changes...",
    lenses: [
      "WireframeEditor",  # Full tools (merged from base, no config override)
      "SequentialThinking"
    ]
  },
  transitions: [{:end, :always}]
}
```

### Pattern 3: Nested Semantic Routing

**Use Case:** Sub-routines with their own routing decisions

```elixir
main_routing: %{
  type: TemplatedSemanticAgent,
  config: %{...},
  transitions: [
    {:wireframe_workflow, "Work on wireframe"},
    {:content_workflow, "Work on content"}
  ]
},

wireframe_workflow: %{
  type: TemplatedSemanticAgent,
  config: %{...},
  transitions: [
    {:wireframe_create, "Create wireframe"},
    {:wireframe_modify, "Modify wireframe"}
  ]
},

# Each sub-route can have its own semantic routing
wireframe_create: %{
  type: TemplatedSemanticAgent,
  config: %{...},
  transitions: [
    {:from_scratch, "Start from blank"},
    {:from_template, "Use template"}
  ]
}
```

### Pattern 4: Conditional Lens Activation

**Use Case:** Different lenses based on execution path

```elixir
visual_editing: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: "Edit visuals...",
    lenses: [
      "WireframeEditor",
      "ColorPalette",  # Only in visual path
      "SequentialThinking"
    ]
  },
  transitions: [{:end, :always}]
},

logic_editing: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: "Edit logic...",
    lenses: [
      "WireframeEditor",
      "JavaScriptDebugger",  # Only in logic path
      "SequentialThinking"
    ]
  },
  transitions: [{:end, :always}]
}
```

---

## Best Practices

### 1. Write Clear Transition Descriptions

**Good:**
```elixir
{:targeted_change, "Make a specific focused modification to existing elements"}
{:build_from_scratch, "Create a new wireframe from a blank starting point"}
```

**Bad:**
```elixir
{:targeted_change, "Change something"}  # Too vague
{:build_from_scratch, "Build"}          # Unclear what this means
```

### 2. Provide Rich Context in Templates

**Good:**
```elixir
template: """
Analyze the user's request and choose the best path.

User request: <%= List.last(@context[:messages])[:content] %>

Current state:
- Wireframe exists: <%= @context[:wireframe_exists] %>
- Element count: <%= @context[:element_count] %>
- Has JavaScript: <%= @context[:has_javascript] %>

Available paths:
- answer_directly: For questions that don't require changes
- targeted_change: For specific modifications to 1-3 elements
- build_from_scratch: For creating a new wireframe or major restructuring

Choose the path that best matches the user's intent and the current state.
"""
```

**Bad:**
```elixir
template: """
Choose a path.
"""  # No context for agent to make informed decision
```

### 3. Use Readonly Mode During Routing

**Why:** Prevents agents from making changes before understanding full intent

```elixir
routing: %{
  config: %{
    lenses: [
      ["WireframeEditor", %{readonly: true}],  # See but don't modify
      "SemanticTransition"
    ]
  }
}
```

### 4. Keep Base Lenses Minimal

**Why:** Easier to reason about what's inherited vs configured

```elixir
# Good: Start with core lenses
initial_context = %{
  lenses: ["WireframeEditor", "SequentialThinking"]
}

# Bad: Too many base lenses
initial_context = %{
  lenses: [
    "WireframeEditor", "SequentialThinking", "SemanticTransition",
    "ColorPalette", "JavaScriptDebugger", "PersonaLens"
  ]
}
```

### 5. Test Scope Isolation

**Verify:** Lens modifications don't leak between branches

```elixir
# After routing adds SemanticTransition
assert context[:lenses] includes "SemanticTransition"

# After entering action step without config
assert context[:lenses] does NOT include "SemanticTransition"
```

---

## When to Use Semantic Routing

### Use Semantic Routing When:

1. **Multiple Valid Paths:** User requests could go different directions
2. **Intent Analysis:** Need agent to understand what user wants
3. **Flexible Flow:** Paths might change over time
4. **Conversational UI:** Users describe goals, not steps
5. **Context-Dependent:** Best path depends on current state

### Don't Use Semantic Routing When:

1. **Single Path:** Only one way through the routine
2. **Fixed Sequence:** Steps must happen in specific order
3. **No Ambiguity:** Intent is always clear from context
4. **Performance Critical:** Extra LLM call is too expensive
5. **Simple Branching:** Regular conditions (`:always`, `:when_error`) suffice

### Alternative 1: Regular Transitions

```elixir
# Use regular transitions for deterministic branching
step_a: %{
  type: SomeStep,
  transitions: [
    {:step_b, :when_success},
    {:error_handler, :when_error},
    {:retry, :when_retry}
  ]
}
```

### Alternative 2: Linear Playbooks

**When You Know The Steps:** Use a linear sequential flow instead of asking the agent to decide.

Think of routines as "early binding" vs tool calls as "late binding." If you know the sequence of steps needed to accomplish a task, script them as a linear playbook rather than making the agent choose.

**Example: BuildWireframeRoutine** (`lib/koalemos/routines/build_wireframe_routine.ex`)

Building a wireframe has known stages: plan → build structure → add behavior → test → polish

```elixir
defmodule BuildWireframeRoutine do
  def start, do: :planning

  def routine_definition do
    %{
      planning: %{
        type: TemplatedSemanticAgent,
        config: %{template: "Plan the wireframe approach..."},
        transitions: [{:layout_and_structure, :always}]
      },

      layout_and_structure: %{
        type: TemplatedSemanticAgent,
        config: %{template: "Build HTML structure and layout CSS..."},
        transitions: [{:behavior, :always}]
      },

      behavior: %{
        type: TemplatedSemanticAgent,
        config: %{template: "Add event handlers and JavaScript..."},
        transitions: [{:testing, :always}]
      },

      testing: %{
        type: TemplatedSemanticAgent,
        config: %{template: "Test interactions..."},
        transitions: [{:polish, :always}]
      },

      polish: %{
        type: TemplatedSemanticAgent,
        config: %{template: "Apply visual styling..."},
        transitions: [{:complete, :always}]
      },

      complete: %{
        type: TemplatedSemanticAgent,
        config: %{template: "Summarize what was built..."},
        transitions: []
      }
    }
  end
end
```

**Key Insight:** Don't ask the agent what to do next when you already know the steps. Use semantic routing for real decision points, not for known sequences.

**Comparison:**
- **Semantic Routing:** "Should I create, modify, or analyze?" (decision point)
- **Linear Playbook:** "Build wireframe: plan → structure → behavior → test → polish" (known sequence)

---

## Troubleshooting

### Problem: Lens Modifications Leak Across Branches

**Symptom:** Action step has lenses from routing step

**Cause:** Not saving/restoring base lenses properly

**Solution:** Verify `_routine_base_lenses` is being tracked:
```elixir
# In first sub-routine, this should be saved
IO.inspect(context[:_routine_base_lenses])  # Should equal original lenses

# In steps without config, this should be restored
IO.inspect(context[:lenses])  # Should equal _routine_base_lenses
```

### Problem: Config Lenses Replace Instead of Merge

**Symptom:** Base lenses disappear when step has config

**Cause:** Not merging, just replacing

**Solution:** Check merge logic in `TemplatedSemanticAgent.setup/2`:
```elixir
merged_lenses = Koalemos.ConfigMerge.merge_lenses(base_lenses, config_lenses)
```

### Problem: Agent Doesn't Choose Transitions

**Symptom:** Agent doesn't call `choose_transition` tool

**Cause:** Tool not available or not prompted properly

**Debug:**
1. Check `tool_descriptions` includes `choose_transition`
2. Verify template mentions available transitions
3. Check `SemanticTransition` lens is active
4. Look for tool execution errors in logs

### Problem: Transitions Not Found

**Symptom:** Error "No parent routine" or empty enum

**Cause:** Execution stack doesn't have parent with transitions

**Debug:**
```elixir
# Check execution stack
IO.inspect(state[:execution_stack])

# Check routine definitions
parent = List.first(state[:execution_stack])
routine_def = state[:routine_definitions][parent.module]
IO.inspect(routine_def[parent.step][:transitions])
```

---

## Testing Semantic Routing

### Unit Tests

```elixir
test "TemplatedSemanticAgent renders template with context" do
  config = %{
    template: "User: <%= @context[:user_name] %>",
    lenses: []
  }

  state = %{context: %{user_name: "Alice", messages: []}}

  {:ok, diff} = TemplatedSemanticAgent.setup(
    %{static: config, runtime: %{}},
    state
  )

  # Should append rendered message
  message = Enum.find_value(diff, fn
    {:append_to, %{messages: msg}} -> msg
    _ -> nil
  end)

  assert message.content == "User: Alice"
end
```

### Integration Tests

```elixir
test "semantic routing workflow completes end-to-end" do
  routine_id = "test-routing-#{:rand.uniform(1000)}"

  # Start routine with semantic routing
  {:ok, pid} = Engine.start_routine(
    routine_id,
    MySemanticRoutine,
    %{user_request: "Create a login page"}
  )

  # Verify it routes correctly
  # (This would require mocking LLM to return choose_transition call)
  assert_receive {:routine_step_changed, ^routine_id, :build_from_scratch}, 5000
end
```

### Manual Testing Checklist

- [ ] Agent receives context showing available transitions
- [ ] Agent calls `choose_transition` with valid choice
- [ ] Engine transitions to chosen step
- [ ] Lenses are correct in each step (check via context dump)
- [ ] Scope isolation works (routing lenses don't leak)
- [ ] Agent can complete full routine
- [ ] Error handling works (invalid transition choice)

---

## Examples

See these files for working examples:

- **WireframeDesignRoutine:** `lib/koalemos/routines/wireframe_design_routine.ex`
  - Semantic routing with 7 sub-routines
  - Readonly lens during routing
  - Full lens configuration per branch
  - Demonstrates when to use semantic routing (routing between user intents)

- **BuildWireframeRoutine:** `lib/koalemos/routines/build_wireframe_routine.ex`
  - Linear playbook with sequential flow
  - Known sequence: planning → layout → behavior → testing → polish
  - Demonstrates when NOT to use semantic routing (known steps)
  - Called as sub-routine from WireframeDesignRoutine

- **Semantic Routing Tests:** `test/koalemos/semantic_routing_test.exs`
  - TemplatedSemanticAgent tests
  - SemanticTransition lens tests
  - Lens scoping tests

- **Routine Tests:** `test/koalemos/routines/`
  - WireframeDesignRoutine tests
  - BuildWireframeRoutine tests
  - Structure and transition verification

---

## Further Reading

- **M5 Milestone Doc:** `docs/milestones/M5.md` - Architecture overview
- **Sprint 1 Plan:** `docs/sprints/m5-sprint-1-plan.md` - Implementation details
- **Execution Engine:** `docs/ARCHITECTURE.md` - How routines and steps work
- **Lens Development:** `docs/guides/LENS_DEVELOPMENT.md` - Creating lenses
