defmodule KoalemosWeb.SamplesLive do
  use KoalemosWeb, :live_view
  alias KoalemosWeb.MessageCards.UserCard
  alias KoalemosWeb.MessageCards.AssistantCard
  alias KoalemosWeb.MessageCards.ErrorCard

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       expanded_images: MapSet.new(),
       page_title: "Component Samples",
       user_messages: create_user_messages(),
       assistant_messages: create_assistant_messages(),
       error_messages: create_error_messages()
     )}
  end

  defp create_user_messages do
    [
      %{
        content: "Hello! This is a simple user message.",
        metadata: %{timestamp: 1730000001}
      },
      %{
        content: "I can use **bold** and _italic_ text, plus [links](https://example.com)!",
        metadata: %{timestamp: 1730000002}
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
        metadata: %{timestamp: 1730000003}
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
        metadata: %{timestamp: 1730000007}
      }
    ]
  end

  defp create_assistant_messages do
    [
      %{
        content: "I'm here to help! Let me know what you need.",
        metadata: %{timestamp: 1730000004}
      },
      %{
        content:
          "I can format responses with **numbered lists**, _emphasis_, and `code snippets`. Here's code: ```elixir\ndefmodule Example do\n  def hello, do: :world\nend\n```",
        metadata: %{timestamp: 1730000005}
      },
      %{
        content:
          "This is a longer response to show how text wraps and flows naturally. The card expands to fit content while maintaining readability.",
        metadata: %{timestamp: 1730000006}
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
    <div class="min-h-screen bg-gray-100 p-8">
      <div class="max-w-4xl mx-auto">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Message Card Components</h1>
        <p class="text-gray-600 mb-8">
          Demo of all message card components from Sprint 2
        </p>
        <!-- User Cards -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">User Cards</h2>
          <div class="space-y-4">
            <%= for message <- @user_messages do %>
              <%= UserCard.render(
                assigns
                |> Map.put(:message, message)
              ) %>
            <% end %>
          </div>
        </section>
        <!-- Assistant Cards -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">Assistant Cards</h2>
          <div class="space-y-4">
            <%= for message <- @assistant_messages do %>
              <%= AssistantCard.render(
                assigns
                |> Map.put(:message, message)
              ) %>
            <% end %>
          </div>
        </section>
        <!-- Error Cards -->
        <section class="mb-12">
          <h2 class="text-xl font-semibold text-gray-800 mb-4">Error Cards</h2>
          <div class="space-y-4">
            <%= for error_msg <- @error_messages do %>
              <%= ErrorCard.render(assigns |> Map.put(:error_message, error_msg)) %>
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
            Sprint 2 Component Samples • <a href="/" class="text-indigo-600 hover:underline">
              Back to Home
            </a>
          </p>
        </footer>
      </div>
    </div>
    """
  end
end
