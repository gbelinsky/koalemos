defmodule Koalemos.Steps.Agent.StructuredResponseAgent do
  @moduledoc """
  Multi-turn agent step that collects structured output.

  This step runs an agent loop that allows the agent to use various tools
  to gather information, then call a `respond` tool when ready to provide
  structured output. The loop exits automatically when the respond tool
  is called.

  ## Config

  - `template` - EEx template for the prompt (with `@context` access)
  - `output_key` - Context key to store result (default: `:structured_output`)
  - `schema` - Schema definition for the respond tool
  - `tool_name` - Override respond tool name (default: "respond")
  - `lenses` - Additional lenses for gathering info

  ## Schema Format

  See `Koalemos.Lenses.StructuredResponse` for schema format documentation.

  ## Example

      analyze: %{
        type: StructuredResponseAgent,
        config: %{
          template: \"\"\"
          Analyze the code in the current directory and provide a structured summary.
          Use the file navigation tools to explore, then call respond when ready.
          \"\"\",
          output_key: :analysis,
          schema: %{
            summary: %{type: :string, description: "Brief project summary"},
            language: %{type: :string, description: "Primary programming language"},
            complexity: %{type: :enum, values: ["low", "medium", "high"]}
          },
          lenses: ["Koalemos.Lenses.FileNavigationLens"]
        },
        transitions: [{:next_step, :always}]
      }

  After execution, `context[:analysis]` contains the structured result.

  ## How It Works

  1. **Setup**: Adds StructuredResponse lens with schema, renders template
  2. **Agent loop**: Standard tool_schema → lens_rendering → llm → parse → execute cycle
  3. **Exit detection**: After tool execution, checks if `structured_response` is in lens_state
  4. **Capture**: Extracts response from lens_state and stores in context under output_key
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
  Returns the routine definition for the structured response agent loop.
  """
  def routine_definition do
    %{
      # Build tool schema from active lenses
      start: %{
        type: ToolSchema,
        transitions: [{:render_lens, :always}]
      },

      # Query active lenses for context blocks
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Make LLM API call
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Parse LLM response
      parse_response: %{
        type: ResponseParsing,
        transitions: [
          {:tool_lookup, :when_has_tool_calls},
          {:capture_result, :when_no_tool_calls}
        ]
      },

      # Resolve tool calls
      tool_lookup: %{
        type: ToolLookup,
        transitions: [{:tool_execution, :always}]
      },

      # Execute tools one at a time
      tool_execution: %{
        type: ToolExecution,
        transitions: [
          {:tool_execution, :when_has_more_tools},
          {:check_response, :when_tools_complete}
        ]
      },

      # Check if respond was called - if so, capture and exit
      check_response: %{
        type: __MODULE__.CheckResponse,
        transitions: [
          {:capture_result, :when_has_response},
          {:start, :when_no_response}
        ]
      },

      # Capture structured response from lens_state to context
      capture_result: %{
        type: __MODULE__.CaptureResult,
        transitions: [{:end, :always}]
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

  def check_condition(:when_has_response, context) do
    lens_state = Map.get(context, :lens_state) || %{}
    Map.has_key?(lens_state, :structured_response)
  end

  def check_condition(:when_no_response, context) do
    not check_condition(:when_has_response, context)
  end

  @doc """
  Setup function that configures the structured response loop.

  Adds the StructuredResponse lens with schema config, stores output_key,
  and renders the template as step_system_prompt.
  """
  def setup(config_sources, state) do
    static = Map.get(config_sources, :static, %{})
    runtime = Map.get(config_sources, :runtime, %{})
    config = Map.merge(static, runtime)

    diff = []

    # 1. Add StructuredResponse lens with schema config
    schema = Map.get(config, :schema, %{})
    tool_name = Map.get(config, :tool_name, "respond")
    tool_description = Map.get(config, :tool_description)

    structured_lens_config = %{schema: schema, tool_name: tool_name}

    structured_lens_config =
      if tool_description do
        Map.put(structured_lens_config, :tool_description, tool_description)
      else
        structured_lens_config
      end

    structured_lens = ["Koalemos.Lenses.StructuredResponse", structured_lens_config]

    # Merge with other configured lenses
    config_lenses = Map.get(config, :lenses, [])
    all_lenses = [structured_lens | config_lenses]

    # Get or save base lenses (same pattern as TemplatedSemanticAgent)
    {base_lenses, save_base_diff} =
      case Map.get(state.context, :_routine_base_lenses) do
        nil ->
          base = state.context[:lenses] || []
          {base, [{:add_or_update, %{_routine_base_lenses: base}}]}

        saved_base ->
          {saved_base, []}
      end

    merged = Koalemos.ConfigMerge.merge_lenses(base_lenses, all_lenses)
    diff = save_base_diff ++ [{:add_or_update, %{lenses: merged}} | diff]

    # 2. Store output_key for CaptureResult step
    output_key = Map.get(config, :output_key, :structured_output)
    diff = [{:add_or_update, %{_structured_output_key: output_key}} | diff]

    # 3. Render template as step_system_prompt
    diff =
      case Map.get(config, :template) do
        nil ->
          diff

        template ->
          rendered = render_eex_template(template, state.context)
          [{:add_or_update, %{step_system_prompt: rendered}} | diff]
      end

    {:ok, Enum.reverse(diff)}
  end

  # Render EEx template with full context access
  defp render_eex_template(template, context) do
    assigns = %{context: context}
    EEx.eval_string(template, assigns: assigns)
  rescue
    error ->
      "Template rendering failed: #{Exception.message(error)}"
  end
end

# Step that just checks for structured response (no-op, transitions do the work)
defmodule Koalemos.Steps.Agent.StructuredResponseAgent.CheckResponse do
  @moduledoc false

  def execute(_config, _state) do
    {:ok, []}
  end
end

# Step that captures structured response from lens_state to context
defmodule Koalemos.Steps.Agent.StructuredResponseAgent.CaptureResult do
  @moduledoc false

  def execute(_config, state) do
    lens_state = state.context[:lens_state] || %{}
    output_key = state.context[:_structured_output_key] || :structured_output

    case Map.get(lens_state, :structured_response) do
      nil ->
        # No response captured - this is fine for text-only responses
        {:ok, []}

      result ->
        # Store result under output_key and clean up temporary keys
        {:ok,
         [
           add_or_update: %{output_key => result},
           remove: [:_structured_output_key]
         ]}
    end
  end
end
