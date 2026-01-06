# Lens Development Guide

---

## TLDR

**Lenses** are pluggable capabilities that provide context and/or tools to conversational AI agents.

**Two types:**
1. **Context-Only**: Provide information only (e.g., PersonaLens) – implement `provide_context/2`
2. **Tool-Providing**: Provide both context AND executable tools (e.g., SequentialThinking, WireframeEditor) – implement `provide_context/2`, `tools/0`, `execute/3`, `info/1`

**Quick pattern:**
```elixir
defmodule MyLens do
  # Context-only: Just this
  def provide_context(_context, _config), do: [%{type: "text", text: "..."}]

  # Tool-providing: Add these
  def tools(), do: [{MyLens, :my_tool}]
  def info(:my_tool), do: %{name: "my_tool", description: "...", input_schema: %{...}}
  def execute(:my_tool, args, _context), do: {"result", [lens_key: value]}
end
```

**Use in routine:**
```elixir
initial_context: %{
  lenses: ["MyLens"]  # Or with config: [["MyLens", %{option: value}]]
}
```

---

## Table of Contents

1. [What are Lenses?](#what-are-lenses)
2. [Context-Only Lenses](#context-only-lenses)
3. [Tool-Providing Lenses](#tool-providing-lenses)
4. [Complete Example: NotesLens](#complete-example-noteslens)
5. [Lens State Management](#lens-state-management)
6. [Configuration Patterns](#configuration-patterns)
7. [Best Practices](#best-practices)
8. [Testing Your Lens](#testing-your-lens)
9. [Common Patterns](#common-patterns)
10. [Troubleshooting](#troubleshooting)

---

## What are Lenses?

### Concept

A **lens** is a perspective on your application's data or capabilities. Lenses:
- Provide contextual information to the AI agent (via system prompt)
- Optionally provide tools the agent can execute
- Maintain their own state across conversation turns
- Are composable (multiple lenses can be active simultaneously)

### Philosophy

Think of lenses as **pluggable capabilities**:
- Each lens focuses on ONE domain (persona, reasoning, wireframes, notes, etc.)
- Lenses are independent – they don't depend on each other
- Lenses are reusable across different routines
- Complex features emerge from composing simple lenses

### When to Create a Lens

**Create a context-only lens when:**
- You want to influence HOW the agent responds (tone, style, expertise)
- You need to inject domain knowledge or instructions
- The capability is purely informational (no actions)

**Create a tool-providing lens when:**
- You want the agent to PERFORM actions (modify data, trigger operations)
- You need structured input/output (tool schemas enforce structure)
- You want atomic, trackable operations (each tool call is recorded)

**Don't create a lens when:**
- You're just adding a simple step to a routine (use a regular Step instead)
- The capability is routine-specific (build it into the routine)
- You need UI-only functionality (use LiveView components)

---

## Context-Only Lenses

Context-only lenses provide information to the agent without offering tools.

### Interface

**Required Function:**

```elixir
@spec provide_context(context :: map(), config :: map()) :: [context_block()]
```

**Context Block Types:**
- Text: `%{type: "text", text: "Information here..."}`
- Image: `%{type: "image", source: %{type: "base64", media_type: "image/png", data: "..."}}`

### Example: PersonaLens

**File:** `lib/koalemos/lenses/persona_lens.ex`

**Purpose:** Configure AI communication style along three dimensions: tone, expertise, style.

**Implementation:**

```elixir
defmodule Koalemos.Lenses.PersonaLens do
  @moduledoc """
  Context-only lens that configures AI persona dimensions.

  ## Configuration

  lenses: [
    ["Koalemos.Lenses.PersonaLens", %{
      tone: :professional,        # professional | casual | friendly | empathetic
      expertise: [:technical, :ux], # list: technical | creative | business | analytical | ux
      style: :balanced            # concise | detailed | balanced | storytelling
    }]
  ]
  """

  @doc "Provide context blocks for configured persona dimensions"
  def provide_context(_context, config) do
    [
      build_tone_context(config[:tone]),
      build_expertise_context(config[:expertise]),
      build_style_context(config[:style])
    ]
    |> Enum.filter(& &1)  # Remove nils
  end

  defp build_tone_context(:professional) do
    %{
      type: "text",
      text: """
      ## Communication Tone: Professional

      Maintain a professional, respectful tone:
      - Use clear, precise language
      - Avoid slang or overly casual expressions
      - Be courteous and constructive
      """
    }
  end

  defp build_tone_context(:casual) do
    %{
      type: "text",
      text: """
      ## Communication Tone: Casual

      Be friendly and conversational:
      - Use natural, relaxed language
      - It's okay to be informal
      - Keep it light and approachable
      """
    }
  end

  defp build_tone_context(nil), do: nil

  defp build_expertise_context(nil), do: nil
  defp build_expertise_context([]), do: nil

  defp build_expertise_context(expertise_list) when is_list(expertise_list) do
    expertise_descriptions = Enum.map_join(expertise_list, "\n", fn exp ->
      "- **#{exp}**: #{get_expertise_description(exp)}"
    end)

    %{
      type: "text",
      text: """
      ## Expertise Areas

      Apply knowledge from these domains:
      #{expertise_descriptions}
      """
    }
  end

  defp get_expertise_description(:technical), do: "Focus on technical accuracy, code quality, architecture"
  defp get_expertise_description(:creative), do: "Emphasize innovation, user experience, aesthetics"
  defp get_expertise_description(:business), do: "Consider business value, ROI, stakeholder needs"
  defp get_expertise_description(:analytical), do: "Use data-driven reasoning, logical analysis"
  defp get_expertise_description(:ux), do: "Prioritize user needs, usability, accessibility"

  defp build_style_context(:concise) do
    %{
      type: "text",
      text: """
      ## Response Style: Concise

      Keep responses brief and to the point:
      - Short sentences
      - Bullet points when appropriate
      - Avoid unnecessary elaboration
      """
    }
  end

  defp build_style_context(:detailed) do
    %{
      type: "text",
      text: """
      ## Response Style: Detailed

      Provide thorough, comprehensive responses:
      - Explain reasoning
      - Include examples
      - Cover edge cases
      """
    }
  end

  defp build_style_context(nil), do: nil
end
```

**Usage in Routine:**

```elixir
def initial_context do
  %{
    lenses: [
      ["Koalemos.Lenses.PersonaLens", %{
        tone: :professional,
        expertise: [:technical, :ux],
        style: :balanced
      }]
    ]
  }
end
```

**Key Patterns:**

1. **Dimensional Configuration** - Multiple independent dimensions (tone, expertise, style)
2. **Private Builders** - Each dimension has its own builder function
3. **Nil Handling** - Gracefully handle missing/nil config values
4. **Clear Documentation** - Docstring explains all options

---

## Tool-Providing Lenses

Tool-providing lenses offer both context AND executable tools.

### Interface

**Required Functions:**

```elixir
# Provide context (same as context-only)
@spec provide_context(context :: map(), config :: map()) :: [context_block()]

# List available tools
@spec tools() :: [{module(), tool_atom()}]

# Provide schema for a tool
@spec info(tool_atom()) :: tool_schema()

# Execute a tool
@spec execute(tool_atom(), args :: map(), context :: map()) :: tool_result()
```

**Tool Schema Format (Anthropic):**

```elixir
%{
  name: "tool_name",                # String name (must match execute/3 atom)
  description: "What it does...",   # Clear description
  input_schema: %{                  # JSON Schema for args
    type: "object",
    properties: %{
      param1: %{
        type: "string",
        description: "What this param does"
      },
      param2: %{
        type: "integer",
        minimum: 1,
        maximum: 100,
        description: "Another param"
      }
    },
    required: ["param1"]  # List of required params
  }
}
```

**Tool Result Formats:**

```elixir
# Simple string
"Operation completed successfully"

# String with lens state updates
{"Operation completed", [key: value, another: data]}

# String with lens state updates and metadata
{"Operation completed", [key: value], %{metadata: "info"}}

# Content blocks (text + images)
{[
  {:text, "Result text"},
  {:image, base64_data, "image/png"}
], [lens_updates]}
```

### Example: SequentialThinking

**File:** `lib/koalemos/lenses/sequential_thinking.ex`

**Purpose:** Structured step-by-step reasoning with visible thought process.

**Key Excerpts:**

```elixir
defmodule Koalemos.Lenses.SequentialThinking do
  @moduledoc """
  Tool-providing lens for sequential thinking.

  Ported from Anthropic's Sequential Thinking MCP server (MIT license).
  Adapted to Koalemos lens architecture.
  """

  # Context: Show current reasoning chain
  def provide_context(context, _config) do
    lens_state = Map.get(context, :lens_state, %{})
    thought_history = Map.get(lens_state, :thought_history, [])

    if length(thought_history) > 0 do
      formatted_thoughts = format_thought_chain(thought_history)

      [%{
        type: "text",
        text: """
        ## Current Thinking Chain

        #{formatted_thoughts}

        Continue your reasoning using the sequential_thinking tool.
        """
      }]
    else
      []
    end
  end

  # List available tools
  def tools do
    [{__MODULE__, :sequential_thinking}]
  end

  # Tool schema
  def info(:sequential_thinking) do
    %{
      name: "sequential_thinking",
      description: """
      Step-by-step reasoning with visible thought process.
      Use for complex problems requiring structured analysis.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          thought: %{
            type: "string",
            description: "Your current thinking step"
          },
          next_thought_needed: %{
            type: "boolean",
            description: "Do you need to think more?"
          },
          thought_number: %{
            type: "integer",
            minimum: 1,
            description: "Current thought number (1-indexed)"
          },
          total_thoughts: %{
            type: "integer",
            minimum: 1,
            description: "Estimated total thoughts (can adjust)"
          }
        },
        required: ["thought", "next_thought_needed", "thought_number", "total_thoughts"]
      }
    }
  end

  # Execute tool
  def execute(:sequential_thinking, args, context) do
    lens_state = Map.get(context, :lens_state, %{})

    # Extract args
    thought = Map.get(args, "thought")
    thought_number = Map.get(args, "thought_number")
    total_thoughts = Map.get(args, "total_thoughts")
    next_thought_needed = Map.get(args, "next_thought_needed")

    # Get or initialize thought history
    thought_history = Map.get(lens_state, :thought_history, [])

    # Reset chain if starting new reasoning (thought_number == 1)
    thought_history = if thought_number == 1 do
      []
    else
      thought_history
    end

    # Add new thought to history
    new_thought = %{
      number: thought_number,
      content: thought,
      total: total_thoughts
    }
    updated_history = thought_history ++ [new_thought]

    # Build result message (brief, thought is in context)
    result = Jason.encode!(%{
      status: "ok",
      thought: thought_number,
      total: total_thoughts,
      continue: next_thought_needed
    })

    # Return result with lens state updates
    {result, [thought_history: updated_history]}
  end

  defp format_thought_chain(thoughts) do
    thoughts
    |> Enum.map(fn %{number: num, content: content, total: total} ->
      "#{num}/#{total}. #{content}"
    end)
    |> Enum.join("\n\n")
  end
end
```

**Key Patterns:**

1. **Context Shows State** - `provide_context/2` displays the current thought chain
2. **Tool Modifies State** - `execute/3` updates `thought_history` via lens_updates
3. **Brief Tool Results** - Result is JSON status, full thoughts shown in context
4. **State Reset Logic** - `thought_number == 1` clears previous chain
5. **Schema Validation** - Clear parameter descriptions and requirements

---

## Complete Example: NotesLens

Let's build a complete tool-providing lens from scratch: a notes system.

**Purpose:** Allow the agent to create, read, update, and delete persistent notes.

**File:** `lib/koalemos/lenses/notes_lens.ex`

```elixir
defmodule Koalemos.Lenses.NotesLens do
  @moduledoc """
  Tool-providing lens for managing persistent notes.

  ## Features
  - Create notes with titles and content
  - List all notes
  - Read specific notes
  - Update existing notes
  - Delete notes

  ## Usage

  lenses: [
    "Koalemos.Lenses.NotesLens"
  ]

  ## State Structure

  lens_state: %{
    notes: %{
      "note-1" => %{id: "note-1", title: "...", content: "...", created_at: DateTime},
      "note-2" => %{...}
    }
  }
  """

  @doc "Provide context showing all notes"
  def provide_context(context, _config) do
    lens_state = Map.get(context, :lens_state, %{})
    notes = Map.get(lens_state, :notes, %{})

    if map_size(notes) == 0 do
      [%{
        type: "text",
        text: """
        ## Notes

        No notes yet. Use the `create_note` tool to create one.
        """
      }]
    else
      notes_list = format_notes_list(notes)

      [%{
        type: "text",
        text: """
        ## Notes (#{map_size(notes)} total)

        #{notes_list}

        Use `read_note` to see full content, or `create_note`/`update_note`/`delete_note` to manage.
        """
      }]
    end
  end

  @doc "List available tools"
  def tools do
    [
      {__MODULE__, :create_note},
      {__MODULE__, :read_note},
      {__MODULE__, :update_note},
      {__MODULE__, :delete_note},
      {__MODULE__, :list_notes}
    ]
  end

  @doc "Get tool schema"
  def info(:create_note) do
    %{
      name: "create_note",
      description: "Create a new note with a title and content",
      input_schema: %{
        type: "object",
        properties: %{
          title: %{
            type: "string",
            description: "Note title (short, descriptive)"
          },
          content: %{
            type: "string",
            description: "Note content (can be long)"
          }
        },
        required: ["title", "content"]
      }
    }
  end

  def info(:read_note) do
    %{
      name: "read_note",
      description: "Read a specific note by ID",
      input_schema: %{
        type: "object",
        properties: %{
          note_id: %{
            type: "string",
            description: "The note ID to read"
          }
        },
        required: ["note_id"]
      }
    }
  end

  def info(:update_note) do
    %{
      name: "update_note",
      description: "Update an existing note's title and/or content",
      input_schema: %{
        type: "object",
        properties: %{
          note_id: %{type: "string", description: "Note ID to update"},
          title: %{type: "string", description: "New title (optional)"},
          content: %{type: "string", description: "New content (optional)"}
        },
        required: ["note_id"]
      }
    }
  end

  def info(:delete_note) do
    %{
      name: "delete_note",
      description: "Delete a note by ID",
      input_schema: %{
        type: "object",
        properties: %{
          note_id: %{type: "string", description: "Note ID to delete"}
        },
        required: ["note_id"]
      }
    }
  end

  def info(:list_notes) do
    %{
      name: "list_notes",
      description: "List all notes (IDs and titles only)",
      input_schema: %{
        type: "object",
        properties: %{}
      }
    }
  end

  @doc "Execute tool"
  def execute(:create_note, args, context) do
    title = Map.get(args, "title")
    content = Map.get(args, "content")

    # Generate unique ID
    note_id = "note-#{:erlang.unique_integer([:positive])}"

    # Create note
    note = %{
      id: note_id,
      title: title,
      content: content,
      created_at: DateTime.utc_now()
    }

    # Get existing notes
    lens_state = Map.get(context, :lens_state, %{})
    notes = Map.get(lens_state, :notes, %{})

    # Add new note
    updated_notes = Map.put(notes, note_id, note)

    # Return result with lens state update
    result = "Created note '#{title}' with ID #{note_id}"
    {result, [notes: updated_notes]}
  end

  def execute(:read_note, args, context) do
    note_id = Map.get(args, "note_id")

    lens_state = Map.get(context, :lens_state, %{})
    notes = Map.get(lens_state, :notes, %{})

    case Map.get(notes, note_id) do
      nil ->
        {"Error: Note #{note_id} not found", []}

      note ->
        result = """
        # #{note.title}

        #{note.content}

        ---
        ID: #{note.id}
        Created: #{Calendar.strftime(note.created_at, "%Y-%m-%d %H:%M:%S")}
        """
        {result, []}
    end
  end

  def execute(:update_note, args, context) do
    note_id = Map.get(args, "note_id")
    new_title = Map.get(args, "title")
    new_content = Map.get(args, "content")

    lens_state = Map.get(context, :lens_state, %{})
    notes = Map.get(lens_state, :notes, %{})

    case Map.get(notes, note_id) do
      nil ->
        {"Error: Note #{note_id} not found", []}

      note ->
        # Update only provided fields
        updated_note =
          note
          |> maybe_update(:title, new_title)
          |> maybe_update(:content, new_content)

        updated_notes = Map.put(notes, note_id, updated_note)

        {"Updated note '#{updated_note.title}'", [notes: updated_notes]}
    end
  end

  def execute(:delete_note, args, context) do
    note_id = Map.get(args, "note_id")

    lens_state = Map.get(context, :lens_state, %{})
    notes = Map.get(lens_state, :notes, %{})

    case Map.get(notes, note_id) do
      nil ->
        {"Error: Note #{note_id} not found", []}

      note ->
        updated_notes = Map.delete(notes, note_id)
        {"Deleted note '#{note.title}'", [notes: updated_notes]}
    end
  end

  def execute(:list_notes, _args, context) do
    lens_state = Map.get(context, :lens_state, %{})
    notes = Map.get(lens_state, :notes, %{})

    if map_size(notes) == 0 do
      {"No notes yet", []}
    else
      list = format_notes_list(notes)
      {list, []}
    end
  end

  # Private helpers

  defp format_notes_list(notes) do
    notes
    |> Map.values()
    |> Enum.sort_by(& &1.created_at, DateTime)
    |> Enum.map(fn note ->
      "- [#{note.id}] #{note.title}"
    end)
    |> Enum.join("\n")
  end

  defp maybe_update(note, _key, nil), do: note
  defp maybe_update(note, key, value), do: Map.put(note, key, value)
end
```

**Test Routine:**

```elixir
defmodule Koalemos.Routines.NotesTestRoutine do
  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{LensRendering, LLMRequest, ResponseParsing, ToolSchema, ToolLookup, ToolExecution}

  def routine_definition do
    %{
      start: %{type: ChatUserInput, transitions: [{:tool_schema, :always}]},
      tool_schema: %{type: ToolSchema, transitions: [{:render_lens, :always}]},
      render_lens: %{type: LensRendering, transitions: [{:llm_request, :always}]},
      llm_request: %{type: LLMRequest, transitions: [{:parse_response, :always}]},
      parse_response: %{type: ResponseParsing, transitions: [
        {:tool_lookup, :when_has_tool_calls},
        {:start, :always}
      ]},
      tool_lookup: %{type: ToolLookup, transitions: [{:tool_execution, :always}]},
      tool_execution: %{type: ToolExecution, transitions: [
        {:tool_schema, :when_more_tools},
        {:start, :always}
      ]}
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
      lenses: ["Koalemos.Lenses.NotesLens"],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5"
    }
  end
end
```

---

## Lens State Management

### What is Lens State?

`lens_state` is a map in `context[:lens_state]` where lenses store their persistent data.

### Key Principles

1. **Lens Isolation** - Each lens uses its own keys (e.g., `notes`, `thought_history`, `wireframe_dom`)
2. **Persistence** - Lens state persists across conversation turns
3. **Updates via Tools** - Tools update lens state by returning lens_updates tuples
4. **Reading from Context** - Both `provide_context/2` and `execute/3` receive `context` containing `lens_state`

### Update Pattern

**In `execute/3`:**

```elixir
def execute(:my_tool, args, context) do
  # Read current lens state
  lens_state = Map.get(context, :lens_state, %{})
  my_data = Map.get(lens_state, :my_key, initial_value)

  # Perform operation
  updated_data = do_something(my_data, args)

  # Return result with lens updates
  {"Operation completed", [my_key: updated_data]}
end
```

**ToolExecution applies updates:**

```elixir
# ToolExecution step automatically merges lens_updates:
updated_lens_state = Enum.reduce(lens_updates, existing_lens_state, fn {key, value}, acc ->
  Map.put(acc, key, value)
end)
```

### Best Practices

1. **Use Descriptive Keys** - `notes`, `wireframe_dom`, not `data` or `state`
2. **Initialize Safely** - Always use `Map.get(lens_state, :key, default)`
3. **Document Structure** - Put lens state structure in module docstring
4. **Avoid Collisions** - If two lenses might use same key, namespace it (e.g., `notes_lens_data`)

---

## Configuration Patterns

### Static Configuration

Passed when lens is specified in `initial_context`:

```elixir
lenses: [
  ["MyLens", %{option1: "value", option2: 42}]
]
```

Received in `provide_context/2` as second parameter:

```elixir
def provide_context(_context, config) do
  option1 = Map.get(config, :option1, "default")
  # ...
end
```

### Runtime Configuration

Can be modified during execution by updating context:

```elixir
# In a step or tool
{:ok, [{:add_or_update, %{
  config: %{
    "MyLens" => %{option1: "new_value"}
  }
}}]}
```

LensRendering merges config sources using `ConfigMerge.merge_lenses/2`.

### Configuration Best Practices

1. **Provide Defaults** - Always have sensible defaults
2. **Validate Early** - Check config in `provide_context/2`, fail fast
3. **Document Options** - List all config options in moduledoc
4. **Use Atoms for Keys** - Consistent with Elixir conventions

---

## Best Practices

### General

1. **Single Responsibility** - One lens, one capability domain
2. **Clear Naming** - Lens name should describe what it does (NotesLens, PersonaLens, WireframeEditor)
3. **Comprehensive Docs** - Moduledoc with usage examples, config options, state structure
4. **Fail Gracefully** - Return error messages, don't raise exceptions
5. **Test Thoroughly** - Unit tests for all tool functions

### Context Provision

1. **Be Concise** - Context adds to token usage, be economical
2. **Structure with Headers** - Use `## Header` for readability
3. **Only Show Relevant Data** - Don't dump entire state
4. **Update Dynamically** - Context should reflect current lens state

### Tool Design

1. **Clear Schemas** - Detailed descriptions for every parameter
2. **Required vs Optional** - Mark parameters appropriately
3. **Validation** - Validate inputs, return helpful error messages
4. **Idempotency** - When possible, tools should be idempotent
5. **Atomic Operations** - Each tool does ONE thing well

### Performance

1. **Avoid Heavy Computation** - `provide_context/2` called before every LLM request
2. **Cache When Possible** - Store computed results in lens state
3. **Lazy Loading** - Don't load data until needed
4. **Monitor State Size** - Large lens states impact memory

---

## Testing Your Lens

### Unit Tests

Test each function independently:

```elixir
defmodule Koalemos.Lenses.NotesLensTest do
  use ExUnit.Case
  alias Koalemos.Lenses.NotesLens

  describe "provide_context/2" do
    test "shows empty state when no notes" do
      context = %{lens_state: %{notes: %{}}}

      [block] = NotesLens.provide_context(context, %{})

      assert block.type == "text"
      assert block.text =~ "No notes yet"
    end

    test "lists notes when present" do
      note = %{id: "note-1", title: "Test", content: "...", created_at: DateTime.utc_now()}
      context = %{lens_state: %{notes: %{"note-1" => note}}}

      [block] = NotesLens.provide_context(context, %{})

      assert block.text =~ "1 total"
      assert block.text =~ "Test"
    end
  end

  describe "execute/3 - create_note" do
    test "creates note and returns result" do
      args = %{"title" => "My Note", "content" => "Content here"}
      context = %{lens_state: %{}}

      {result, lens_updates} = NotesLens.execute(:create_note, args, context)

      assert result =~ "Created note 'My Note'"
      assert Keyword.has_key?(lens_updates, :notes)

      notes = Keyword.get(lens_updates, :notes)
      assert map_size(notes) == 1

      [note] = Map.values(notes)
      assert note.title == "My Note"
      assert note.content == "Content here"
    end
  end

  describe "execute/3 - read_note" do
    test "returns note content when found" do
      note = %{id: "note-1", title: "Test", content: "Content", created_at: DateTime.utc_now()}
      context = %{lens_state: %{notes: %{"note-1" => note}}}
      args = %{"note_id" => "note-1"}

      {result, _lens_updates} = NotesLens.execute(:read_note, args, context)

      assert result =~ "# Test"
      assert result =~ "Content"
    end

    test "returns error when note not found" do
      context = %{lens_state: %{notes: %{}}}
      args = %{"note_id" => "nonexistent"}

      {result, _lens_updates} = NotesLens.execute(:read_note, args, context)

      assert result =~ "Error: Note nonexistent not found"
    end
  end
end
```

### Integration Tests

Test with real routine execution:

```elixir
defmodule Koalemos.Routines.NotesTestRoutineTest do
  use ExUnit.Case
  alias Koalemos.EngineManager

  test "notes lens integration" do
    # Start routine
    {:ok, routine_id} = EngineManager.start_routine(
      NotesTestRoutine,
      %{},
      "notes-test-#{:erlang.unique_integer()}"
    )

    # Send user input (agent will create note)
    Engine.send_external_event(routine_id, :user_input, "Create a note titled 'Test' with content 'Hello'")

    # Wait for processing
    Process.sleep(2000)

    # Get routine state
    %{lens_state: lens_state} = EngineManager.get_routine_state(routine_id)

    # Verify note was created
    notes = Map.get(lens_state, :notes, %{})
    assert map_size(notes) == 1

    [note] = Map.values(notes)
    assert note.title == "Test"
  end
end
```

### Manual Testing

Create a test page (LiveView) for interactive testing:

```elixir
defmodule KoalemosWeb.NotesTestLive do
  use KoalemosWeb, :live_view
  alias Koalemos.EngineManager

  def mount(_params, _session, socket) do
    # Start routine
    {:ok, routine_id} = EngineManager.start_routine(
      Koalemos.Routines.NotesTestRoutine,
      %{},
      "notes-test-#{:erlang.unique_integer()}"
    )

    # Subscribe to routine events
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

    {:ok, assign(socket, routine_id: routine_id, messages: [])}
  end

  # ... rest of LiveView implementation
end
```

---

## Common Patterns

### Pattern: State Machine

Track state transitions within your lens:

```elixir
def execute(:start_process, _args, context) do
  {"Process started", [status: :in_progress, started_at: DateTime.utc_now()]}
end

def execute(:complete_process, _args, context) do
  lens_state = Map.get(context, :lens_state, %{})

  if Map.get(lens_state, :status) == :in_progress do
    {"Process completed", [status: :completed, completed_at: DateTime.utc_now()]}
  else
    {"Error: No process in progress", []}
  end
end
```

### Pattern: Accumulator

Accumulate data over multiple tool calls:

```elixir
def execute(:add_item, args, context) do
  item = Map.get(args, "item")

  lens_state = Map.get(context, :lens_state, %{})
  items = Map.get(lens_state, :items, [])

  updated_items = items ++ [item]

  {"Added '#{item}' (#{length(updated_items)} total)", [items: updated_items]}
end
```

### Pattern: Context with Images

Return images in context blocks:

```elixir
def provide_context(context, _config) do
  lens_state = Map.get(context, :lens_state, %{})
  screenshot = Map.get(lens_state, :last_screenshot)

  if screenshot do
    [
      %{type: "text", text: "## Current State"},
      %{
        type: "image",
        source: %{
          type: "base64",
          media_type: "image/png",
          data: screenshot
        }
      }
    ]
  else
    [%{type: "text", text: "## Current State\n\nNo screenshot available"}]
  end
end
```

### Pattern: Tool Result with Images

Return images in tool results:

```elixir
def execute(:capture_state, _args, context) do
  # Capture screenshot somehow
  screenshot_base64 = do_capture()

  # Return content blocks
  {
    [
      {:text, "Captured state successfully"},
      {:image, screenshot_base64, "image/png"}
    ],
    [last_screenshot: screenshot_base64]
  }
end
```

---

## Troubleshooting

### Tool Not Showing Up

**Symptom:** Agent doesn't have access to your tool.

**Causes:**
1. Lens not in `context[:lenses]`
2. Tool not returned by `tools/0`
3. Tool name mismatch between `info/1` and `execute/3`

**Fix:**
```elixir
# Ensure lens is active
lenses: ["MyLens"]

# Ensure tools/0 returns all tools
def tools do
  [{__MODULE__, :my_tool}]  # Must match execute/3 atom
end

# Ensure name in schema matches
def info(:my_tool) do
  %{name: "my_tool", ...}  # String must match atom
end
```

### Tool Execution Fails

**Symptom:** Tool returns error or crashes.

**Causes:**
1. Missing required parameters
2. Wrong parameter types
3. Lens state not initialized

**Fix:**
```elixir
def execute(:my_tool, args, context) do
  # Validate parameters
  required_param = Map.get(args, "required_param")
  if required_param == nil do
    return {"Error: required_param is missing", []}
  end

  # Initialize lens state safely
  lens_state = Map.get(context, :lens_state, %{})
  my_data = Map.get(lens_state, :my_data, %{})  # Default to empty map

  # ... rest of logic
end
```

### Context Not Updating

**Symptom:** `provide_context/2` shows stale data.

**Causes:**
1. Lens updates not returned from `execute/3`
2. Lens updates using wrong key
3. Not reading from `context[:lens_state]`

**Fix:**
```elixir
# In execute/3, return lens updates
{"Result", [my_key: updated_value]}

# In provide_context/2, read from lens_state
def provide_context(context, _config) do
  lens_state = Map.get(context, :lens_state, %{})
  my_data = Map.get(lens_state, :my_key, default)
  # ... build context from my_data
end
```

### Tool Schema Validation Fails

**Symptom:** LLM can't call tool due to schema errors.

**Causes:**
1. Invalid JSON Schema syntax
2. Missing required fields
3. Type mismatches

**Fix:**
```elixir
def info(:my_tool) do
  %{
    name: "my_tool",
    description: "Clear description",
    input_schema: %{
      type: "object",        # Required
      properties: %{         # Required
        param1: %{
          type: "string",    # Valid JSON Schema type
          description: "..." # Always include descriptions
        }
      },
      required: ["param1"]   # List of required param names (strings)
    }
  }
end
```

### Performance Issues

**Symptom:** Routine runs slowly.

**Causes:**
1. Heavy computation in `provide_context/2`
2. Large lens state
3. Too many context blocks

**Fix:**
```elixir
# Cache computed results
def provide_context(context, _config) do
  lens_state = Map.get(context, :lens_state, %{})

  # Check if cached result is fresh
  cached_context = Map.get(lens_state, :cached_context)
  last_update = Map.get(lens_state, :last_update)

  if cached_context && recent?(last_update) do
    cached_context
  else
    # Recompute and cache
    context_blocks = compute_context(lens_state)
    # Note: Can't update lens_state from provide_context, only from execute
    context_blocks
  end
end

# Keep lens state lean
def execute(:cleanup, _args, context) do
  lens_state = Map.get(context, :lens_state, %{})

  # Remove old/unused data
  pruned_data = prune_old_entries(lens_state)

  {"Cleaned up old data", [my_data: pruned_data]}
end
```

---

## Advanced Topics

### Multi-Lens Coordination

**Challenge:** Two lenses need to share data.

**Solutions:**

1. **Shared Context Keys** (simple but couples lenses):
```elixir
# Lens A writes
{"Done", [shared_data: value]}

# Lens B reads
lens_state = Map.get(context, :lens_state, %{})
shared_data = Map.get(lens_state, :shared_data)
```

2. **PubSub Events** (decoupled, more complex):
```elixir
# Lens A publishes
def execute(:my_tool, args, context) do
  routine_id = Map.get(context, :routine_id)
  Phoenix.PubSub.broadcast(Koalemos.PubSub, "lens:#{routine_id}", {:lens_event, :data_updated, value})
  {"Done", []}
end

# Lens B subscribes (in routine setup)
Phoenix.PubSub.subscribe(Koalemos.PubSub, "lens:#{routine_id}")
```

3. **Lens Composition** (cleanest, requires design):
Create a parent lens that delegates to child lenses.

### Async Operations

**Challenge:** Tool needs to wait for external process.

**Solutions:**

1. **Blocking (simplest)**:
```elixir
def execute(:fetch_data, args, context) do
  # Just wait
  result = HTTPoison.get!(url)
  {"Fetched data", [data: result.body]}
end
```

2. **PubSub Coordination (better UX)**:
```elixir
def execute(:start_fetch, args, context) do
  routine_id = Map.get(context, :routine_id)

  # Start async task
  Task.start(fn ->
    result = HTTPoison.get!(url)
    # Send event when done
    Engine.send_external_event(routine_id, :fetch_complete, result.body)
  end)

  {"Fetch started, will notify when complete", [fetch_status: :in_progress]}
end

# Routine handles event
external_events: [
  {:fetch_complete, fn context, data ->
    {context, lens_updates: [fetch_status: :complete, data: data]}
  end}
]
```

---

## Summary

**You now know:**
- What lenses are and when to use them
- How to create context-only lenses (PersonaLens pattern)
- How to create tool-providing lenses (SequentialThinking, NotesLens patterns)
- How to manage lens state across turns
- Best practices for lens design
- How to test your lenses
- Common patterns and troubleshooting

**Next steps:**
1. Read `docs/guides/ROUTINE_DEVELOPMENT.md` to learn how to use your lens in routines
2. Study existing lenses in `lib/koalemos/lenses/`
3. Build your own lens for your use case
4. Share patterns and improvements with the community

**Questions?** Check docs/ARCHITECTURE.md for deeper technical details, or study the source code of existing lenses.
