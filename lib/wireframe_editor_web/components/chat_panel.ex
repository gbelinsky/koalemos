defmodule WireframeEditorWeb.ChatPanel do
  @moduledoc """
  A complete chat interface combining MessageFeed and UserInputComponent.

  Features:
  - Displays conversation history
  - Handles user text and image input
  - Manages message list state
  - Ready for backend integration (routine_id prop)

  ## Usage

  ```heex
  <.live_component
    module={WireframeEditorWeb.ChatPanel}
    id="chat-panel"
    routine_id="test-123"
    initial_messages={@messages}
  />
  ```

  ## Props

  - `routine_id` (string, required): Identifier for the chat session
  - `initial_messages` (list, optional): Pre-populate with messages (default: [])
  - `tool_display` (atom, optional): Tool display mode - `:full` (purple cards), `:inline` (subtle indicators), `:hidden` (default: `:full`)
  - `show_system_messages` (boolean, optional): Whether to show system messages in conversation (default: `true`)

  ## Message Format

  Messages follow the standard format:
  ```elixir
  %{
    role: "user" | "assistant" | "system",
    content: string | [%{type: "text" | "image", ...}],
    metadata: %{
      id: string,
      timestamp: integer,
      source: :user | :agent | :error
    }
  }
  ```

  ## Parent Integration

  This component is self-contained and doesn't require parent message handling.
  In future sprints, it will send user messages to the routine via the parent.
  """
  use Phoenix.LiveComponent

  alias WireframeEditorWeb.MessageFeed
  alias WireframeEditorWeb.UserInputComponent
  alias WireframeEditorWeb.StatusBar

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:show_screenshot_checkbox, false)
     |> assign(:active_tab, "conversation")}
  end

  @impl true
  def update(assigns, socket) do
    # Fetch latest screenshot from cache if routine_id is available
    # Now using server-side Puppeteer rendering with full CSS gradient support
    screenshot_data =
      case Map.get(assigns, :routine_id) do
        nil ->
          nil

        routine_id ->
          # Read from StateServer instead of legacy ScreenshotCache
          alias WireframeEditorWeb.Servers.WireframeStateServer
          if WireframeStateServer.exists?(routine_id) do
            WireframeStateServer.get_screenshot(routine_id)
          else
            nil
          end
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:screenshot_data, screenshot_data)
      |> assign_new(:messages, fn -> Map.get(assigns, :initial_messages, []) end)
      |> assign_new(:current_step, fn -> nil end)
      |> assign_new(:routine_module, fn -> nil end)
      |> assign_new(:execution_stack, fn -> [] end)
      |> assign_new(:step_module, fn -> nil end)
      |> assign_new(:show_screenshot_checkbox, fn ->
        Map.get(assigns, :show_screenshot_checkbox, false)
      end)
      |> assign_new(:disabled, fn -> Map.get(assigns, :disabled, false) end)
      |> assign_new(:status, fn -> :running end)
      |> assign_new(:last_error, fn -> nil end)
      |> assign_new(:tool_display, fn -> Map.get(assigns, :tool_display, :full) end)
      |> assign_new(:show_system_messages, fn ->
        Map.get(assigns, :show_system_messages, true)
      end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-panel h-full flex flex-col">
      <!-- Tab Header (only shown when system messages are visible) -->
      <%= if @show_system_messages do %>
        <div class="border-b border-slate-200 bg-white">
          <div class="flex">
            <button
              phx-click="switch_tab"
              phx-value-tab="conversation"
              phx-target={@myself}
              class={[
                "px-4 py-2 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "conversation",
                  do: "border-blue-500 text-blue-600",
                  else: "border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300"
                )
              ]}
            >
              Conversation
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="raw"
              phx-target={@myself}
              class={[
                "px-4 py-2 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "raw",
                  do: "border-blue-500 text-blue-600",
                  else: "border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300"
                )
              ]}
            >
              Raw Messages
            </button>
          </div>
        </div>
      <% end %>

      <!-- Content Area -->
      <div class="flex-1 overflow-hidden min-h-0">
        <%= if !@show_system_messages || @active_tab == "conversation" do %>
          <.live_component
            module={MessageFeed}
            id={"#{@id}-feed"}
            messages={@messages}
            current_step={@current_step}
            status={@status}
            last_error={@last_error}
            tool_display={@tool_display}
            show_system_messages={@show_system_messages}
          />
        <% else %>
          <div class="h-full overflow-auto p-4 bg-slate-50 font-mono text-xs">
            <pre class="text-slate-800"><%= Jason.encode!(@messages, pretty: true) %></pre>
          </div>
        <% end %>
      </div>

      <!-- Status Bar (between conversation and input) -->
      <.live_component
        module={StatusBar}
        id={"#{@id}-status"}
        current_step={@current_step}
        routine_module={@routine_module}
        execution_stack={@execution_stack}
        step_module={@step_module}
        status={@status}
      />

      <!-- Token Usage Display -->
      <%= if has_token_data?(@messages) do %>
        <div class="border-t border-slate-200 bg-gradient-to-r from-slate-50 to-indigo-50/20 px-4 py-2">
          <div class="flex items-center gap-4 text-xs text-slate-600">
            <div class="flex items-center gap-1.5">
              <span class="font-medium text-slate-500">Total In:</span>
              <span class="font-mono font-semibold text-indigo-700">{format_number(total_input_tokens(@messages))}</span>
            </div>
            <div class="flex items-center gap-1.5">
              <span class="font-medium text-slate-500">Total Out:</span>
              <span class="font-mono font-semibold text-indigo-700">{format_number(total_output_tokens(@messages))}</span>
            </div>
            <div class="flex items-center gap-1.5">
              <span class="font-medium text-slate-500">Last Context:</span>
              <span class="font-mono font-semibold text-blue-700">{format_number(last_request_input_tokens(@messages))}</span>
            </div>
          </div>
        </div>
      <% end %>

      <!-- User Input (flexible height at bottom, max 50% of container) -->
      <div class="border-t-2 border-slate-300/60 bg-white p-4 max-h-[50%] overflow-y-auto flex-shrink-0">
        <.live_component
          module={UserInputComponent}
          id={"#{@id}-input"}
          placeholder="type your message..."
          show_screenshot_checkbox={@show_screenshot_checkbox}
          screenshot_data={@screenshot_data}
          disabled={@disabled}
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_info(:check_uploads, socket) do
    # Forward to UserInputComponent for upload polling
    send_update(UserInputComponent, id: "#{socket.assigns.id}-input", check_uploads: true)
    {:noreply, socket}
  end

  def handle_info({:clear_sent_feedback, component_id}, socket) do
    # Forward to UserInputComponent to clear send feedback
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  def handle_info({:user_input_submitted, %{text: text, images: images}}, socket) do
    # Create user message
    user_message = create_user_message(text, images)

    # Add to messages
    new_messages = socket.assigns.messages ++ [user_message]

    {:noreply, assign(socket, :messages, new_messages)}
  end

  # Private Functions

  # Made public for testing
  def create_user_message(text, images) when is_binary(text) and length(images) == 0 do
    %{
      role: "user",
      content: text,
      metadata: %{
        id: "msg-#{System.unique_integer([:positive])}",
        timestamp: System.system_time(:second),
        source: :user
      }
    }
  end

  def create_user_message(text, images) when is_binary(text) and length(images) > 0 do
    # Convert images from UserInputComponent format to message content format
    content_blocks =
      if text != "" do
        [%{type: "text", text: text}]
      else
        []
      end

    image_blocks =
      Enum.map(images, fn image ->
        %{
          type: "image",
          source: %{
            data: image.base64,
            media_type: image.media_type
          }
        }
      end)

    %{
      role: "user",
      content: content_blocks ++ image_blocks,
      metadata: %{
        id: "msg-#{System.unique_integer([:positive])}",
        timestamp: System.system_time(:second),
        source: :user
      }
    }
  end

  # Token usage calculation helpers

  defp has_token_data?(messages) do
    Enum.any?(messages, fn message ->
      usage = get_in(message, [:metadata, :usage]) || get_in(message, ["metadata", "usage"])
      usage != nil && map_size(usage) > 0
    end)
  end

  defp total_input_tokens(messages) do
    messages
    |> Enum.map(&get_message_input_tokens/1)
    |> Enum.sum()
  end

  defp total_output_tokens(messages) do
    messages
    |> Enum.map(&get_message_output_tokens/1)
    |> Enum.sum()
  end

  defp last_request_input_tokens(messages) do
    # Find the last message with usage data (most recent API call)
    messages
    |> Enum.reverse()
    |> Enum.find_value(0, fn message ->
      usage = get_in(message, [:metadata, :usage]) || get_in(message, ["metadata", "usage"])

      if usage && map_size(usage) > 0 do
        Map.get(usage, "input_tokens") || Map.get(usage, :input_tokens) || 0
      else
        nil
      end
    end)
  end

  defp get_message_input_tokens(message) do
    usage = get_in(message, [:metadata, :usage]) || get_in(message, ["metadata", "usage"]) || %{}
    Map.get(usage, "input_tokens") || Map.get(usage, :input_tokens) || 0
  end

  defp get_message_output_tokens(message) do
    usage = get_in(message, [:metadata, :usage]) || get_in(message, ["metadata", "usage"]) || %{}
    Map.get(usage, "output_tokens") || Map.get(usage, :output_tokens) || 0
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(_), do: "0"
end
