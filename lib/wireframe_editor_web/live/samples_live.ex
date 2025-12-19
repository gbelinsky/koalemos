defmodule WireframeEditorWeb.SamplesLive do
  use WireframeEditorWeb, :live_view
  alias WireframeEditorWeb.MessageCards.UserCard
  alias WireframeEditorWeb.MessageCards.AssistantCard
  alias WireframeEditorWeb.MessageCards.ErrorCard
  alias WireframeEditorWeb.MessageFeed
  alias WireframeEditorWeb.UserInputComponent
  alias WireframeEditorWeb.ChatPanel

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       expanded_images: MapSet.new(),
       page_title: "Component Samples",
       user_messages: create_user_messages(),
       assistant_messages: create_assistant_messages(),
       error_messages: create_error_messages(),
       conversation_messages: create_conversation_messages(),
       current_user_input: ""
     )}
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    # Forward to UserInputComponent instances (both standalone and in ChatPanel)
    send_update(UserInputComponent, id: "sample-input", check_uploads: true)
    send_update(UserInputComponent, id: "sample-chat-panel-input", check_uploads: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    # Forward to UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_input_submitted, %{text: text, images: images}}, socket) do
    require Logger
    Logger.info("User input submitted: text=#{text}, images=#{length(images)}")

    # Demo only - just log it, no flash message needed
    {:noreply, socket}
  end

  defp create_user_messages do
    [
      %{
        content: "Hello! This is a simple user message.",
        metadata: %{timestamp: 1_730_000_001}
      },
      %{
        content: "I can use **bold** and _italic_ text, plus [links](https://example.com)!",
        metadata: %{timestamp: 1_730_000_002}
      },
      %{
        content: [
          %{type: "text", text: "Check out this placeholder image:"},
          %{
            type: "image",
            source: %{
              data:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
              media_type: "image/png"
            }
          }
        ],
        metadata: %{timestamp: 1_730_000_003}
      },
      %{
        content: [
          %{type: "text", text: "Multiple images can be expanded:"},
          %{
            type: "image",
            source: %{
              data:
                "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
              media_type: "image/png"
            }
          },
          %{
            type: "image",
            source: %{
              data:
                "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQDwADhgGAWjR9awAAAABJRU5ErkJggg==",
              media_type: "image/png"
            }
          }
        ],
        metadata: %{timestamp: 1_730_000_007}
      }
    ]
  end

  defp create_assistant_messages do
    [
      %{
        content: "I'm here to help! Let me know what you need.",
        metadata: %{timestamp: 1_730_000_004}
      },
      %{
        content:
          "I can format responses with **numbered lists**, _emphasis_, and `code snippets`.\n\nHere's code:\n\n```elixir\ndefmodule Example do\n  def hello, do: :world\nend\n```",
        metadata: %{timestamp: 1_730_000_005}
      },
      %{
        content:
          "This is a longer response to show how text wraps and flows naturally. The card expands to fit content while maintaining readability.",
        metadata: %{timestamp: 1_730_000_006}
      }
    ]
  end

  defp create_error_messages do
    [
      "Connection failed. Please try again.",
      "Invalid input: The field 'name' is required.",
      "API rate limit exceeded. Please wait before retrying."
    ]
  end

  defp create_conversation_messages do
    [
      %{
        role: "user",
        content: "Hello! Can you help me with something?",
        metadata: %{id: "conv-1", timestamp: 1_730_000_001, source: :user}
      },
      %{
        role: "assistant",
        content: "Of course! I'd be happy to help. What would you like assistance with?",
        metadata: %{id: "conv-2", timestamp: 1_730_000_002, source: :agent}
      },
      %{
        role: "user",
        content: [
          %{type: "text", text: "Can you analyze this image?"},
          %{
            type: "image",
            source: %{
              data:
                "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
              media_type: "image/png"
            }
          }
        ],
        metadata: %{id: "conv-3", timestamp: 1_730_000_003, source: :user}
      },
      %{
        role: "assistant",
        content:
          "I can see the image you've shared. It appears to be a small placeholder. Let me analyze it more carefully...",
        metadata: %{id: "conv-4", timestamp: 1_730_000_004, source: :agent}
      },
      %{
        role: "user",
        content: "Thanks! That's exactly what I needed.",
        metadata: %{id: "conv-5", timestamp: 1_730_000_005, source: :user}
      }
    ]
  end

  @impl true
  def handle_event("expand_image", %{"card" => card_id}, socket) do
    {:noreply, update(socket, :expanded_images, &MapSet.put(&1, card_id))}
  end

  @impl true
  def handle_event("collapse_image", %{"card" => card_id}, socket) do
    {:noreply, update(socket, :expanded_images, &MapSet.delete(&1, card_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style>html, body { background-color: rgb(243 244 246); }</style>
    <div class="min-h-screen bg-gray-100 p-8">
      <div class="max-w-4xl mx-auto">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Component Samples</h1>
        <p class="text-gray-600 mb-8">
          Demo of all message components from Sprints 2, 3 & 4
        </p>
        <!-- Chat Panel (Sprint 4) -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">Chat Panel (Sprint 4)</h2>
          <p class="text-gray-600 mb-4 text-sm">
            Complete integrated chat experience combining MessageFeed + UserInputComponent.
            Shows a sample conversation with user and assistant messages.
          </p>
          <div class="bg-white rounded-xl shadow-lg overflow-hidden" style="height: 600px;">
            <.live_component
              module={ChatPanel}
              id="sample-chat-panel"
              routine_id="demo-routine-123"
              initial_messages={@conversation_messages}
            />
          </div>
        </section>
        <hr class="my-12 border-gray-300" />
        <!-- Message Feed (Sprint 3) -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">Message Feed</h2>
          <p class="text-gray-600 mb-4 text-sm">
            Complete conversation view with user, assistant, and error messages
          </p>
          <div class="bg-white rounded-xl shadow-lg overflow-hidden" style="height: 500px;">
            <.live_component
              module={MessageFeed}
              id="sample-feed"
              messages={@conversation_messages}
            />
          </div>
        </section>
        <!-- User Input (Sprint 3) -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">User Input Component</h2>
          <p class="text-gray-600 mb-4 text-sm">
            Text and image input with Enter key support and drag-and-drop uploads
          </p>
          <div class="bg-white rounded-xl shadow-lg p-6">
            <.live_component
              module={UserInputComponent}
              id="sample-input"
              placeholder="try typing a message or uploading images..."
              current_input={@current_user_input}
            />
          </div>
        </section>
        <hr class="my-12 border-gray-300" />
        <!-- User Cards -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">User Cards</h2>
          <div class="space-y-4">
            <%= for message <- @user_messages do %>
              {UserCard.render(
                assigns
                |> Map.put(:message, message)
              )}
            <% end %>
          </div>
        </section>
        <!-- Assistant Cards -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">Assistant Cards</h2>
          <div class="space-y-4">
            <%= for message <- @assistant_messages do %>
              {AssistantCard.render(
                assigns
                |> Map.put(:message, message)
              )}
            <% end %>
          </div>
        </section>
        <!-- Error Cards -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">Error Cards</h2>
          <div class="space-y-4">
            <%= for error_msg <- @error_messages do %>
              {ErrorCard.render(assigns |> Map.put(:error_message, error_msg))}
            <% end %>
          </div>
        </section>
        <!-- Interactive Info -->
        <section class="mb-12">
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <p class="text-blue-800 text-sm">
              <strong>Tip:</strong> Click on image thumbnails in user messages to expand them.
              Click the ▲ button to collapse.
            </p>
          </div>
        </section>
        <!-- Footer -->
        <footer class="text-center text-gray-500 text-sm mt-12">
          <p>
            Sprint 2, 3 & 4 Component Samples •
            <a href="/" class="text-indigo-600 hover:underline">
              Back to Home
            </a>
          </p>
        </footer>
      </div>
    </div>
    """
  end
end
