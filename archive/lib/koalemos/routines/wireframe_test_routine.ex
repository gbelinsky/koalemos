defmodule Koalemos.Routines.WireframeTestRoutine do
  @moduledoc """
  Test routine for wireframe editor testing (M4 Sprint 4).

  Full agent loop with tool execution for WireframeEditor lens.
  Agent can use 9 wireframe editing tools to modify wireframes.

  Loop: ChatUserInput → ToolSchema → LensRendering → LLMRequest → ResponseParsing
    → (if tools) ToolLookup → ToolExecution → (back to ToolSchema for next iteration)
    → (if no tools) back to start for next user message

  ## Features

  - Load sample wireframes (simple, medium, complex)
  - Full WireframeEditor lens integration
  - Tool execution infrastructure
  - Designed vs running state tracking
  - Console output monitoring

  ## Available Tools (9 total)

  Structure tools:
  - modify_classes, modify_elements, manage_attributes

  Behavior tools:
  - manage_handlers, manage_functions, manage_variables, manage_css, manage_init_scripts

  Testing tool:
  - trigger_interaction (ephemeral - for testing only)

  Initial context should include:
  - wireframe_sample: "simple", "medium", or "complex" (loads sample HTML)
  - wireframe_html: Direct HTML content (overrides sample)
  - llm_provider, llm_model, max_tokens, temperature
  """

  alias Koalemos.Steps.User.ChatUserInput

  alias Koalemos.Steps.Agent.{
    ToolSchema,
    LensRendering,
    LLMRequest,
    ResponseParsing,
    ToolLookup,
    ToolExecution
  }

  alias Koalemos.Integrations.ParsingIntegration

  @sample_files %{
    "simple" => "wireframe_simple.html",
    "medium" => "wireframe_medium.html",
    "complex" => "wireframe_complex.html"
  }

  @doc """
  Returns the routine definition with tool execution infrastructure.

  Full agent loop:
  start (ChatUserInput) → build_tool_schema → render_lens → llm_request → parse_response
    → (if tools) tool_lookup → tool_execution → (back to build_tool_schema)
    → (if no tools) back to start for next user input
  """
  def routine_definition do
    %{
      # Wait for user input (main loop entry point)
      start: %{
        type: ChatUserInput,
        transitions: [{:build_tool_schema, :always}]
      },

      # Build tool schema (runs each time before LLM request)
      build_tool_schema: %{
        type: ToolSchema,
        transitions: [{:render_lens, :always}]
      },

      # Get context from WireframeEditor lens
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Make LLM request with messages, tools, and lens context
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Parse LLM response and add to messages
      parse_response: %{
        type: ResponseParsing,
        transitions: [
          {:tool_lookup, :when_has_tool_calls},
          {:start, :when_no_tool_calls}
        ]
      },

      # Resolve tool calls to executable format
      tool_lookup: %{
        type: ToolLookup,
        transitions: [{:tool_execution, :always}]
      },

      # Execute tools one at a time
      tool_execution: %{
        type: ToolExecution,
        transitions: [
          {:tool_execution, :when_has_more_tools},
          {:build_tool_schema, :when_tools_complete}
        ]
      }
    }
  end

  @doc """
  Condition check functions for routine transitions.
  """
  def check_condition(:always, _context), do: true

  def check_condition(:when_has_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls, [])
    length(tool_calls) > 0
  end

  def check_condition(:when_no_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls, [])
    length(tool_calls) == 0
  end

  def check_condition(:when_has_more_tools, context) do
    remaining = Map.get(context, :to_execute, [])
    length(remaining) > 0
  end

  def check_condition(:when_tools_complete, context) do
    remaining = Map.get(context, :to_execute, [])
    length(remaining) == 0
  end

  @doc """
  Returns default initial context for the routine.
  Engine will auto-call this and merge with user-provided context.

  User can provide in their context:
  - wireframe_sample: Load a sample HTML file ("simple", "medium", "complex")
  - wireframe_html: Directly provide HTML content
  """
  def initial_context do
    %{
      messages: [],
      # WireframeEditor lens
      lenses: ["Koalemos.Lenses.WireframeEditor"],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5",
      # Higher token limit for wireframe context
      max_tokens: 64000,
      temperature: 0.7,
      wireframe_html: nil,
      wireframe_sample: nil
    }
  end

  @doc """
  Setup function called by Engine after context is merged.
  Loads sample HTML if wireframe_sample is specified.
  Parses HTML and initializes lens_state.

  Returns {:ok, diff} where diff is a keyword list of context field changes.
  """
  def setup(_routine_config, state) do
    # Load sample HTML if specified in context
    updated_context =
      state.context
      |> maybe_load_sample()
      |> parse_and_initialize_lens_state()

    # Calculate diff - only return fields that changed
    changes =
      Enum.reduce(updated_context, %{}, fn {key, value}, acc ->
        if Map.get(state.context, key) != value do
          Map.put(acc, key, value)
        else
          acc
        end
      end)

    # Return in ContextManager format: {:add_or_update, map()}
    if map_size(changes) > 0 do
      {:ok, [{:add_or_update, changes}]}
    else
      {:ok, []}
    end
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
        {:error,
         "Unknown sample: #{sample_id}. Available: #{Map.keys(@sample_files) |> Enum.join(", ")}"}

      filename ->
        fixtures_path = Path.join([:code.priv_dir(:koalemos), "wireframes"])
        path = Path.join([fixtures_path, filename])

        case File.read(path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
        end
    end
  end

  defp parse_and_initialize_lens_state(%{wireframe_html: html} = context) when is_binary(html) do
    require Logger

    # Generate a routine ID for cache storage (used by ParsingIntegration)
    routine_id =
      Map.get(context, :routine_id, "wireframe-test-#{:erlang.unique_integer([:positive])}")

    case ParsingIntegration.parse_wireframe(html, routine_id) do
      {:ok, wireframe} ->
        # Initialize lens_state with designed version from parsed wireframe
        # ParsingIntegration extracts JavaScript and CSS automatically
        lens_state = %{
          designed: %{
            dom_tree: wireframe.dom_tree,
            style_elements: wireframe.styles,
            script_elements: wireframe.scripts,
            custom_css: wireframe.css_rules,
            custom_functions: Map.get(wireframe.javascript, :functions, %{}),
            custom_variables: Map.get(wireframe.javascript, :variables, %{}),
            init_scripts: extract_init_scripts_as_map(wireframe.javascript.init_scripts),
            handlers: Map.get(wireframe.javascript, :handlers, %{}),
            metadata: wireframe.metadata
          },
          running: %{},
          modifications: []
        }

        context
        |> Map.put(:lens_state, lens_state)
        |> Map.put(:routine_id, routine_id)

      {:error, reason} ->
        Logger.warning("[WireframeTestRoutine] Failed to parse HTML: #{reason}")
        context
    end
  end

  defp parse_and_initialize_lens_state(context), do: context

  # Convert init scripts list to map with index keys
  defp extract_init_scripts_as_map(init_scripts) when is_list(init_scripts) do
    init_scripts
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {script, idx}, acc ->
      if script != "" do
        Map.put(acc, "init_#{idx}", script)
      else
        acc
      end
    end)
  end
end
