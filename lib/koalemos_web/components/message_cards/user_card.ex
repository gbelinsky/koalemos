defmodule KoalemosWeb.MessageCards.UserCard do
  @moduledoc """
  Displays a user message card with optional images.

  Features:
  - User message text with markdown formatting
  - Attached images displayed as thumbnails (collapsed) or full-size (expanded)
  - Expand/collapse functionality for images
  """
  use Phoenix.Component
  import KoalemosWeb.MarkdownHelper
  import KoalemosWeb.MessageCards.Helpers

  attr :message, :map, required: true, doc: "Message map with content and metadata"
  attr :expanded_images, :any, default: MapSet.new(), doc: "Set of expanded card IDs"
  attr :card_id, :string, default: nil, doc: "Optional card ID (generated if not provided)"

  def render(assigns) do
    # Generate card ID if not provided or nil
    card_id = assigns[:card_id] || generate_card_id(assigns.message)
    assigns = assign(assigns, :card_id, card_id)

    # Extract text and images from content
    {text_content, image_items} = extract_text_and_images(assigns.message.content)

    # Check if this card is expanded
    expanded = MapSet.member?(assigns.expanded_images, card_id)

    assigns =
      assigns
      |> assign(:text_content, text_content)
      |> assign(:image_items, image_items)
      |> assign(:has_images, length(image_items) > 0)
      |> assign(:expanded, expanded)

    ~H"""
    <div
      class="bg-gray-50 p-3 border-l-4 border-l-blue-400 rounded-md shadow-sm hover:shadow-md transition-shadow duration-200"
      id={@card_id}
    >
      <!-- Header with label and expand/collapse button -->
      <div class="flex items-center justify-between mb-2">
        <div class="text-xs font-semibold text-blue-600 uppercase tracking-wide flex items-center gap-2">
          <span>USER</span>
          <%= if @has_images && !@expanded do %>
            <KoalemosWeb.MessageCards.ImageGallery.render
              images={@image_items}
              card_id={@card_id}
              expanded={false}
              on_expand="expand_image"
            />
          <% end %>
        </div>
        <%= if @has_images && @expanded do %>
          <button
            phx-click="collapse_image"
            phx-value-card={@card_id}
            class="text-gray-400 hover:text-gray-600 transition-colors text-sm"
            title="Collapse images"
          >
            ▲
          </button>
        <% end %>
      </div>
      <!-- Text content -->
      <%= if @text_content != "" do %>
        <div class="text-gray-700 text-sm leading-relaxed mb-2">
          <%= safe_markdown_to_html(@text_content) %>
        </div>
      <% end %>
      <!-- Expanded images -->
      <%= if @has_images && @expanded do %>
        <KoalemosWeb.MessageCards.ImageGallery.render
          images={@image_items}
          card_id={@card_id}
          expanded={true}
          on_collapse="collapse_image"
        />
      <% end %>
    </div>
    """
  end
end
