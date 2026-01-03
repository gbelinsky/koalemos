defmodule WireframeEditorWeb.Routines.WireframeDesignRoutine do
  @moduledoc """
  V4 Wireframe Design Routine with semantic routing.

  Clean V4 implementation using StateServer architecture:
  - All sub-routines use WireframeEditor lens
  - StateServer is single source of truth
  - No lens_state in context - StateServer handles state

  ## Semantic Routing

  Agent analyzes user request and chooses the best sub-routine:
  - interact_wireframe: Explore and test the wireframe
  - play: Interactive play mode (calls PlayRoutine)
  - debug: Debug and fix issues
  - targeted_change: Make specific modifications
  - build_from_scratch: Create new wireframe (calls BuildWireframeRoutine)
  - modify_existing: Make broader changes
  - ask_clarification: Ask for more information
  - show_current_state: Explain current state

  ## Flow

  start → routing → [sub-routine] → show_result → start
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent
  alias WireframeEditorWeb.Integrations.ParsingIntegration
  alias WireframeEditorWeb.Servers.WireframeStateServer

  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  @sample_files %{
    "simple" => "wireframe_simple.html",
    "medium" => "wireframe_medium.html",
    "complex" => "wireframe_complex.html",
    "blank" => nil
  }

  # ============================================================================
  # Routine Definition
  # ============================================================================

  def routine_definition do
    %{
      # Wait for user input (main loop entry point)
      start: %{
        type: ChatUserInput,
        transitions: [{:routing, :always}]
      },

      # Routing phase - agent decides which sub-routine to use
      routing: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Analyze the user's request and choose the appropriate action.
          For simple questions, answer directly and transition to start.
          """,
          lenses: [
            ["WireframeEditorWeb.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SemanticTransition"
          ]
        },
        transitions: [
          {:interact_wireframe, "Test or explore the wireframe"},
          {:play, "Play games or interactive testing"},
          {:debug, "Debug and fix issues"},
          {:targeted_change, "Make a specific modification"},
          {:build_from_scratch, "Create new wireframe from scratch"},
          {:modify_existing, "Make broader structural changes"},
          {:ask_clarification, "Need more information"},
          {:show_current_state, "Explain current state"},
          {:start, :always}
        ]
      },

      # Interact with wireframe
      interact_wireframe: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Explore and test the wireframe.
          Use trigger_interaction to test, check LIVE DOM STATE for results.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Play mode - calls PlayRoutine
      play: %{
        type: WireframeEditorWeb.Routines.PlayRoutine,
        config: %{},
        transitions: [{:show_result, :always}]
      },

      # Debug issues
      debug: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Debug the issue: understand the problem, inspect state, test to reproduce, fix, verify.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:show_result, :always}]
      },

      # Targeted change
      targeted_change: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Make the specific change requested. Be precise and focused.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:show_result, :always}]
      },

      # Build from scratch - calls BuildWireframeRoutine
      build_from_scratch: %{
        type: WireframeEditorWeb.Routines.BuildWireframeRoutine,
        config: %{},
        transitions: [{:show_result, :always}]
      },

      # Modify existing
      modify_existing: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Make broader changes to the wireframe structure.
          Plan your approach for multiple related changes.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:show_result, :always}]
      },

      # Ask clarification
      ask_clarification: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          The request is unclear. Ask specific questions to understand what the user wants.
          """,
          lenses: [
            ["WireframeEditorWeb.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Show current state
      show_current_state: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Explain the current wireframe state and what the user can do with it.
          """,
          lenses: [
            ["WireframeEditorWeb.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Show result
      show_result: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Briefly summarize what you changed.
          """,
          lenses: [
            ["WireframeEditorWeb.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      }
    }
  end

  def check_condition(:always, _context), do: true

  # ============================================================================
  # Initial Context
  # ============================================================================

  def initial_context do
    %{
      messages: [],
      lenses: [
        "WireframeEditorWeb.Lenses.WireframeEditor",
        "Koalemos.Lenses.SequentialThinking"
      ],
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5-20250929",
      max_tokens: 64000,
      temperature: 0.7,
      wireframe_html: nil,
      wireframe_sample: nil
    }
  end

  # ============================================================================
  # Setup - Parse HTML and Start StateServer
  # ============================================================================

  def setup(_routine_config, state) do
    context = maybe_load_sample(state.context)
    routine_id = Map.get(context, :routine_id, "wireframe-v4-#{:erlang.unique_integer([:positive])}")
    html = Map.get(context, :wireframe_html)

    Log.info(:wireframe, "[WireframeDesignRoutine] Setting up routine #{routine_id}")

    case parse_html_to_designed(html, routine_id) do
      {:ok, designed} ->
        Log.debug(:wireframe, "[WireframeDesignRoutine] HTML parsed successfully")
        {:ok, _pid} = WireframeStateServer.start_link(routine_id: routine_id, designed: designed)
        Log.debug(:wireframe, "[WireframeDesignRoutine] StateServer started")
        {:ok, [{:add_or_update, %{routine_id: routine_id}}]}

      {:error, reason} ->
        Logger.error("[WireframeDesignRoutine] Failed to parse HTML: #{inspect(reason)}")
        {:ok, [{:add_or_update, %{routine_id: routine_id, setup_error: reason}}]}

      nil ->
        # No HTML provided - start with minimal root element
        Log.info(:wireframe, "[WireframeDesignRoutine] No HTML provided, starting with minimal root")
        minimal_root = %{dom_tree: %{tag: "div", id: "root", children: []}}
        {:ok, _pid} = WireframeStateServer.start_link(routine_id: routine_id, designed: minimal_root)
        {:ok, [{:add_or_update, %{routine_id: routine_id}}]}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp maybe_load_sample(%{wireframe_sample: "blank"} = context), do: context
  defp maybe_load_sample(%{wireframe_sample: nil} = context), do: context

  defp maybe_load_sample(%{wireframe_sample: sample} = context) when is_binary(sample) do
    case load_sample_html(sample) do
      {:ok, html} -> Map.put(context, :wireframe_html, html)
      {:error, reason} ->
        Logger.warning("[WireframeDesignRoutine] Failed to load sample '#{sample}': #{reason}")
        context
    end
  end

  defp maybe_load_sample(context), do: context

  defp load_sample_html(sample_id) do
    case Map.get(@sample_files, sample_id) do
      nil ->
        {:error, "Unknown sample: #{sample_id}. Available: #{Map.keys(@sample_files) |> Enum.join(", ")}"}

      filename ->
        fixtures_path = Path.join([:code.priv_dir(:koalemos), "wireframes"])
        path = Path.join([fixtures_path, filename])

        case File.read(path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
        end
    end
  end

  defp parse_html_to_designed(nil, _routine_id), do: nil
  defp parse_html_to_designed("", _routine_id), do: nil

  defp parse_html_to_designed(html, routine_id) when is_binary(html) do
    case ParsingIntegration.parse_wireframe(html, routine_id) do
      {:ok, wireframe} ->
        designed = %{
          dom_tree: wireframe.dom_tree,
          handlers: wireframe.javascript.handlers,
          init_scripts: convert_init_scripts_to_map(wireframe.javascript.init_scripts),
          custom_css: wireframe.css_rules,
          custom_functions: wireframe.javascript.functions,
          custom_variables: wireframe.javascript.variables
        }
        {:ok, designed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_init_scripts_to_map(init_scripts) when is_list(init_scripts) do
    init_scripts
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {script, idx}, acc ->
      if is_binary(script) and script != "" do
        Map.put(acc, "init_#{idx}", script)
      else
        acc
      end
    end)
  end

  defp convert_init_scripts_to_map(%{} = init_scripts), do: init_scripts
  defp convert_init_scripts_to_map(_), do: %{}
end
