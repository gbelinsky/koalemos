defmodule Koalemos.Routines.WireframeTestRoutine do
  @moduledoc """
  Test routine for wireframe editor testing (M4 Sprint 1).

  This routine provides a foundation for testing the WireframeEditor lens
  that will be built in later sprints. For now, it supports:
  - Loading sample HTML files
  - Basic HTML viewing and inspection
  - Future: DOM manipulation, JavaScript handling, CSS modifications

  Loop: ChatUserInput → LensRendering → LLMRequest → ResponseParsing → loop back

  ## Future Evolution (Sprints 4-8)

  This routine will be extended to support:

  1. **Tool Execution**: WireframeEditor lens will provide tools (query_element,
     add_element, modify_styles, etc.) that need to be executed as part of the loop.

  2. **Agent-as-Node Pattern**: Similar to flo's TemplatedSemanticAgent, we may add
     a sub-routine step that manages a tool chain through an agent, allowing the
     WireframeEditor to orchestrate complex multi-step operations (e.g., "add a
     contact form" → query structure → generate HTML → insert element → apply styles).

  3. **Wireframe State Management**: Context will track parsed wireframe structure
     and modifications, enabling undo/redo and validation workflows.

  The basic loop will remain, but may include a ToolExecution step after LLMRequest
  and before ResponseParsing, or a TemplatedAgent sub-routine node for complex operations.

  The routine:
  1. Waits for user input
  2. Renders context from active lenses
  3. Makes an LLM request
  4. Parses the response
  5. Loops back to wait for more user input

  Initial context should include:
  - llm_provider (default: "anthropic")
  - llm_model (default: "claude-haiku-4-5")
  - max_tokens (default: 2000)
  - temperature (default: 0.7)
  - wireframe_html (optional: HTML content to work with)
  - wireframe_sample (optional: "simple", "medium", or "complex")
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{LensRendering, LLMRequest, ResponseParsing}

  @fixtures_path "test/fixtures"
  @sample_files %{
    "simple" => "wireframe_simple.html",
    "medium" => "wireframe_medium.html",
    "complex" => "wireframe_complex.html"
  }

  @doc """
  Returns the routine definition for the wireframe test workflow.
  """
  def routine_definition do
    %{
      # Start by waiting for user input
      start: %{
        type: ChatUserInput,
        transitions: [{:render_lens, :always}]
      },

      # Get context from lenses (will include WireframeEditor lens in future sprints)
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Make LLM request with messages and lens context
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Parse LLM response and add to messages
      parse_response: %{
        type: ResponseParsing,
        transitions: [{:start, :always}]
      }
    }
  end

  @doc """
  Simple condition that always returns true.
  """
  def check_condition(:always, _context), do: true

  @doc """
  Returns default initial context for the routine.
  Engine will auto-call this and merge with user-provided context.

  User can provide in their context:
  - wireframe_sample: Load a sample HTML file ("simple", "medium", "complex")
  - wireframe_html: Directly provide HTML content
  - lenses: List of lens module names (default: none yet, will add WireframeEditor in Sprint 4)
  """
  def initial_context do
    %{
      messages: [],
      lenses: [],  # Will add WireframeEditor lens in Sprint 4+
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5",
      max_tokens: 2000,
      temperature: 0.7,
      wireframe_html: nil,
      wireframe_sample: nil
    }
  end

  @doc """
  Setup function called by Engine after context is merged.
  Loads sample HTML if wireframe_sample is specified.
  """
  def setup(_routine_config, state) do
    # Load sample HTML if specified in context
    updated_context = maybe_load_sample(state.context)

    %{state | context: updated_context}
  end

  # Private Helpers

  defp maybe_load_sample(%{wireframe_sample: sample} = context) when is_binary(sample) do
    case load_sample_html(sample) do
      {:ok, html} ->
        Map.put(context, :wireframe_html, html)

      {:error, reason} ->
        # Log error but don't fail - just leave wireframe_html as nil
        require Logger
        Logger.warning("[WireframeTestRoutine] Failed to load sample '#{sample}': #{reason}")
        context
    end
  end

  defp maybe_load_sample(context), do: context

  defp load_sample_html(sample_id) do
    case Map.get(@sample_files, sample_id) do
      nil ->
        {:error, "Unknown sample: #{sample_id}. Available: #{Map.keys(@sample_files) |> Enum.join(", ")}"}

      filename ->
        path = Path.join([@fixtures_path, filename])

        case File.read(path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
        end
    end
  end
end
