defmodule KoalemosWeb.MessageCards.AssistantCard do
  @moduledoc """
  Displays an AI assistant message card.

  Features:
  - AI response text with markdown formatting
  - Clean, simple styling
  """
  use Phoenix.Component
  import KoalemosWeb.MarkdownHelper
  import KoalemosWeb.MessageCards.Helpers

  attr :message, :map, required: true, doc: "Message map with content and metadata"
  attr :card_id, :string, default: nil, doc: "Optional card ID (generated if not provided)"

  def render(assigns) do
    # Generate card ID if not provided or nil
    card_id = assigns[:card_id] || generate_card_id(assigns.message)
    assigns = assign(assigns, :card_id, card_id)

    # Extract text content
    text_content = extract_text_content(assigns.message.content)

    assigns = assign(assigns, :text_content, text_content)

    ~H"""
    <div
      class="bg-white p-3 border-l-4 border-l-indigo-400 rounded-md shadow-sm hover:shadow-md transition-shadow duration-200"
      id={@card_id}
    >
      <!-- Header -->
      <div class="text-xs font-semibold text-indigo-600 uppercase tracking-wide mb-2">
        ASSISTANT
      </div>
      <!-- Content with markdown -->
      <div class="text-gray-700 text-sm leading-relaxed">
        <%= safe_markdown_to_html(@text_content) %>
      </div>
    </div>
    """
  end
end
