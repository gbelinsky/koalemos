defmodule WireframeEditorWeb.StatusBar do
  @moduledoc """
  Status bar component showing current routine execution state.

  Displays:
  - Current routine and step (breadcrumb)
  - Current identity (User/Agent/System)
  - Auto-hides when idle, prominent when waiting for user

  Positioned between conversation panel and input panel.
  """
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:current_step, fn -> nil end)
      |> assign_new(:routine_module, fn -> nil end)
      |> assign_new(:execution_stack, fn -> [] end)
      |> assign_new(:step_module, fn -> nil end)
      |> assign_new(:status, fn -> :idle end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    # Determine identity and visibility
    assigns = assign(assigns, :identity, determine_identity(assigns.step_module, assigns.current_step))
    assigns = assign(assigns, :visible, should_show?(assigns.identity, assigns.status))
    assigns =
      assign(
        assigns,
        :breadcrumb,
        build_breadcrumb(assigns.routine_module, assigns.execution_stack, assigns.current_step)
      )

    ~H"""
    <div
      class={[
        "status-bar h-10 flex-shrink-0 border-t border-b border-slate-200 bg-white px-4",
        if(!@visible, do: "hidden"),
        if(@identity == :user, do: "bg-blue-50 border-blue-300", else: "bg-white")
      ]}
    >
      <div class="flex items-center justify-between text-sm h-full">
        <!-- Identity Indicator -->
        <div class="flex items-center space-x-2 flex-shrink-0">
          <%= case @identity do %>
            <% :user -> %>
              <span class="text-lg">👤</span>
              <span class="font-medium text-blue-700">User</span>
              <span class="text-slate-500 text-xs ml-2">Waiting for your input...</span>
            <% :agent -> %>
              <span class="text-lg">🤖</span>
              <span class="font-medium text-slate-700">Agent</span>
              <!-- Spinner for LLM request -->
              <svg class="animate-spin h-4 w-4 text-slate-500 ml-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            <% :system -> %>
              <span class="text-lg">⚙️</span>
              <span class="font-medium text-slate-700">System</span>
            <% _ -> %>
              <span class="text-slate-400">Idle</span>
          <% end %>
        </div>
        <!-- Breadcrumb (truncate if too long) -->
        <div class="text-slate-500 text-xs font-mono truncate ml-4">
          <%= @breadcrumb %>
        </div>
      </div>
    </div>
    """
  end

  # Private Functions

  # Determines the current identity based on the step module and step name.
  # - User: Koalemos.Steps.User.ChatUserInput (the only user step for now)
  # - Agent: Steps making LLM requests
  # - System: Everything else (tool execution, parsing, etc.)
  #
  # TODO (post-demo): More robust detection by checking waiting_for state and event types
  defp determine_identity(step_module, step) do
    # Convert step_module to string for comparison (it comes as string from metadata)
    step_module_str = to_string(step_module)

    cond do
      # User input steps: check if step_module is ChatUserInput
      step_module_str =~ "ChatUserInput" ->
        :user

      # Agent/LLM steps: check step name contains llm_request or llm
      is_llm_step?(step) ->
        :agent

      # System steps (everything else)
      true ->
        :system
    end
  end

  defp is_llm_step?(step) when is_atom(step) or is_binary(step) do
    step_str = to_string(step)
    step_str =~ "llm_request" or step_str =~ "llm"
  end

  defp is_llm_step?(_), do: false

  # Determines if the status bar should be visible.
  # Rules:
  # - Always show when waiting for user (:user identity)
  # - Show when agent or system is working
  # - Hide when idle or unknown
  defp should_show?(:user, _status), do: true
  defp should_show?(:agent, _status), do: true
  defp should_show?(:system, :idle), do: false
  defp should_show?(:system, _status), do: true
  defp should_show?(_, :idle), do: false
  defp should_show?(_, _), do: false

  # Builds breadcrumb from routine module, execution stack, and current step.
  # Format: "RoutineName → sub_routine → stage → step"
  # Example: "WireframeDesignRoutine → build_from_scratch → polish → llm_request"
  defp build_breadcrumb(nil, [], nil), do: ""
  defp build_breadcrumb(nil, [], step), do: to_string(step)

  defp build_breadcrumb(module, execution_stack, step) when is_atom(module) or is_binary(module) do
    # Start with the main routine name (simplified)
    routine_name = extract_routine_name(module)

    # Build the path from execution stack (reverse to show call order)
    stack_path =
      execution_stack
      |> Enum.reverse()  # Stack is deepest-first, reverse to show call order
      |> Enum.map(fn frame ->
        # Each frame is a map: %{module: ..., step: ...}
        case frame do
          %{step: step_name} -> to_string(step_name)
          %{"step" => step_name} -> to_string(step_name)
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Add current step to the end
    all_parts =
      [routine_name | stack_path] ++
        if step, do: [to_string(step)], else: []

    Enum.join(all_parts, " → ")
  end

  defp build_breadcrumb(module, _stack, step) do
    "#{module} → #{step}"
  end

  # Extracts routine name from full module path.
  # Example: "Elixir.Koalemos.Routines.WireframeDesignRoutine" → "WireframeDesignRoutine"
  defp extract_routine_name(nil), do: ""

  defp extract_routine_name(module) when is_atom(module) do
    module
    |> to_string()
    |> extract_routine_name()
  end

  defp extract_routine_name(module_str) when is_binary(module_str) do
    module_str
    |> String.split(".")
    |> List.last()
    |> case do
      nil -> module_str
      name -> name
    end
  end
end
