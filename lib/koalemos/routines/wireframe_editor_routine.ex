defmodule Koalemos.Routines.WireframeEditorRoutine do
  @moduledoc """
  Wireframe editor routine using V4 architecture.

  V4 Architecture Benefits:
  - No PubSub: Direct process communication via Registry
  - No adapters: Lens calls StateServer directly
  - Parsing in setup: StateServer receives already-parsed data
  - Two-state preview model: pid == nil or pid (no :initializing)

  Single-step agent loop:
  1. Wait for user input
  2. Agent sees context (designed + running + screenshot)
  3. Agent uses tools (modify_classes, etc.)
  4. Loop back to wait for next user input
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent
  alias KoalemosWeb.Servers.WireframeStateServer
  alias Koalemos.Integrations.ParsingIntegration

  require Logger

  @default_html """
  <div id="app">
    <h1 id="title">Dynamic Counter</h1>
    <div id="counter-display">0</div>
    <button id="increment-btn">Increment</button>
    <button id="decrement-btn">Decrement</button>
    <div id="dynamic-container">
      <!-- Init script will add elements here -->
    </div>
  </div>

  <script data-wireframe-init>
    // Initialize counter variable
    window.count = 0;

    // Create dynamic elements
    const container = document.getElementById('dynamic-container');
    for (let i = 1; i <= 3; i++) {
      const el = document.createElement('div');
      el.id = 'dynamic-item-' + i;
      el.style.cssText = 'padding: 8px; background: #f3f4f6; margin: 4px 0; border-radius: 4px;';
      el.textContent = 'Dynamic item ' + i;
      container.appendChild(el);
    }

    // Attach click handlers
    document.getElementById('increment-btn').addEventListener('click', function() {
      window.count++;
      document.getElementById('counter-display').textContent = window.count;
      console.log('Counter incremented to: ' + window.count);
    });

    document.getElementById('decrement-btn').addEventListener('click', function() {
      window.count--;
      document.getElementById('counter-display').textContent = window.count;
      console.log('Counter decremented to: ' + window.count);
    });

    console.log('Init script completed - created 3 dynamic items and attached handlers');
  </script>

  <style>
    #app {
      font-family: sans-serif;
      padding: 20px;
    }
    #title {
      font-size: 1.5rem;
      font-weight: bold;
      margin-bottom: 10px;
    }
    #counter-display {
      font-size: 3rem;
      color: #2563eb;
      margin: 16px 0;
      font-weight: bold;
    }
    #increment-btn, #decrement-btn {
      padding: 10px 20px;
      background: #3b82f6;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      margin-right: 8px;
    }
    #increment-btn:hover, #decrement-btn:hover {
      background: #2563eb;
    }
    #decrement-btn {
      background: #ef4444;
    }
    #decrement-btn:hover {
      background: #dc2626;
    }
    #dynamic-container {
      margin-top: 20px;
      border: 1px solid #e5e7eb;
      padding: 12px;
      border-radius: 8px;
    }
  </style>
  """

  @doc """
  Returns the routine definition with simple agent loop.
  """
  def routine_definition do
    %{
      start: %{
        type: ChatUserInput,
        transitions: [{:agent_loop, :always}]
      },
      agent_loop: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          You are a wireframe editor assistant. Help the user modify their wireframe.

          You can see the current wireframe state (designed and running) and use tools to modify it.

          ## Available Tools

          **Structure Tools (modify DOM):**
          - modify_classes: Add or remove CSS classes from elements
          - modify_elements: Add, remove, or replace DOM elements
          - manage_attributes: Set or remove HTML attributes

          **Behavior Tools (modify JavaScript):**
          - manage_handlers: Add, replace, or remove event handlers
          - manage_functions: Add, replace, or remove custom JS functions
          - manage_variables: Set or remove global variables
          - manage_css: Add, replace, or remove CSS rules
          - manage_init_scripts: Add, replace, or remove initialization scripts

          **Testing Tool:**
          - trigger_interaction: Test interactions (ephemeral - doesn't persist)

          When the user asks for changes, use the appropriate tool(s) to make the modification.
          After making changes, briefly confirm what you did.
          """,
          lenses: ["Koalemos.Lenses.WireframeEditor"]
        },
        transitions: [{:start, :always}]
      }
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{
      messages: [],
      lenses: ["Koalemos.Lenses.WireframeEditor"],
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5-20250929",
      max_tokens: 64000,
      temperature: 0.7
    }
  end

  @doc """
  Setup function - parses HTML and creates StateServer with pre-parsed data.

  Key difference from V3: Parsing happens HERE, not in StateServer.
  StateServer receives already-parsed designed state.
  """
  def setup(_routine_config, state) do
    routine_id = state.context[:routine_id] || generate_routine_id()
    html = state.context[:wireframe_html] || @default_html

    Logger.info("[WireframeEditorRoutine] Setting up routine #{routine_id}")

    # Parse HTML in the routine (not in StateServer)
    case parse_html_to_designed(html) do
      {:ok, designed} ->
        Logger.info("[WireframeEditorRoutine] HTML parsed successfully")

        # Start StateServer with pre-parsed designed state
        # Note: start_link will crash on failure, so no error tuple to match
        {:ok, _pid} = WireframeStateServer.start_link(routine_id: routine_id, designed: designed)
        Logger.info("[WireframeEditorRoutine] StateServer started")
        {:ok, [{:add_or_update, %{routine_id: routine_id}}]}

      {:error, reason} ->
        Logger.error("[WireframeEditorRoutine] Failed to parse HTML: #{inspect(reason)}")
        {:ok, [{:add_or_update, %{routine_id: routine_id, setup_error: reason}}]}
    end
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp generate_routine_id do
    "wireframe-v4-#{:erlang.unique_integer([:positive])}"
  end

  defp parse_html_to_designed(html_string) when is_binary(html_string) do
    case ParsingIntegration.parse_wireframe(html_string, "temp") do
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

  # init_scripts from parsing is a list of code strings
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
