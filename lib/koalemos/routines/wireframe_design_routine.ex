defmodule Koalemos.Routines.WireframeDesignRoutine do
  @moduledoc """
  Multi-stage wireframe design routine with semantic routing (M5).

  This routine uses semantic transitions to let the agent choose its own path
  through different sub-routines based on the user's request.

  ## Architecture Pattern

  1. **Routing Phase:** Agent analyzes request and chooses appropriate sub-routine
  2. **Sub-Routines:** Specialized TemplatedSemanticAgent instances for different tasks
  3. **Loop Back:** After completion, returns to start for next user input

  ## Available Sub-Routines

  - **interact_wireframe** - Interact with, inspect, or test the wireframe using tools
  - **play** - Enter tight interaction loop for games or conversational testing (calls PlayRoutine)
  - **debug** - Systematically debug and fix wireframe issues
  - **targeted_change** - Make a specific, focused modification to the wireframe
  - **build_from_scratch** - Create a new wireframe structure from description (calls BuildWireframeRoutine)
  - **modify_existing** - Make broader changes to existing wireframe
  - **ask_clarification** - Request more information from the user
  - **show_current_state** - Show screenshot and explain current wireframe state

  Note: Simple questions can be answered directly in the routing phase without needing a separate step.

  ## Semantic Transitions

  Uses string-based semantic transitions that serve dual purpose:
  - Condition marker for agent to understand when to choose
  - Description for agent to reason about choice

  ## Example Flow

  ```
  User: "Make the button blue"
    ↓
  routing → analyze request → choose_transition(targeted_change, "specific color change")
    ↓
  targeted_change → WireframeEditor tools → modify_css
    ↓
  show_result → capture screenshot → return to start
    ↓
  start → wait for next user input
  ```

  ## Initial Context

  Requires:
  - `wireframe_html` or `wireframe_sample` - Initial wireframe content
  - `llm_provider`, `llm_model` - LLM configuration
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent
  alias Koalemos.Integrations.ParsingIntegration
  require Logger

  @sample_files %{
    "simple" => "wireframe_simple.html",
    "medium" => "wireframe_medium.html",
    "complex" => "wireframe_complex.html"
  }

  @doc """
  Returns the routine definition with semantic routing.

  Main loop:
  start (ChatUserInput) → routing (choose sub-routine) → sub-routine → show_result → start
  """
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
          Analyze the user's request and choose the most appropriate sub-routine.

          Consider what the user wants to accomplish and route accordingly.

          NOTE: If the user just wants an answer or information without any tool use,
          you can answer directly here instead of routing to another step. Just provide
          the answer and transition to start for the next user input.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditor", %{readonly: true}],
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
          # Fallback to start if no other matches (also used when answering directly)
          {:start, :always}
        ]
      },

      # Interact with wireframe - full tool access for inspection and testing
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

          Use tools as needed to respond to the user's request.
          Focus on interaction and exploration rather than major modifications.
          """
        },
        transitions: [{:start, :always}]
      },

      # Play mode - tight interaction loop via PlayRoutine sub-routine
      play: %{
        type: Koalemos.Routines.PlayRoutine,
        config: %{},
        transitions: [{:show_result, :always}]
      },

      # Debug - investigate and fix wireframe issues
      debug: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Help debug the wireframe issue the user is experiencing.

          You have full access to all wireframe tools to:
          - Inspect the current state (read_dom, capture_screenshot)
          - Test interactions to reproduce issues (trigger_interaction)
          - Make fixes to resolve problems (modify_elements, manage_css, manage_handlers, etc.)
          - Explain what was wrong and how you fixed it

          Use a systematic debugging approach:
          1. Understand the problem
          2. Inspect relevant code/state
          3. Test to reproduce the issue
          4. Identify the root cause
          5. Apply fixes
          6. Verify the fix works

          Use sequential_thinking to explain your debugging process and findings.
          """
        },
        transitions: [{:show_result, :always}]
      },

      # Targeted change - inherits default lenses (WireframeEditor + SequentialThinking)
      targeted_change: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Make the specific change requested by the user.

          Use the wireframe editing tools to make focused, precise changes.
          When done, use sequential_thinking to explain what you changed and why.
          """
        },
        transitions: [{:show_result, :always}]
      },

      # Build from scratch - calls BuildWireframeRoutine sub-routine
      build_from_scratch: %{
        type: Koalemos.Routines.BuildWireframeRoutine,
        config: %{},
        transitions: [{:show_result, :always}]
      },

      # Modify existing - inherits default lenses
      modify_existing: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Make broader modifications to the existing wireframe.

          You may need to make multiple related changes. Use sequential_thinking to plan
          your approach and explain your changes as you go.
          """
        },
        transitions: [{:show_result, :always}]
      },

      # Ask clarification - readonly wireframe context
      ask_clarification: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          The user's request is ambiguous or needs more details.

          Ask specific questions to understand what they want.
          Be helpful and suggest options if appropriate.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Show current state - readonly wireframe context
      show_current_state: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Show and explain the current state of the wireframe.

          Explain what's currently implemented and what the user can do with it.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      },

      # Show result - readonly wireframe context to summarize changes
      show_result: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Summarize the changes you just made.

          Review the current wireframe state and explain what changed.
          Be concise and clear about what you accomplished.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:start, :always}]
      }
    }
  end

  @doc """
  Condition check function - always returns true.
  All semantic routing is handled by SemanticTransition lens.
  """
  def check_condition(:always, _context), do: true

  @doc """
  Returns default initial context for the routine.

  User can provide:
  - wireframe_sample: Load a sample HTML file ("simple", "medium", "complex")
  - wireframe_html: Directly provide HTML content
  """
  def initial_context do
    %{
      messages: [],
      lenses: [
        "Koalemos.Lenses.WireframeEditor",
        "Koalemos.Lenses.SequentialThinking"
      ],
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",
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

    # Return in ContextManager format
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
        Logger.warning("[WireframeDesignRoutine] Failed to load sample '#{sample}': #{reason}")
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
        # Compute path at runtime for release compatibility
        fixtures_path = Path.join([:code.priv_dir(:koalemos), "wireframes"])
        path = Path.join([fixtures_path, filename])

        case File.read(path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
        end
    end
  end

  defp parse_and_initialize_lens_state(%{wireframe_html: html} = context) when is_binary(html) do
    # Generate a routine ID for cache storage
    routine_id =
      Map.get(context, :routine_id, "wireframe-design-#{:erlang.unique_integer([:positive])}")

    case ParsingIntegration.parse_wireframe(html, routine_id) do
      {:ok, wireframe} ->
        # Initialize lens_state with designed version from parsed wireframe
        lens_state = %{
          designed: %{
            dom_tree: wireframe.dom_tree,
            style_elements: wireframe.styles,
            script_elements: wireframe.scripts,
            custom_css: extract_css_rules_as_map(wireframe.css_rules),
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
        Logger.warning("[WireframeDesignRoutine] Failed to parse HTML: #{reason}")
        context
    end
  end

  defp parse_and_initialize_lens_state(context), do: context

  # Convert CSS rules list to map format (selector -> declarations)
  defp extract_css_rules_as_map(css_rules) when is_list(css_rules) do
    Enum.reduce(css_rules, %{}, fn rule, acc ->
      Map.put(acc, rule.selector, rule.declarations)
    end)
  end

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
