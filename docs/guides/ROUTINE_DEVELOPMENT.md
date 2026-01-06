# Routine Development Guide

---

## TLDR

**Routines** are state machines that define conversation flows in Koalemos.

**Core pattern:**
```elixir
defmodule MyRoutine do
  def routine_definition do
    %{
      start: %{
        type: StepModule,
        transitions: [{:next_step, :always}]
      },
      next_step: %{
        type: AnotherStep,
        transitions: [{:end, :always}]
      }
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{messages: [], lenses: ["MyLens"]}
  end
end
```

**Start routine:**
```elixir
{:ok, routine_id} = EngineManager.start_routine(MyRoutine, %{extra: "context"}, "routine-id")
```

---

## Table of Contents

1. [What are Routines?](#what-are-routines)
2. [Simple Chat Routine](#simple-chat-routine)
3. [Tool-Enabled Routine](#tool-enabled-routine)
4. [Complete Example: TaskManagerRoutine](#complete-example-taskmanagerroutine)
5. [State Machine Concepts](#state-machine-concepts)
6. [Transitions and Conditions](#transitions-and-conditions)
7. [Sub-Routines](#sub-routines)
8. [Configuration](#configuration)
9. [Best Practices](#best-practices)
10. [Testing Your Routine](#testing-your-routine)
11. [Common Patterns](#common-patterns)
12. [Troubleshooting](#troubleshooting)

---

## What are Routines?

### Concept

A **routine** is a state machine that defines a conversation flow. Routines:
- Define a sequence of steps (states)
- Specify transitions between steps
- Manage conversation context (messages, lens state, etc.)
- Can be composed (routines can call other routines as sub-routines)

### Philosophy

Routines embody the **conversation flow** of your AI application:
- Each routine solves ONE conversation pattern (chat, task management, code review, etc.)
- Routines are declarative – you define the flow, the engine executes it
- Routines are reusable – one routine can be used in multiple contexts
- Complexity managed through composition (sub-routines)

### When to Create a Routine

**Create a routine when:**
- You have a multi-step conversation flow
- You need specific step ordering and transitions
- You want reusable conversation patterns
- You need to coordinate multiple lenses and steps

**Don't create a routine when:**
- You're adding a single capability (create a Lens or Step instead)
- The flow is specific to ONE routine (use sub-routines or extend existing routine)

---

## Simple Chat Routine

The simplest useful routine: user input → agent response loop.

### TestChatRoutine

**File:** `lib/koalemos/routines/test_chat_routine.ex`

```elixir
defmodule Koalemos.Routines.TestChatRoutine do
  @moduledoc """
  Simplest agent loop: user → lens → LLM → user.

  No tool execution, context-only lenses.

  ## Flow
  1. Wait for user input
  2. Render lens context
  3. Call LLM
  4. Parse response and append to messages
  5. Loop back to wait for user

  ## Usage

  {:ok, routine_id} = EngineManager.start_routine(
    TestChatRoutine,
    %{lenses: ["Koalemos.Lenses.PersonaLens"]},
    "chat-#{unique_id}"
  )
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{LensRendering, LLMRequest, ResponseParsing}

  @doc "Define the state machine"
  def routine_definition do
    %{
      # Step 1: Wait for user input
      start: %{
        type: ChatUserInput,
        transitions: [{:render_lens, :always}]
      },

      # Step 2: Get context from active lenses
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Step 3: Make LLM API request
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Step 4: Parse response, extract message and tool calls
      parse_response: %{
        type: ResponseParsing,
        transitions: [{:start, :always}]  # Loop back to wait for user
      }
    }
  end

  @doc "Check transition conditions"
  def check_condition(:always, _context), do: true

  @doc "Provide default initial context"
  def initial_context do
    %{
      messages: [],
      lenses: [],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5"
    }
  end
end
```

### Key Concepts

**1. State Machine as Map:**
- Keys are step names (`:start`, `:render_lens`, etc.)
- Values are step configurations

**2. Step Configuration:**
```elixir
step_name: %{
  type: StepModule,           # Which step to execute
  config: %{...},             # Optional static config
  transitions: [...]          # Where to go next
}
```

**3. Transitions:**
```elixir
transitions: [
  {:next_step, :condition_name},
  {:another_step, :another_condition}
]
```
- Engine evaluates conditions in order
- Takes first matching transition
- If no match, goes to `:end`

**4. Starting Step:**
- Defaults to `:start`
- Override with `def start, do: :my_start_step`

---

## Tool-Enabled Routine

Routines that support tool execution need additional steps in the loop.

### WireframeTestRoutine

**File:** `lib/koalemos/routines/wireframe_test_routine.ex`

**Key Excerpts:**

```elixir
defmodule Koalemos.Routines.WireframeTestRoutine do
  @moduledoc """
  Full agent loop with tool execution.

  ## Flow
  1. Wait for user input
  2. Build tool schemas from lenses
  3. Render lens context (with state snapshot)
  4. Call LLM with tools
  5. Parse response
  6. IF tool calls: Execute tools (loop until done)
  7. ELSE: Back to wait for user

  ## Features
  - Sample wireframe loading
  - WireframeEditor lens integration
  - Tool execution loop
  - State snapshots
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{
    ToolSchema, LensRendering, LLMRequest, ResponseParsing,
    ToolLookup, ToolExecution
  }

  def routine_definition do
    %{
      # Wait for user input
      start: %{
        type: ChatUserInput,
        transitions: [{:tool_schema, :always}]
      },

      # Build tool schemas from lenses
      tool_schema: %{
        type: ToolSchema,
        transitions: [{:render_lens, :always}]
      },

      # Render lens context (captures state snapshot)
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Call LLM with tools
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Parse response
      parse_response: %{
        type: ResponseParsing,
        transitions: [
          {:tool_lookup, :when_has_tool_calls},
          {:start, :always}
        ]
      },

      # Resolve tool names to executable refs
      tool_lookup: %{
        type: ToolLookup,
        transitions: [{:tool_execution, :always}]
      },

      # Execute ONE tool (consume pattern)
      tool_execution: %{
        type: ToolExecution,
        transitions: [
          {:tool_schema, :when_more_tools},  # Loop if more tools to execute
          {:start, :always}                  # Else back to user input
        ]
      }
    }
  end

  def check_condition(:always, _context), do: true

  def check_condition(:when_has_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls, [])
    length(tool_calls) > 0
  end

  def check_condition(:when_more_tools, context) do
    to_execute = Map.get(context, :to_execute, [])
    length(to_execute) > 0
  end

  def initial_context do
    %{
      messages: [],
      lenses: ["Koalemos.Lenses.WireframeEditor"],
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",
      llm_max_tokens: 64_000  # Wireframes need more tokens
    }
  end

  @doc "Setup function - loads sample wireframe if specified"
  def setup(context) do
    sample = Map.get(context, :wireframe_sample)
    html_content = Map.get(context, :wireframe_html)

    cond do
      sample ->
        load_sample_wireframe(sample, context)

      html_content ->
        parse_and_init_wireframe(html_content, context)

      true ->
        {:ok, []}  # No wireframe to load
    end
  end

  defp load_sample_wireframe(sample_name, context) do
    samples_dir = Path.join([File.cwd!(), "priv", "samples"])
    file_path = Path.join(samples_dir, "#{sample_name}.html")

    case File.read(file_path) do
      {:ok, html_content} ->
        parse_and_init_wireframe(html_content, context)

      {:error, reason} ->
        {:error, "Failed to load sample: #{reason}"}
    end
  end

  defp parse_and_init_wireframe(html_content, _context) do
    # Parse HTML with ParsingIntegration
    case Koalemos.Integrations.ParsingIntegration.parse_wireframe(html_content, "wireframe") do
      {:ok, parsed} ->
        # Initialize lens_state with parsed wireframe
        {:ok, [
          add_or_update: %{
            lens_state: %{
              designed_dom: parsed.dom_tree,
              styles: parsed.styles,
              scripts: parsed.scripts,
              functions: parsed.functions,
              variables: parsed.variables,
              handlers: parsed.handlers
            }
          }
        ]}

      {:error, reason} ->
        {:error, "Failed to parse wireframe: #{reason}"}
    end
  end
end
```

### Tool Execution Loop

**Key pattern:**

1. **Parse finds tool calls** → `:tool_lookup` (condition: `when_has_tool_calls`)
2. **Lookup resolves tools** → `:tool_execution`
3. **Execution runs ONE tool** → back to `:tool_schema` (condition: `when_more_tools`)
4. **Repeat** until `to_execute` empty → back to `:start`

This loop ensures:
- Tools execute sequentially (one at a time)
- Lens updates applied after each tool
- Context captured before next LLM request

---

## Complete Example: TaskManagerRoutine

Let's build a complete task management routine from scratch.

**Purpose:** Manage tasks with states (todo, in progress, done), priorities, and due dates.

**File:** `lib/koalemos/routines/task_manager_routine.ex`

```elixir
defmodule Koalemos.Routines.TaskManagerRoutine do
  @moduledoc """
  Task management routine with full CRUD operations.

  ## Features
  - Create tasks with priority and due date
  - Update task status (todo → in_progress → done)
  - List tasks filtered by status
  - Delete tasks
  - Summary view of all tasks

  ## Usage

  {:ok, routine_id} = EngineManager.start_routine(
    TaskManagerRoutine,
    %{},
    "tasks-#{unique_id}"
  )
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{
    ToolSchema, LensRendering, LLMRequest, ResponseParsing,
    ToolLookup, ToolExecution
  }

  @doc "Define the state machine - full agent loop with tools"
  def routine_definition do
    %{
      start: %{type: ChatUserInput, transitions: [{:tool_schema, :always}]},
      tool_schema: %{type: ToolSchema, transitions: [{:render_lens, :always}]},
      render_lens: %{type: LensRendering, transitions: [{:llm_request, :always}]},
      llm_request: %{type: LLMRequest, transitions: [{:parse_response, :always}]},
      parse_response: %{
        type: ResponseParsing,
        transitions: [
          {:tool_lookup, :when_has_tool_calls},
          {:start, :always}
        ]
      },
      tool_lookup: %{type: ToolLookup, transitions: [{:tool_execution, :always}]},
      tool_execution: %{
        type: ToolExecution,
        transitions: [
          {:tool_schema, :when_more_tools},
          {:start, :always}
        ]
      }
    }
  end

  @doc "Condition checks"
  def check_condition(:always, _context), do: true

  def check_condition(:when_has_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls, [])
    length(tool_calls) > 0
  end

  def check_condition(:when_more_tools, context) do
    to_execute = Map.get(context, :to_execute, [])
    length(to_execute) > 0
  end

  @doc "Initial context with TaskLens active"
  def initial_context do
    %{
      messages: [],
      lenses: ["Koalemos.Lenses.TaskLens"],  # Assuming we created this lens
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5",
      lens_state: %{
        tasks: %{},
        next_id: 1
      }
    }
  end
end
```

**Companion Lens:** `lib/koalemos/lenses/task_lens.ex`

```elixir
defmodule Koalemos.Lenses.TaskLens do
  @moduledoc """
  Task management lens providing CRUD operations.

  ## State Structure

  lens_state: %{
    tasks: %{
      "task-1" => %{
        id: "task-1",
        title: "...",
        description: "...",
        status: :todo | :in_progress | :done,
        priority: :low | :medium | :high,
        due_date: ~D[2025-11-15],
        created_at: DateTime,
        updated_at: DateTime
      }
    },
    next_id: 2
  }
  """

  def provide_context(context, _config) do
    lens_state = Map.get(context, :lens_state, %{})
    tasks = Map.get(lens_state, :tasks, %{})

    if map_size(tasks) == 0 do
      [%{
        type: "text",
        text: """
        ## Task Manager

        No tasks yet. Use `create_task` to get started.
        """
      }]
    else
      summary = build_task_summary(tasks)

      [%{
        type: "text",
        text: """
        ## Task Manager

        #{summary}

        Use task tools to manage tasks.
        """
      }]
    end
  end

  def tools do
    [
      {__MODULE__, :create_task},
      {__MODULE__, :update_task_status},
      {__MODULE__, :update_task_priority},
      {__MODULE__, :list_tasks},
      {__MODULE__, :delete_task}
    ]
  end

  def info(:create_task) do
    %{
      name: "create_task",
      description: "Create a new task with title, description, priority, and due date",
      input_schema: %{
        type: "object",
        properties: %{
          title: %{type: "string", description: "Task title"},
          description: %{type: "string", description: "Task description (optional)"},
          priority: %{
            type: "string",
            enum: ["low", "medium", "high"],
            description: "Task priority (default: medium)"
          },
          due_date: %{
            type: "string",
            pattern: "^\\d{4}-\\d{2}-\\d{2}$",
            description: "Due date in YYYY-MM-DD format (optional)"
          }
        },
        required: ["title"]
      }
    }
  end

  def info(:update_task_status) do
    %{
      name: "update_task_status",
      description: "Update task status to todo, in_progress, or done",
      input_schema: %{
        type: "object",
        properties: %{
          task_id: %{type: "string", description: "Task ID"},
          status: %{
            type: "string",
            enum: ["todo", "in_progress", "done"],
            description: "New status"
          }
        },
        required: ["task_id", "status"]
      }
    }
  end

  def info(:update_task_priority) do
    %{
      name: "update_task_priority",
      description: "Update task priority",
      input_schema: %{
        type: "object",
        properties: %{
          task_id: %{type: "string", description: "Task ID"},
          priority: %{
            type: "string",
            enum: ["low", "medium", "high"],
            description: "New priority"
          }
        },
        required: ["task_id", "priority"]
      }
    }
  end

  def info(:list_tasks) do
    %{
      name: "list_tasks",
      description: "List tasks filtered by status",
      input_schema: %{
        type: "object",
        properties: %{
          status: %{
            type: "string",
            enum: ["all", "todo", "in_progress", "done"],
            description: "Filter by status (default: all)"
          }
        }
      }
    }
  end

  def info(:delete_task) do
    %{
      name: "delete_task",
      description: "Delete a task by ID",
      input_schema: %{
        type: "object",
        properties: %{
          task_id: %{type: "string", description: "Task ID to delete"}
        },
        required: ["task_id"]
      }
    }
  end

  def execute(:create_task, args, context) do
    title = Map.get(args, "title")
    description = Map.get(args, "description", "")
    priority = String.to_atom(Map.get(args, "priority", "medium"))
    due_date_str = Map.get(args, "due_date")

    lens_state = Map.get(context, :lens_state, %{})
    tasks = Map.get(lens_state, :tasks, %{})
    next_id = Map.get(lens_state, :next_id, 1)

    task_id = "task-#{next_id}"
    now = DateTime.utc_now()

    due_date = if due_date_str do
      case Date.from_iso8601(due_date_str) do
        {:ok, date} -> date
        _ -> nil
      end
    else
      nil
    end

    task = %{
      id: task_id,
      title: title,
      description: description,
      status: :todo,
      priority: priority,
      due_date: due_date,
      created_at: now,
      updated_at: now
    }

    updated_tasks = Map.put(tasks, task_id, task)

    result = "Created task '#{title}' with ID #{task_id}"
    {result, [tasks: updated_tasks, next_id: next_id + 1]}
  end

  def execute(:update_task_status, args, context) do
    task_id = Map.get(args, "task_id")
    new_status = String.to_atom(Map.get(args, "status"))

    lens_state = Map.get(context, :lens_state, %{})
    tasks = Map.get(lens_state, :tasks, %{})

    case Map.get(tasks, task_id) do
      nil ->
        {"Error: Task #{task_id} not found", []}

      task ->
        updated_task = %{task | status: new_status, updated_at: DateTime.utc_now()}
        updated_tasks = Map.put(tasks, task_id, updated_task)

        {"Updated '#{task.title}' status to #{new_status}", [tasks: updated_tasks]}
    end
  end

  def execute(:update_task_priority, args, context) do
    task_id = Map.get(args, "task_id")
    new_priority = String.to_atom(Map.get(args, "priority"))

    lens_state = Map.get(context, :lens_state, %{})
    tasks = Map.get(lens_state, :tasks, %{})

    case Map.get(tasks, task_id) do
      nil ->
        {"Error: Task #{task_id} not found", []}

      task ->
        updated_task = %{task | priority: new_priority, updated_at: DateTime.utc_now()}
        updated_tasks = Map.put(tasks, task_id, updated_task)

        {"Updated '#{task.title}' priority to #{new_priority}", [tasks: updated_tasks]}
    end
  end

  def execute(:list_tasks, args, context) do
    status_filter = Map.get(args, "status", "all")

    lens_state = Map.get(context, :lens_state, %{})
    tasks = Map.get(lens_state, :tasks, %{})

    filtered_tasks = if status_filter == "all" do
      Map.values(tasks)
    else
      status_atom = String.to_atom(status_filter)
      tasks
      |> Map.values()
      |> Enum.filter(fn task -> task.status == status_atom end)
    end

    if length(filtered_tasks) == 0 do
      {"No tasks found with status: #{status_filter}", []}
    else
      list = format_task_list(filtered_tasks)
      {list, []}
    end
  end

  def execute(:delete_task, args, context) do
    task_id = Map.get(args, "task_id")

    lens_state = Map.get(context, :lens_state, %{})
    tasks = Map.get(lens_state, :tasks, %{})

    case Map.get(tasks, task_id) do
      nil ->
        {"Error: Task #{task_id} not found", []}

      task ->
        updated_tasks = Map.delete(tasks, task_id)
        {"Deleted task '#{task.title}'", [tasks: updated_tasks]}
    end
  end

  # Private helpers

  defp build_task_summary(tasks) do
    by_status = Enum.group_by(Map.values(tasks), & &1.status)

    todo_count = length(Map.get(by_status, :todo, []))
    in_progress_count = length(Map.get(by_status, :in_progress, []))
    done_count = length(Map.get(by_status, :done, []))

    """
    **Summary:**
    - Todo: #{todo_count}
    - In Progress: #{in_progress_count}
    - Done: #{done_count}
    - Total: #{map_size(tasks)}
    """
  end

  defp format_task_list(tasks) do
    tasks
    |> Enum.sort_by(& &1.created_at, DateTime)
    |> Enum.map(&format_task/1)
    |> Enum.join("\n\n")
  end

  defp format_task(task) do
    status_emoji = case task.status do
      :todo -> "⬜"
      :in_progress -> "🔵"
      :done -> "✅"
    end

    priority_emoji = case task.priority do
      :low -> "🔽"
      :medium -> "➖"
      :high -> "🔺"
    end

    due_date_str = if task.due_date do
      "| Due: #{Date.to_string(task.due_date)}"
    else
      ""
    end

    """
    #{status_emoji} **#{task.title}** #{priority_emoji}
    #{task.id} #{due_date_str}
    #{task.description}
    """
  end
end
```

---

## State Machine Concepts

### Steps are States

Each step in your routine is a state in the state machine:

```elixir
%{
  waiting_for_user: %{...},   # State 1
  processing: %{...},          # State 2
  done: %{...}                 # State 3
}
```

### Transitions are Edges

Transitions define valid state changes:

```
waiting_for_user --(:always)--> processing
processing --(:when_success)--> done
processing --(:when_error)--> waiting_for_user
```

### Context is State Data

The `context` map holds all state data:

```elixir
%{
  messages: [...],           # Conversation history
  lens_state: %{...},        # Lens-specific state
  tool_calls: [...],         # Pending tool calls
  config: %{...},            # Configuration
  # ... any custom data
}
```

### Special States

- **`:start`** - Default entry point (override with `def start, do: :my_step`)
- **`:end`** - Terminal state (routine completes)
- **`:error`** - Error state (routine fails)

---

## Transitions and Conditions

### Transition Format

```elixir
transitions: [
  {:next_step, :condition_name},
  {:another_step, :another_condition},
  {:end, :always}  # Fallback
]
```

### Condition Evaluation

1. Engine calls `check_condition/2` for each transition in order
2. First transition that returns `true` is taken
3. If no transitions match, routine goes to `:end`

### Common Condition Patterns

**Always:**
```elixir
def check_condition(:always, _context), do: true
```

**Context Check:**
```elixir
def check_condition(:when_has_data, context) do
  data = Map.get(context, :my_data)
  data != nil && data != []
end
```

**Flag Check:**
```elixir
def check_condition(:when_complete, context) do
  Map.get(context, :is_complete, false)
end
```

**List Empty/Non-Empty:**
```elixir
def check_condition(:when_more_items, context) do
  items = Map.get(context, :items, [])
  length(items) > 0
end
```

**Complex Logic:**
```elixir
def check_condition(:when_ready_to_proceed, context) do
  has_data = Map.get(context, :data) != nil
  not_processing = Map.get(context, :processing, false) == false
  has_data && not_processing
end
```

### Multi-Way Branching

```elixir
parse_response: %{
  type: ResponseParsing,
  transitions: [
    {:handle_error, :when_error},           # Check first
    {:execute_tools, :when_has_tool_calls}, # Then this
    {:wait_for_user, :always}               # Fallback
  ]
}
```

---

## Sub-Routines

### Concept

Any step can be a routine itself. The engine automatically detects this and enters it as a sub-routine.

### When to Use Sub-Routines

- **Complex multi-step operations** that need their own state machine
- **Reusable routines** used by multiple parent routines
- **Conditional branches** that have complex internal logic

### Pattern

**Parent Routine:**

```elixir
defmodule ParentRoutine do
  def routine_definition do
    %{
      start: %{type: ChatUserInput, transitions: [{:complex_task, :always}]},

      # This step is actually a sub-routine!
      complex_task: %{
        type: ComplexSubRoutine,
        transitions: [{:finish, :always}]
      },

      finish: %{type: SummaryStep, transitions: [{:end, :always}]}
    }
  end
end
```

**Sub-Routine:**

```elixir
defmodule ComplexSubRoutine do
  # Has its own routine_definition - engine detects this
  def routine_definition do
    %{
      start: %{type: Step1, transitions: [{:step2, :always}]},
      step2: %{type: Step2, transitions: [{:step3, :always}]},
      step3: %{type: Step3, transitions: [{:end, :always}]}
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context, do: %{}
end
```

### Sub-Routine Execution Flow

1. Parent reaches `complex_task` step
2. Engine sees `ComplexSubRoutine` has `routine_definition/0`
3. Engine pushes current state onto execution stack
4. Engine loads sub-routine definition, sets current step to sub-routine's `:start`
5. Sub-routine executes normally
6. When sub-routine reaches `:end`, engine pops execution stack
7. Parent continues from `complex_task` → `finish` transition

### Context Sharing

Sub-routines **share the same context** as parent. Any changes to context in sub-routine persist in parent.

```elixir
# Sub-routine can update shared context
def execute(_config, context) do
  {:ok, [add_or_update: %{sub_routine_data: "value"}]}
end

# Parent can read it after sub-routine completes
def execute(_config, context) do
  data = Map.get(context, :sub_routine_data)  # "value"
end
```

---

## Configuration

### Static Configuration

Defined in routine definition:

```elixir
my_step: %{
  type: MyStep,
  config: %{
    option1: "value",
    option2: 42
  },
  transitions: [...]
}
```

Steps receive this in `config_sources.static`.

### Runtime Configuration

Passed when starting routine or updated during execution:

```elixir
# At start
EngineManager.start_routine(MyRoutine, %{
  config: %{
    my_step: %{option1: "runtime_value"}
  }
}, routine_id)

# During execution (in a step)
{:ok, [add_or_update: %{
  config: %{
    my_step: %{option1: "updated_value"}
  }
}]}
```

Steps receive this in `config_sources.runtime`.

### Hybrid Config Pattern

Steps merge static and runtime config:

```elixir
def execute(config_sources, state) do
  # Runtime overrides static
  option1 = ConfigMerge.get_key(config_sources, :option1, "default")
end
```

---

## Best Practices

### General

1. **Single Responsibility** - One routine, one conversation pattern
2. **Clear Naming** - Name describes what the routine does (ChatRoutine, TaskManagerRoutine)
3. **Comprehensive Docs** - Moduledoc with flow diagram, features, usage example
4. **Start Simple** - Begin with minimal flow, add complexity as needed
5. **Test Thoroughly** - Unit tests for conditions, integration tests for full flow

### State Machine Design

1. **Keep Steps Small** - Each step does ONE thing
2. **Explicit Transitions** - Always specify transitions, even if just `{:end, :always}`
3. **Order Conditions** - Put most specific conditions first
4. **Handle All Cases** - Always have an `:always` fallback
5. **Avoid Loops** - Be careful with circular transitions (can create infinite loops)

### Context Management

1. **Initialize in initial_context/0** - Set up required keys with defaults
2. **Document Context Keys** - List all context keys in moduledoc
3. **Clean Up Temporary Data** - Remove transient data when no longer needed
4. **Namespace Custom Data** - Use specific keys (not generic like `:data`)

### Tool Execution

1. **Use Standard Pattern** - Follow the tool execution loop pattern (tool_schema → render_lens → llm_request → parse → tool_lookup → tool_execution)
2. **One Tool at a Time** - ToolExecution consumes one tool per execution
3. **Loop Until Done** - Check `when_more_tools` condition

### Error Handling

1. **Anticipate Failures** - Have error branches in transitions
2. **Log Errors** - Use Logger for debugging
3. **User-Friendly Messages** - Return helpful error messages to user
4. **Recover Gracefully** - Don't crash, transition to error handling state

---

## Testing Your Routine

### Unit Tests

Test conditions independently:

```elixir
defmodule MyRoutineTest do
  use ExUnit.Case
  alias MyRoutine

  describe "check_condition/2" do
    test "when_has_data returns true when data present" do
      context = %{my_data: "value"}
      assert MyRoutine.check_condition(:when_has_data, context)
    end

    test "when_has_data returns false when data missing" do
      context = %{}
      refute MyRoutine.check_condition(:when_has_data, context)
    end
  end

  describe "initial_context/0" do
    test "provides default context" do
      context = MyRoutine.initial_context()

      assert context.messages == []
      assert context.lenses != nil
    end
  end
end
```

### Integration Tests

Test full routine execution:

```elixir
defmodule MyRoutineIntegrationTest do
  use ExUnit.Case
  alias Koalemos.{Engine, EngineManager}

  @tag :integration
  test "completes full flow" do
    routine_id = "test-#{:erlang.unique_integer()}"

    # Start routine
    {:ok, ^routine_id} = EngineManager.start_routine(MyRoutine, %{}, routine_id)

    # Send event
    Engine.send_external_event(routine_id, :user_input, "Hello")

    # Wait for processing
    Process.sleep(1000)

    # Verify state
    state = EngineManager.get_routine_state(routine_id)
    assert state.context.messages != []

    # Cleanup
    EngineManager.stop_routine(routine_id)
  end
end
```

### Manual Testing with LiveView

Create a test page:

```elixir
defmodule KoalemosWeb.MyRoutineTestLive do
  use KoalemosWeb, :live_view
  alias Koalemos.{Engine, EngineManager}

  def mount(_params, _session, socket) do
    routine_id = "my-routine-#{:erlang.unique_integer()}"

    {:ok, ^routine_id} = EngineManager.start_routine(
      MyRoutine,
      %{},
      routine_id
    )

    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

    {:ok, assign(socket, routine_id: routine_id, messages: [])}
  end

  def handle_event("send_message", %{"message" => text}, socket) do
    Engine.send_external_event(socket.assigns.routine_id, :user_input, text)
    {:noreply, socket}
  end

  def handle_info({:event, event}, socket) do
    messages = event.metadata.context.messages || []
    {:noreply, assign(socket, messages: messages)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>My Routine Test</h1>
      <div id="messages">
        <%= for msg <- @messages do %>
          <div><%= inspect(msg) %></div>
        <% end %>
      </div>
      <form phx-submit="send_message">
        <input type="text" name="message" />
        <button>Send</button>
      </form>
    </div>
    """
  end
end
```

---

## Common Patterns

### Pattern: Simple Loop

User input → process → response → loop back:

```elixir
%{
  start: %{type: ChatUserInput, transitions: [{:process, :always}]},
  process: %{type: ProcessStep, transitions: [{:start, :always}]}
}
```

### Pattern: Conditional Branch

Different paths based on context:

```elixir
%{
  start: %{type: ChatUserInput, transitions: [{:decision, :always}]},
  decision: %{
    type: DecisionStep,
    transitions: [
      {:path_a, :when_condition_a},
      {:path_b, :when_condition_b},
      {:fallback, :always}
    ]
  },
  path_a: %{type: StepA, transitions: [{:end, :always}]},
  path_b: %{type: StepB, transitions: [{:end, :always}]},
  fallback: %{type: DefaultStep, transitions: [{:end, :always}]}
}
```

### Pattern: Multi-Phase Workflow

Sequential phases:

```elixir
%{
  start: %{type: InitStep, transitions: [{:phase1, :always}]},
  phase1: %{type: Phase1Steps, transitions: [{:phase2, :when_phase1_complete}]},
  phase2: %{type: Phase2Steps, transitions: [{:phase3, :when_phase2_complete}]},
  phase3: %{type: Phase3Steps, transitions: [{:finalize, :when_phase3_complete}]},
  finalize: %{type: FinalStep, transitions: [{:end, :always}]}
}
```

### Pattern: Error Recovery

Error handling with recovery:

```elixir
%{
  start: %{type: ChatUserInput, transitions: [{:process, :always}]},
  process: %{
    type: ProcessStep,
    transitions: [
      {:handle_error, :when_error},
      {:success, :always}
    ]
  },
  handle_error: %{
    type: ErrorStep,
    transitions: [
      {:retry, :when_recoverable},
      {:abort, :always}
    ]
  },
  retry: %{type: RetryStep, transitions: [{:process, :always}]},
  abort: %{type: AbortStep, transitions: [{:end, :always}]},
  success: %{type: SuccessStep, transitions: [{:start, :always}]}
}
```

---

## Troubleshooting

### Routine Never Starts

**Symptom:** EngineManager.start_routine returns {:ok, routine_id} but nothing happens.

**Causes:**
1. Missing `routine_definition/0`
2. Empty routine definition
3. No `:start` step and no `start/0` function

**Fix:**
```elixir
# Ensure you have routine_definition/0
def routine_definition do
  %{
    start: %{...}
  }
end
```

### Routine Gets Stuck

**Symptom:** Routine stops progressing, stays on one step.

**Causes:**
1. Step waiting for event that never comes
2. No transitions from current step
3. All transition conditions return false
4. Step returns error but no error handling

**Fix:**
```elixir
# Always have fallback transition
my_step: %{
  type: MyStep,
  transitions: [
    {:next, :when_ready},
    {:end, :always}  # Fallback
  ]
}

# Ensure at least one condition always true
def check_condition(:always, _context), do: true
```

### Infinite Loop

**Symptom:** Routine loops forever between same steps.

**Causes:**
1. Circular transitions without exit condition
2. Condition always true

**Fix:**
```elixir
# Add counter to break loops
def check_condition(:when_not_max_retries, context) do
  retries = Map.get(context, :retries, 0)
  retries < 3
end

# Step increments counter
{:ok, [add_or_update: %{retries: retries + 1}]}
```

### Context Data Missing

**Symptom:** Step can't find expected data in context.

**Causes:**
1. Not initialized in `initial_context/0`
2. Previous step didn't add data
3. Typo in key name

**Fix:**
```elixir
# Initialize in initial_context
def initial_context do
  %{
    messages: [],
    my_data: %{},  # Initialize all expected keys
    flags: %{}
  }
end

# Defensively read from context
my_data = Map.get(context, :my_data, %{})  # Provide default
```

### Condition Not Triggering

**Symptom:** Transition condition should be true but isn't taken.

**Causes:**
1. Condition comes after another that's always true
2. Condition logic is wrong
3. Context key is wrong

**Fix:**
```elixir
# Order matters - put specific conditions first
transitions: [
  {:specific_case, :when_specific},  # Check first
  {:general_case, :always}           # Fallback
]

# Debug condition
def check_condition(:when_specific, context) do
  result = Map.get(context, :my_key) == "expected"
  Logger.debug("Condition :when_specific = #{result}")
  result
end
```

### Sub-Routine Not Executing

**Symptom:** Step that should be sub-routine executes as normal step.

**Causes:**
1. Sub-routine module doesn't implement `routine_definition/0`
2. Sub-routine not loaded (compile error)

**Fix:**
```elixir
# Ensure sub-routine has routine_definition/0
defmodule MySubRoutine do
  def routine_definition do
    %{start: %{...}}
  end
end

# Verify it's in the right place
my_sub_routine_step: %{
  type: MySubRoutine,  # Module name
  transitions: [...]
}
```

---

## Advanced Topics

### Dynamic Step Selection

Use a step that decides which step to execute next at runtime:

```elixir
defmodule RouterStep do
  def execute(_config, state) do
    next_step = determine_next_step(state.context)

    # Set a flag that conditions can check
    {:ok, [add_or_update: %{next_step: next_step}]}
  end
end

# In routine
router: %{
  type: RouterStep,
  transitions: [
    {:step_a, :when_next_is_a},
    {:step_b, :when_next_is_b},
    {:step_c, :always}
  ]
}
```

### External Event Handling

Respond to events from outside the routine:

```elixir
# In routine definition
def external_events do
  [
    {:custom_event, fn context, data ->
      # Process event, return context diff
      {context, [add_or_update: %{event_data: data}]}
    end}
  ]
end

# Trigger from outside
Engine.send_external_event(routine_id, :custom_event, %{data: "value"})
```

### Timeout Handling

Handle step timeouts:

```elixir
wait_with_timeout: %{
  type: ChatUserInput,
  transitions: [
    {:timeout_handler, :when_timeout},
    {:process, :always}
  ]
}

# ChatUserInput supports timeout via engine handle_event
# Set timeout in step implementation
```

---

## Summary

**You now know:**
- What routines are and when to create them
- Simple chat routine pattern (TestChatRoutine)
- Tool-enabled routine pattern (WireframeTestRoutine)
- How to build complete routines from scratch (TaskManagerRoutine)
- State machine concepts and transition logic
- Sub-routine composition
- Configuration patterns
- Best practices for routine design
- Testing strategies
- Common patterns and troubleshooting

**Next steps:**
1. Read `docs/guides/LENS_DEVELOPMENT.md` to learn how to create lenses for your routines
2. Study existing routines in `lib/koalemos/routines/`
3. Build your own routine for your use case
4. Combine routines with custom lenses for powerful applications

**Questions?** Check `docs/ARCHITECTURE.md` for deeper technical details, or study the source code of existing routines.
