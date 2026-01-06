defmodule Koalemos.Steps.Agent.TemplatedSemanticAgent do
  @moduledoc """
  Reusable semantic agent step with EEx templating and lens configuration.

  This step acts as a complete sub-routine containing a full agent loop.
  It combines EEx templating with configurable lenses to create specialized
  agent behaviors without duplicating the agent loop structure.

  ## Configuration

  - `template`: EEx template string with `@context` access for dynamic prompt building
  - `lenses`: List of lens configs to provide context and tools
  - `system_prompt_additions`: Optional extra system context (string)

  ## Example Usage

  ```elixir
  routing: %{
    type: TemplatedSemanticAgent,
    config: %{
      template: '''
      Analyze the user's request and route to the appropriate sub-routine.

      User request: <%= List.last(@context[:messages])[:content] %>
      Current wireframe: <%= if @context[:has_wireframe], do: "exists", else: "empty" %>

      Choose the best sub-routine for this request.
      ''',
      lenses: ["Koalemos.Lenses.SemanticTransition"]
    },
    transitions: [
      {:answer_directly, "Answer questions without making changes"},
      {:targeted_change, "Make a specific focused modification"},
      {:build_from_scratch, "Create new wireframe from scratch"}
    ]
  }
  ```

  ## How It Works

  1. **Setup phase:** Renders the EEx template with full context access
  2. **Agent loop:** Executes lens_rendering → llm → parse → tool_execution → loop
  3. **Transition:** When agent uses workflow_transition tool, pops back to parent routine

  ## Workflow Transitions

  This step is designed to work with the SemanticTransition lens pattern:
  - Lenses can return `workflow_transition: {target_step, reason}` in lens_state
  - Engine automatically pops the execution stack and applies transition at parent level
  - See Orchestrator.handle_step_success (lines 219-251) for implementation details
  """

  alias Koalemos.Steps.Agent.{
    ToolSchema,
    LensRendering,
    LLMRequest,
    ResponseParsing,
    ToolLookup,
    ToolExecution
  }

  @doc """
  Returns the routine definition for the internal agent loop.

  This sub-routine executes the complete agent loop:
  1. build_tool_schema - Build tool descriptions from active lenses
  2. render_lens - Query lenses for context blocks
  3. llm_request - Make LLM API call with messages, tools, and context
  4. parse_response - Parse response and extract tool calls
  5. tool_lookup - Resolve tool calls to executable format (if tools present)
  6. tool_execution - Execute tools one at a time (if tools present)
  7. Loop back to build_tool_schema or exit
  """
  def routine_definition do
    %{
      # Build tool schema from active lenses (runs each iteration before LLM)
      start: %{
        type: ToolSchema,
        transitions: [{:render_lens, :always}]
      },

      # Query active lenses for their current context blocks
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Make LLM API call with messages, tools, and lens contexts
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Parse LLM response to extract tool calls and assistant message
      parse_response: %{
        type: ResponseParsing,
        transitions: [
          {:tool_lookup, :when_has_tool_calls},
          {:end, :when_no_tool_calls}
        ]
      },

      # Resolve tool calls to executable format using tool_map
      tool_lookup: %{
        type: ToolLookup,
        transitions: [{:tool_execution, :always}]
      },

      # Execute tools one at a time, update lens state, add result to messages
      tool_execution: %{
        type: ToolExecution,
        transitions: [
          {:tool_execution, :when_has_more_tools},
          {:start, :when_tools_complete}
        ]
      }
    }
  end

  @doc """
  Check condition functions for internal transitions.
  """
  def check_condition(:always, _context), do: true

  def check_condition(:when_has_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls) || []
    length(tool_calls) > 0
  end

  def check_condition(:when_no_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls) || []
    length(tool_calls) == 0
  end

  def check_condition(:when_has_more_tools, context) do
    to_execute = Map.get(context, :to_execute) || []
    length(to_execute) > 0
  end

  def check_condition(:when_tools_complete, context) do
    to_execute = Map.get(context, :to_execute) || []
    length(to_execute) == 0
  end

  @doc """
  Setup function that processes template and configures the semantic loop.

  This is called by the Engine before entering the sub-routine.
  It renders the EEx template with the current context and adds it as
  a system message to guide the agent's behavior.

  **Lens Merging:** Config lenses are merged with inherited context lenses.
  Config lenses override inherited lenses for the same module (by name),
  and new lenses are added. This allows step config to:
  - Override a parent lens with different config (e.g., readonly mode)
  - Add new lenses (e.g., SemanticTransition)
  - Keep other inherited lenses unchanged

  ## Parameters

  - `config_sources` - Map with :static and :runtime config
  - `state` - Current engine state with context

  ## Returns

  `{:ok, diff}` where diff is a list of context changes
  """
  def setup(config_sources, state) do
    # Merge static and runtime config
    static_config = Map.get(config_sources, :static, %{})
    runtime_config = Map.get(config_sources, :runtime, %{})
    config = Map.merge(static_config, runtime_config)

    # Build the context diff
    diff = []

    # 1. Merge config lenses with base routine lenses
    # First entry in a routine saves the base lenses, subsequent entries use them
    diff =
      case Map.get(config, :lenses) do
        nil ->
          # No config lenses means restore to base (if we saved them) or keep current
          case Map.get(state.context, :_routine_base_lenses) do
            nil ->
              # First sub-routine in this routine - save current as base
              base_lenses = state.context[:lenses] || []
              [{:add_or_update, %{_routine_base_lenses: base_lenses}} | diff]

            saved_base ->
              # Restore to saved base lenses
              [{:add_or_update, %{lenses: saved_base}} | diff]
          end

        [] ->
          # Same as nil - restore to base
          case Map.get(state.context, :_routine_base_lenses) do
            nil ->
              base_lenses = state.context[:lenses] || []
              [{:add_or_update, %{_routine_base_lenses: base_lenses}} | diff]

            saved_base ->
              [{:add_or_update, %{lenses: saved_base}} | diff]
          end

        config_lenses when is_list(config_lenses) ->
          # Get base lenses - either saved or current (and save if not saved yet)
          {base_lenses, save_base_diff} =
            case Map.get(state.context, :_routine_base_lenses) do
              nil ->
                base = state.context[:lenses] || []
                {base, [{:add_or_update, %{_routine_base_lenses: base}}]}

              saved_base ->
                {saved_base, []}
            end

          merged_lenses = Koalemos.ConfigMerge.merge_lenses(base_lenses, config_lenses)
          save_base_diff ++ [{:add_or_update, %{lenses: merged_lenses}} | diff]
      end

    # 2. Add step system prompt if template present
    # NOTE: step_system_prompt persists in context until overwritten by next step with template
    # TODO (post-release): Clear step_system_prompt when agent loop completes
    diff =
      case Map.get(config, :template) do
        nil ->
          diff

        template ->
          # Render the template with current context
          rendered_action = render_eex_template(template, state.context)

          # Store as step_system_prompt - included in system content by LLM provider
          [{:add_or_update, %{step_system_prompt: rendered_action}} | diff]
      end

    {:ok, Enum.reverse(diff)}
  end

  # Render EEx template with full context access
  defp render_eex_template(template, context) do
    # Use EEx with assigns pattern for full context access
    assigns = %{context: context}

    # Render using EEx with assigns binding
    EEx.eval_string(template, assigns: assigns)
  rescue
    error ->
      "Template rendering failed: #{Exception.message(error)}"
  end

end
