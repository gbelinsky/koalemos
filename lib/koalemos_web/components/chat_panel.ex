defmodule KoalemosWeb.ChatPanel do
  @moduledoc """
  A complete chat interface combining MessageFeed and UserInputComponent.

  Features:
  - Displays conversation history
  - Handles user text and image input
  - Manages message list state
  - Optional mock AI responses for testing
  - Ready for backend integration (routine_id prop)

  ## Usage

  ```heex
  <.live_component
    module={KoalemosWeb.ChatPanel}
    id="chat-panel"
    routine_id="test-123"
    mock_responses={true}
  />
  ```

  ## Props

  - `routine_id` (string, required): Identifier for the chat session (unused in Sprint 4, ready for Sprint 6)
  - `mock_responses` (boolean, optional): If true, adds mock AI responses after user messages (default: false)
  - `initial_messages` (list, optional): Pre-populate with messages (default: [])

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

  alias KoalemosWeb.MessageFeed
  alias KoalemosWeb.UserInputComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:mock_responses, false)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:messages, fn -> Map.get(assigns, :initial_messages, []) end)
      |> assign_new(:mock_responses, fn -> Map.get(assigns, :mock_responses, false) end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-panel h-full flex flex-col">
      <!-- Message Feed (takes up remaining space after input) -->
      <div class="flex-1 overflow-hidden min-h-0">
        <.live_component
          module={MessageFeed}
          id={"#{@id}-feed"}
          messages={@messages}
        />
      </div>
      <!-- User Input (flexible height at bottom, max 50% of container) -->
      <div class="border-t-2 border-slate-300/60 bg-white p-4 max-h-[50%] overflow-y-auto flex-shrink-0">
        <.live_component
          module={UserInputComponent}
          id={"#{@id}-input"}
          placeholder="type your message..."
        />
      </div>
    </div>
    """
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
    socket = assign(socket, :messages, new_messages)

    # If mock responses enabled, schedule a mock AI response
    socket =
      if socket.assigns.mock_responses do
        Process.send_after(self(), {:mock_ai_response, user_message}, 2000)
        socket
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:mock_ai_response, _user_message}, socket) do
    # Create mock AI response
    mock_response = %{
      role: "assistant",
      content:
        "this is a mock response. in sprint 6, i'll connect to real AI! (but honestly, this is pretty good for a placeholder, right?)",
      metadata: %{
        id: "msg-#{System.unique_integer([:positive])}",
        timestamp: System.system_time(:second),
        source: :agent
      }
    }

    # Add to messages
    new_messages = socket.assigns.messages ++ [mock_response]
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
end
