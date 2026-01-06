defmodule WireframeEditorWeb.MessageCards.UserCard do
  @moduledoc """
  Displays a user message card with optional images.

  Features:
  - User message text with markdown formatting
  - Attached images displayed as thumbnails (collapsed) or full-size (expanded)
  - Expand/collapse functionality for images
  """
  use Phoenix.Component
  import WireframeEditorWeb.MarkdownHelper
  import WireframeEditorWeb.MessageCards.Helpers

  attr :message, :map, required: true, doc: "Message map with content and metadata"
  attr :expanded_images, :any, default: MapSet.new(), doc: "Set of expanded card IDs"
  attr :card_id, :string, default: nil, doc: "Optional card ID (generated if not provided)"
  attr :on_expand, :string, default: "expand_image", doc: "Event name for expand action"
  attr :on_collapse, :string, default: "collapse_image", doc: "Event name for collapse action"
  attr :target, :any, default: nil, doc: "Event target (for LiveComponent)"

  def render(assigns) do
    # Generate card ID if not provided or nil
    card_id = assigns[:card_id] || generate_card_id(assigns.message)
    assigns = assign(assigns, :card_id, card_id)

    # Extract text, images, and tool results from content
    {text_content, image_items, tool_results} = extract_content_parts(assigns.message.content)

    # Check if this card is expanded
    expanded = MapSet.member?(assigns.expanded_images, card_id)

    assigns =
      assigns
      |> assign(:text_content, text_content)
      |> assign(:image_items, image_items)
      |> assign(:tool_results, tool_results)
      |> assign(:has_images, length(image_items) > 0)
      |> assign(:has_tool_results, length(tool_results) > 0)
      |> assign(:expanded, expanded)

    ~H"""
    <div
      class="bg-gradient-to-br from-slate-50 to-blue-50/30 p-3 border-l-[6px] border-t border-r-2 border-blue-400/60 rounded-2xl shadow-[2px_4px_12px_-2px_rgba(59,130,246,0.15)] hover:shadow-[3px_6px_16px_-2px_rgba(59,130,246,0.25)] transition-all duration-300"
      id={@card_id}
    >
      <!-- Header with label and expand/collapse button -->
      <div class="flex items-center justify-between mb-1.5">
        <div class="text-[0.6rem] font-medium text-blue-600/80 tracking-wider flex items-center gap-1.5">
          <span>you</span>
          <%= if @has_images && !@expanded do %>
            <WireframeEditorWeb.MessageCards.ImageGallery.render
              images={@image_items}
              card_id={@card_id}
              expanded={false}
              on_expand={@on_expand}
              target={@target}
            />
          <% end %>
        </div>
        <%= if @has_images && @expanded do %>
          <button
            phx-click={@on_collapse}
            phx-value-card={@card_id}
            phx-target={@target}
            class="text-blue-400/60 hover:text-blue-600 hover:bg-blue-50/50 transition-all px-2 py-1 rounded-lg text-xs"
            title="Collapse images"
          >
            ▲ collapse
          </button>
        <% end %>
      </div>
      <!-- Tool Results -->
      <%= if @has_tool_results do %>
        <div class="space-y-1.5 mb-2">
          <%= for tool_result <- @tool_results do %>
            <div class="bg-green-50/50 border border-green-200 rounded-lg p-2">
              <div class="flex items-center gap-1.5 mb-0.5">
                <svg
                  class="w-3.5 h-3.5 text-green-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span class="text-[0.65rem] font-medium text-green-900">
                  Tool Result
                </span>
              </div>
              <div class="text-[0.65rem] text-green-800 bg-white/60 p-1.5 rounded border border-green-100">
                {format_tool_result_content(tool_result)}
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
      <!-- Text content -->
      <%= if @text_content != "" do %>
        <div class="text-slate-700 text-[0.8rem] leading-snug mb-2">
          {safe_markdown_to_html(@text_content)}
        </div>
      <% end %>
      <!-- Expanded images -->
      <%= if @has_images && @expanded do %>
        <WireframeEditorWeb.MessageCards.ImageGallery.render
          images={@image_items}
          card_id={@card_id}
          expanded={true}
          on_collapse={@on_collapse}
          target={@target}
        />
      <% end %>
    </div>
    """
  end

  # Private helpers

  defp extract_content_parts(content) when is_list(content) do
    text_items =
      Enum.filter(content, fn item ->
        Map.get(item, :type) == "text" || Map.get(item, "type") == "text"
      end)

    image_items =
      Enum.filter(content, fn item ->
        Map.get(item, :type) == "image" || Map.get(item, "type") == "image"
      end)

    tool_results =
      Enum.filter(content, fn item ->
        Map.get(item, :type) == "tool_result" || Map.get(item, "type") == "tool_result"
      end)

    text_content =
      text_items
      |> Enum.map(fn item -> Map.get(item, :text) || Map.get(item, "text") || "" end)
      |> Enum.join(" ")
      |> String.trim()

    {text_content, image_items, tool_results}
  end

  defp extract_content_parts(content) when is_binary(content) do
    {content, [], []}
  end

  defp extract_content_parts(_content) do
    {"", [], []}
  end

  defp format_tool_result_content(tool_result) do
    content = Map.get(tool_result, :content) || Map.get(tool_result, "content")

    case content do
      text when is_binary(text) -> text
      _ -> inspect(content)
    end
  end
end
