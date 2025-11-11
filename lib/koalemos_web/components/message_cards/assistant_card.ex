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

    # Extract text content and tool calls
    {text_content, tool_calls} = extract_text_and_tool_calls(assigns.message.content)

    assigns =
      assigns
      |> assign(:text_content, text_content)
      |> assign(:tool_calls, tool_calls)

    ~H"""
    <div
      class="bg-gradient-to-br from-white to-indigo-50/20 p-4 border-r-[6px] border-t border-l-2 border-indigo-400/60 rounded-2xl shadow-[-2px_4px_12px_-2px_rgba(99,102,241,0.15)] hover:shadow-[-3px_6px_16px_-2px_rgba(99,102,241,0.25)] transition-all duration-300"
      id={@card_id}
    >
      <!-- Header -->
      <div class="text-[0.65rem] font-medium text-indigo-600/70 tracking-wider mb-2.5">
        koalemos
      </div>
      <!-- Tool Calls (if any) -->
      <%= if length(@tool_calls) > 0 do %>
        <div class="mt-3 space-y-2">
          <%= for tool_call <- @tool_calls do %>
            <div class="bg-indigo-50/50 border border-indigo-200 rounded-lg p-3">
              <div class="flex items-center gap-2 mb-1">
                <svg class="w-4 h-4 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                </svg>
                <span class="text-sm font-medium text-indigo-900">
                  <%= Map.get(tool_call, :name) || Map.get(tool_call, "name") %>
                </span>
              </div>
              <div class="text-xs text-indigo-700 font-mono bg-white/60 p-2 rounded border border-indigo-100">
                <%= format_tool_input(Map.get(tool_call, :input) || Map.get(tool_call, "input")) %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
      <!-- Content with markdown -->
      <%= if @text_content != "" do %>
        <div class="text-slate-700 text-[0.9rem] leading-relaxed prose prose-sm max-w-none
                    prose-p:my-2 prose-p:leading-relaxed
                    prose-ul:my-2 prose-ul:list-disc prose-ul:pl-5
                    prose-ol:my-2 prose-ol:list-decimal prose-ol:pl-5
                    prose-li:my-1
                    prose-code:bg-slate-100 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:font-mono prose-code:text-slate-900
                    prose-pre:bg-slate-800 prose-pre:text-slate-100 prose-pre:p-3 prose-pre:rounded-lg prose-pre:overflow-x-auto prose-pre:my-3
                    [&_pre_code]:bg-transparent [&_pre_code]:p-0 [&_pre_code]:text-slate-100
                    prose-a:text-indigo-600 prose-a:underline hover:prose-a:text-indigo-800
                    prose-strong:font-semibold prose-strong:text-slate-900
                    prose-em:italic
                    prose-h1:text-xl prose-h1:font-bold prose-h1:mt-4 prose-h1:mb-2
                    prose-h2:text-lg prose-h2:font-bold prose-h2:mt-3 prose-h2:mb-2
                    prose-h3:text-base prose-h3:font-semibold prose-h3:mt-2 prose-h3:mb-1
                    prose-blockquote:border-l-4 prose-blockquote:border-slate-300 prose-blockquote:pl-4 prose-blockquote:italic prose-blockquote:text-slate-600">
          <%= safe_markdown_to_html(@text_content) %>
        </div>
      <% end %>
    </div>
    """
  end

  # Private helpers

  defp extract_text_and_tool_calls(content) when is_list(content) do
    text_items =
      Enum.filter(content, fn item ->
        Map.get(item, :type) == "text" || Map.get(item, "type") == "text"
      end)

    tool_use_items =
      Enum.filter(content, fn item ->
        Map.get(item, :type) == "tool_use" || Map.get(item, "type") == "tool_use"
      end)

    text_content =
      text_items
      |> Enum.map(fn item -> Map.get(item, :text) || Map.get(item, "text") || "" end)
      |> Enum.join(" ")
      |> String.trim()

    {text_content, tool_use_items}
  end

  defp extract_text_and_tool_calls(content) when is_binary(content) do
    {content, []}
  end

  defp extract_text_and_tool_calls(_content) do
    {"", []}
  end

  defp format_tool_input(input) when is_map(input) do
    input
    |> Enum.map(fn {k, v} ->
      key = if is_atom(k), do: Atom.to_string(k), else: k
      value = if is_binary(v) and String.length(v) > 50, do: String.slice(v, 0, 50) <> "...", else: inspect(v)
      "#{key}: #{value}"
    end)
    |> Enum.join(", ")
  end

  defp format_tool_input(input) do
    inspect(input)
  end
end
