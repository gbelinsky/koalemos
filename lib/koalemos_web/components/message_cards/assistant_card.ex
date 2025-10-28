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
      class="bg-gradient-to-br from-white to-indigo-50/20 p-4 border-r-[6px] border-t border-l-2 border-indigo-400/60 rounded-2xl shadow-[-2px_4px_12px_-2px_rgba(99,102,241,0.15)] hover:shadow-[-3px_6px_16px_-2px_rgba(99,102,241,0.25)] transition-all duration-300"
      id={@card_id}
    >
      <!-- Header -->
      <div class="text-[0.65rem] font-medium text-indigo-600/70 tracking-wider mb-2.5">
        koalemos
      </div>
      <!-- Content with markdown -->
      <div class="text-slate-700 text-[0.9rem] leading-relaxed">
        <%= safe_markdown_to_html(@text_content) %>
      </div>
    </div>
    """
  end
end
