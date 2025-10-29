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
      <div class="text-slate-700 text-[0.9rem] leading-relaxed prose prose-sm max-w-none
                  prose-p:my-2 prose-p:leading-relaxed
                  prose-ul:my-2 prose-ul:list-disc prose-ul:pl-5
                  prose-ol:my-2 prose-ol:list-decimal prose-ol:pl-5
                  prose-li:my-1
                  prose-code:bg-slate-100 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:font-mono
                  prose-pre:bg-slate-800 prose-pre:text-slate-100 prose-pre:p-3 prose-pre:rounded-lg prose-pre:overflow-x-auto
                  prose-a:text-indigo-600 prose-a:underline hover:prose-a:text-indigo-800
                  prose-strong:font-semibold prose-strong:text-slate-900
                  prose-em:italic
                  prose-h1:text-xl prose-h1:font-bold prose-h1:mt-4 prose-h1:mb-2
                  prose-h2:text-lg prose-h2:font-bold prose-h2:mt-3 prose-h2:mb-2
                  prose-h3:text-base prose-h3:font-semibold prose-h3:mt-2 prose-h3:mb-1
                  prose-blockquote:border-l-4 prose-blockquote:border-slate-300 prose-blockquote:pl-4 prose-blockquote:italic prose-blockquote:text-slate-600">
        <%= safe_markdown_to_html(@text_content) %>
      </div>
    </div>
    """
  end
end
