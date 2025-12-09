defmodule Koalemos.Routines.WireframeDesignV4Routine do
  @moduledoc """
  V4 Wireframe Design Routine with semantic routing.

  Clean V4 implementation using StateServer architecture:
  - All sub-routines use WireframeEditorV4 lens
  - StateServer is single source of truth
  - No lens_state in context - StateServer handles state

  ## Semantic Routing

  Agent analyzes user request and chooses the best sub-routine:
  - interact_wireframe: Explore and test the wireframe
  - play: Interactive play mode (calls PlayV4Routine)
  - debug: Debug and fix issues
  - targeted_change: Make specific modifications
  - build_from_scratch: Create new wireframe (calls BuildWireframeV4Routine)
  - modify_existing: Make broader changes
  - ask_clarification: Ask for more information
  - show_current_state: Explain current state

  ## Flow

  start → routing → [sub-routine] → show_result → start
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent
  alias Koalemos.Integrations.ParsingIntegration
  alias KoalemosWeb.Servers.WireframeStateServerV4

  require Logger

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
          Analyze the user's request and choose the most appropriate action.

          Consider what the user wants to accomplish and route accordingly.

          NOTE: If the user just wants an answer or information without any tool use,
          you can answer directly here and transition to start for the next input.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditorV4", %{readonly: true}],
            "Koalemos.Lenses.SemanticTransition"
          ]
        },
        transitions: [
          {:interact_wireframe, "Interact with, inspect, or test the wireframe using tools"},
          {:play, "Enter interactive play mode for games or conversational testing"},
          {:debug, "Debug and troubleshoot wireframe issues"},
          {:targeted_change, "Make a specific, focused modification to the wireframe"},
          {:build_from_scratch, "Create a new wireframe structure from description"},
          {:modify_existing, "Make broader changes to existing wireframe structure"},
          {:ask_clarification, "Ask user for more information or clarification"},
          {:show_current_state, "Show screenshot and explain current wireframe state"},
          {:start, :always}
        ]
      },

      # Interact with wireframe - full tool access
      interact_wireframe: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Interact with and explore the wireframe using tools.

          You have full access to wireframe tools for:
          - Testing interactions with trigger_interaction
          - Inspecting the current state
          - Making small exploratory changes if helpful
          - Answering questions that require tool use

          Focus on interaction and exploration rather than major modifications.
          """,
          lenses: [
            "Koalemos.Lenses.WireframeEditorV4",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Play mode - calls PlayV4Routine
      play: %{
        type: Koalemos.Routines.PlayV4Routine,
        config: %{},
        transitions: [{:show_result, :always}]
      },

      # Debug - investigate and fix issues
      debug: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Help debug the wireframe issue the user is experiencing.

          Use a systematic debugging approach:
          1. Understand the problem
          2. Inspect relevant code/state
          3. Test to reproduce the issue
          4. Identify the root cause
          5. Apply fixes
          6. Verify the fix works

          Use sequential_thinking to explain your debugging process.
          """,
          lenses: [
            "Koalemos.Lenses.WireframeEditorV4",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:show_result, :always}]
      },

      # Targeted change - focused modifications
      targeted_change: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Make the specific change requested by the user.

          Use the wireframe editing tools to make focused, precise changes.
          When done, use sequential_thinking to explain what you changed and why.
          """,
          lenses: [
            "Koalemos.Lenses.WireframeEditorV4",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:show_result, :always}]
      },

      # Build from scratch - calls BuildWireframeV4Routine
      build_from_scratch: %{
        type: Koalemos.Routines.BuildWireframeV4Routine,
        config: %{},
        transitions: [{:show_result, :always}]
      },

      # Modify existing - broader changes
      modify_existing: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Make broader modifications to the existing wireframe.

          You may need to make multiple related changes. Use sequential_thinking to plan
          your approach and explain your changes as you go.
          """,
          lenses: [
            "Koalemos.Lenses.WireframeEditorV4",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:show_result, :always}]
      },

      # Ask clarification - readonly context
      ask_clarification: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          The user's request is ambiguous or needs more details.

          Ask specific questions to understand what they want.
          Be helpful and suggest options if appropriate.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditorV4", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Show current state - readonly context
      show_current_state: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Show and explain the current state of the wireframe.

          Explain what's currently implemented and what the user can do with it.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditorV4", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Show result - summarize changes
      show_result: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Summarize the changes you just made.

          Review the current wireframe state and explain what changed.
          Be concise and clear about what you accomplished.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditorV4", %{readonly: true}],
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
        "Koalemos.Lenses.WireframeEditorV4",
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

    Logger.info("[WireframeDesignV4Routine] Setting up routine #{routine_id}")

    case parse_html_to_designed(html, routine_id) do
      {:ok, designed} ->
        Logger.info("[WireframeDesignV4Routine] HTML parsed successfully")
        {:ok, _pid} = WireframeStateServerV4.start_link(routine_id: routine_id, designed: designed)
        Logger.info("[WireframeDesignV4Routine] StateServer started")
        {:ok, [{:add_or_update, %{routine_id: routine_id}}]}

      {:error, reason} ->
        Logger.error("[WireframeDesignV4Routine] Failed to parse HTML: #{inspect(reason)}")
        {:ok, [{:add_or_update, %{routine_id: routine_id, setup_error: reason}}]}

      nil ->
        # No HTML provided - start with minimal root element
        Logger.info("[WireframeDesignV4Routine] No HTML provided, starting with minimal root")
        minimal_root = %{dom_tree: %{tag: "div", id: "root", children: []}}
        {:ok, _pid} = WireframeStateServerV4.start_link(routine_id: routine_id, designed: minimal_root)
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
        Logger.warning("[WireframeDesignV4Routine] Failed to load sample '#{sample}': #{reason}")
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
