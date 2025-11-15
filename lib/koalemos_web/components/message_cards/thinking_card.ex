defmodule KoalemosWeb.MessageCards.ThinkingCard do
  @moduledoc """
  Displays a consolidated thinking card for sequential_thinking tool usage.

  Features:
  - Shows progress: "Thinking... (3/10 thoughts)"
  - Expandable to show all thoughts in the chain
  - Updates dynamically as thoughts are added
  - Extracts thoughts from tool_use and tool_result messages
  """
  use Phoenix.Component
  import KoalemosWeb.MarkdownHelper

  attr :messages, :list, required: true, doc: "All messages to extract thinking from"
  attr :card_id, :string, default: "thinking-card", doc: "Card ID for expand/collapse"
  attr :expanded, :boolean, default: false, doc: "Whether card is expanded"
  attr :on_toggle, :string, default: "toggle_thinking", doc: "Event name for toggle"
  attr :target, :any, default: nil, doc: "Event target (for LiveComponent)"

  def render(assigns) do
    # Extract all thinking tool calls and results
    thoughts = extract_thoughts(assigns.messages)

    # Determine current status
    {current, total, complete} = get_progress(thoughts)

    assigns =
      assigns
      |> assign(:thoughts, thoughts)
      |> assign(:current, current)
      |> assign(:total, total)
      |> assign(:complete, complete)
      |> assign(:has_thoughts, length(thoughts) > 0)

    ~H"""
    <%= if @has_thoughts do %>
      <div
        class="bg-gradient-to-br from-teal-50 to-blue-50/30 p-4 border-l-[6px] border-t border-r-2 border-teal-400/60 rounded-2xl shadow-[2px_4px_12px_-2px_rgba(20,184,166,0.15)] hover:shadow-[3px_6px_16px_-2px_rgba(20,184,166,0.25)] transition-all duration-300"
        id={@card_id}
      >
        <!-- Clickable Header with progress -->
        <button
          phx-click={@on_toggle}
          phx-value-card={@card_id}
          phx-target={@target}
          class="w-full text-left"
        >
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <div class="text-[0.65rem] font-medium text-teal-600/80 tracking-wider">
                sequential thinking
              </div>
              <%= if @complete do %>
                <span class="text-xs text-teal-700 bg-teal-100 px-2 py-0.5 rounded-full">
                  {@total} Thoughts
                </span>
              <% else %>
                <span class="text-xs text-blue-700 bg-blue-100 px-2 py-0.5 rounded-full animate-pulse">
                  Thinking...
                </span>
              <% end %>
              <span class="text-xs text-teal-600/70">
                {@current} / {@total}
              </span>
            </div>
            <div class="text-teal-400/60 hover:text-teal-600 transition-all text-sm px-2">
              {if @expanded, do: "▲", else: "▼"}
            </div>
          </div>
          <!-- Progress bar (only when not complete) -->
          <%= if !@complete do %>
            <div class="w-full bg-teal-100 rounded-full h-2">
              <div
                class="bg-teal-500 h-2 rounded-full transition-all duration-500"
                style={"width: #{progress_percentage(@current, @total)}%"}
              >
              </div>
            </div>
          <% end %>
        </button>

        <%= if @expanded do %>
          <!-- Expanded: Show all thoughts -->
          <div class="space-y-2 mt-3">
            <%= for thought <- @thoughts do %>
              <div class="bg-white/60 border border-teal-200 rounded-lg p-3">
                <div class="flex items-start gap-2">
                  <div class="flex-shrink-0 w-6 h-6 bg-teal-100 rounded-full flex items-center justify-center">
                    <span class="text-xs font-bold text-teal-700">{thought.number}</span>
                  </div>
                  <div class="flex-1">
                    <div class="text-sm text-slate-700 leading-relaxed prose prose-sm prose-slate max-w-none
                                prose-p:my-1 prose-p:leading-relaxed
                                prose-headings:mt-2 prose-headings:mb-1
                                prose-ul:my-1 prose-ol:my-1
                                prose-li:my-0.5
                                prose-code:text-xs prose-code:bg-slate-100 prose-code:px-1 prose-code:py-0.5 prose-code:rounded
                                prose-pre:my-2 prose-pre:bg-slate-100
                                prose-strong:font-semibold prose-strong:text-slate-900">
                      {safe_markdown_to_html(thought.text)}
                    </div>
                    <%= if thought.revision do %>
                      <span class="text-xs text-amber-600 mt-1 inline-block">
                        🔄 Revision of thought {thought.revises_thought}
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  # Private helpers

  defp extract_thoughts(messages) do
    messages
    |> Enum.flat_map(fn message ->
      case message.content do
        content when is_list(content) ->
          # Extract from tool_use blocks
          Enum.filter(content, fn item ->
            name = Map.get(item, :name) || Map.get(item, "name")
            name == "sequential_thinking"
          end)
          |> Enum.map(fn tool_call ->
            input = Map.get(tool_call, :input) || Map.get(tool_call, "input") || %{}

            # Extract and normalize next_thought_needed to boolean
            next_needed =
              case Map.get(input, "next_thought_needed") || Map.get(input, :next_thought_needed) do
                false -> false
                "false" -> false
                nil -> false
                _ -> true
              end

            %{
              text: Map.get(input, "thought") || Map.get(input, :thought),
              number: Map.get(input, "thought_number") || Map.get(input, :thought_number),
              total: Map.get(input, "total_thoughts") || Map.get(input, :total_thoughts),
              next_needed: next_needed,
              revision: Map.get(input, "is_revision") || Map.get(input, :is_revision) || false,
              revises_thought:
                Map.get(input, "revises_thought") || Map.get(input, :revises_thought)
            }
          end)

        _ ->
          []
      end
    end)
    |> Enum.reject(&is_nil(&1.text))
  end

  defp get_progress(thoughts) do
    case thoughts do
      [] ->
        {0, 0, false}

      thoughts ->
        last_thought = List.last(thoughts)
        current = last_thought.number || length(thoughts)
        total = last_thought.total || current
        complete = !last_thought.next_needed

        {current, total, complete}
    end
  end

  defp progress_percentage(current, total) when total > 0 do
    min(100, round(current / total * 100))
  end

  defp progress_percentage(_current, _total), do: 0
end
