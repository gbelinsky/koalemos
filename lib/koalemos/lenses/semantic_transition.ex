defmodule Koalemos.Lenses.SemanticTransition do
  @moduledoc """
  Lens for semantic workflow transitions.

  Enables agents to choose their own path by providing a dynamic transition tool
  based on the parent routine's available transitions.

  ## How It Works

  1. **Reads execution stack** to find parent routine and current step
  2. **Extracts parent transitions** from routine definition
  3. **Detects semantic transitions** (string conditions)
  4. **Dynamically generates tool schema** with transition names as enum
  5. **Provides formatted context** showing each option with description
  6. **Returns workflow_transition** in lens_state for Engine to handle

  ## Semantic Transitions

  String conditions serve dual purpose as condition marker and description:

  ```elixir
  routing: %{
    type: TemplatedSemanticAgent,
    transitions: [
      {:answer_directly, "Answer questions without making changes"},
      {:targeted_change, "Make a specific focused modification"},
      {:build_from_scratch, "Create new wireframe from scratch"}
    ]
  }
  ```

  ## Stack Navigation

  When agent is executing inside a TemplatedSemanticAgent sub-routine:
  ```
  ParentRoutine
    └─ routing (TemplatedSemanticAgent)  ← Parent on stack
         └─ llm_request (current)        ← Agent is here
  ```

  This lens shows the **parent's transitions**, not the current node's transitions.

  ## Engine Integration

  Uses existing workflow_transition mechanism (Orchestrator lines 219-251):
  1. Lens returns `workflow_transition: {target_step, reason}` in lens_state
  2. Engine finds ancestor routine with that transition
  3. Pops execution stack until reaching target routine
  4. Applies transition at correct level

  ## Example Usage

  ```elixir
  # In routine definition
  routing: %{
    type: TemplatedSemanticAgent,
    config: %{
      template: "Analyze the request and choose the best sub-routine.",
      lenses: ["Koalemos.Lenses.SemanticTransition"]
    },
    transitions: [
      {:answer_directly, "Answer questions without making changes"},
      {:make_change, "Modify the wireframe"}
    ]
  }
  ```

  The agent will see:
  - Context explaining available transitions
  - Tool to choose transition with reason
  - Engine will handle the stack popping and transition application
  """

  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  @doc """
  Provides context showing available semantic transitions.

  Reads parent routine definition from execution stack and formats
  available transitions for agent to understand.
  """
  def provide_context(state, _config \\ %{}) do
    case get_parent_transitions(state) do
      {:ok, transitions} ->
        format_transitions_context(transitions)

      {:error, reason} ->
        Log.debug(:engine, "[SemanticTransition] Failed to get parent transitions: #{reason}")
        []
    end
  end

  @doc """
  Provide tool definitions for this lens.

  Returns list of {module, tool_atom} tuples for ToolSchema step.

  Config parameter is accepted for consistency with other lenses but not used.
  Semantic transitions are always available when needed.
  """
  def tools(_config \\ %{}) do
    [{__MODULE__, :choose_transition}]
  end

  @doc """
  Provides transition tool schema dynamically generated from parent transitions.

  Tool schema enum is built from actual transition names available,
  making this lens fully dynamic and reusable.
  """
  def info(:choose_transition, context) do
    # Extract state from context if available
    state = %{
      execution_stack: Map.get(context, :execution_stack, []),
      routine_definitions: Map.get(context, :routine_definitions, %{})
    }

    case get_parent_transitions(state) do
      {:ok, transitions} ->
        build_transition_tool_info(transitions)

      {:error, reason} ->
        Log.debug(:engine, "[SemanticTransition] Failed to build tool schema: #{reason}")
        # Return minimal schema as fallback
        %{
          name: "choose_transition",
          description: "Choose workflow transition (unavailable - no parent transitions)",
          input_schema: %{
            type: "object",
            properties: %{
              transition: %{type: "string"},
              reason: %{type: "string"}
            },
            required: ["transition", "reason"]
          }
        }
    end
  end

  @doc """
  Executes the transition choice tool.

  Returns workflow_transition in lens_state for Engine to process.
  Engine will pop the stack and apply transition at parent level.
  """
  def execute(:choose_transition, %{"transition" => choice, "reason" => reason}, _context) do
    # Use to_existing_atom since transitions are predefined in routines
    case safe_to_atom(choice) do
      {:ok, transition_atom} ->
        Log.info(:engine, "[SemanticTransition] Transition chosen: #{choice} (#{reason})")
        result_message = "Transitioning to: #{choice}"
        {result_message, [workflow_transition: {transition_atom, reason}]}

      {:error, _} ->
        Log.warning(:engine, "[SemanticTransition] Invalid transition: #{choice}")
        {"Invalid transition: #{choice}. Please choose from the available options.", []}
    end
  end

  defp safe_to_atom(string) when is_binary(string) do
    {:ok, String.to_existing_atom(string)}
  rescue
    ArgumentError -> {:error, :not_found}
  end

  defp safe_to_atom(atom) when is_atom(atom), do: {:ok, atom}

  # Private Helpers

  # Get parent routine transitions from execution stack
  defp get_parent_transitions(state) do
    execution_stack = Map.get(state, :execution_stack, [])
    routine_definitions = Map.get(state, :routine_definitions, %{})

    case execution_stack do
      [] ->
        {:error, "No parent routine (empty execution stack)"}

      [%{module: parent_module, step: parent_step} | _] ->
        case Map.get(routine_definitions, parent_module) do
          nil ->
            {:error, "Parent routine definition not found: #{inspect(parent_module)}"}

          parent_definition ->
            case Map.get(parent_definition, parent_step) do
              nil ->
                {:error, "Parent step not found: #{inspect(parent_step)}"}

              parent_step_config ->
                transitions = Map.get(parent_step_config, :transitions, [])

                # Filter to only semantic transitions (string conditions)
                semantic_transitions =
                  Enum.filter(transitions, fn
                    {_target, condition} when is_binary(condition) -> true
                    _ -> false
                  end)

                if Enum.empty?(semantic_transitions) do
                  {:error, "No semantic transitions found in parent step"}
                else
                  {:ok, semantic_transitions}
                end
            end
        end
    end
  end

  # Format transitions as context for the agent
  defp format_transitions_context(transitions) do
    formatted_list =
      transitions
      |> Enum.map(fn {target, description} ->
        "  • **#{target}** → #{description}"
      end)
      |> Enum.join("\n")

    [
      %{
        type: "text",
        text: """
        ## Available Transitions

        Choose the most appropriate transition for the current situation:

        #{formatted_list}

        Use the `choose_transition` tool to make your selection.
        """
      }
    ]
  end

  # Build dynamic tool info schema from transitions
  defp build_transition_tool_info(transitions) do
    transition_names =
      Enum.map(transitions, fn {target, _desc} ->
        Atom.to_string(target)
      end)

    %{
      name: "choose_transition",
      description: "Choose which workflow transition to take based on the current situation",
      input_schema: %{
        type: "object",
        properties: %{
          transition: %{
            type: "string",
            enum: transition_names,
            description: "Which transition path to take"
          },
          reason: %{
            type: "string",
            description: "Brief explanation of why this transition is appropriate"
          }
        },
        required: ["transition", "reason"]
      }
    }
  end
end
