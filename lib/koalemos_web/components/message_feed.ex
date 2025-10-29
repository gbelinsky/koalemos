defmodule KoalemosWeb.MessageFeed do
  @moduledoc """
  Displays a feed of messages using message card components.

  Features:
  - Renders user, assistant, and error messages with appropriate cards
  - Manages expanded state for images and content
  - Integrates with ScrollToBottom hook for auto-scrolling
  - Handles empty state gracefully
  - Deduplicates messages by metadata.id

  ## Usage

  ```heex
  <.live_component
    module={KoalemosWeb.MessageFeed}
    id="message-feed"
    messages={@messages}
  />
  ```

  ## Message Format

  Messages should be maps with:
  - `role`: "user" | "assistant" | "system"
  - `content`: String or list of content blocks
  - `metadata`: Map with `:id`, `:timestamp`, `:source` (optional)
  """
  use Phoenix.LiveComponent

  alias KoalemosWeb.MessageCards.Helpers
  alias KoalemosWeb.MessageCards.UserCard
  alias KoalemosWeb.MessageCards.AssistantCard
  alias KoalemosWeb.MessageCards.ErrorCard

  @impl true
  def render(assigns) do
    ~H"""
    <div class="message-feed h-full flex flex-col">
      <div
        class="flex-1 overflow-y-auto p-4 space-y-3"
        id={"#{@id}-container"}
        phx-hook="ScrollToBottom"
      >
        <%= if length(@messages) == 0 do %>
          <!-- Empty state -->
          <div class="h-full flex flex-col items-center justify-center text-center p-8">
            <div class="bg-gradient-to-br from-slate-50 to-gray-50/30 p-8 rounded-3xl border-l-[3px] border-r-[2px] border-t border-slate-300/50 shadow-[2px_3px_12px_-2px_rgba(148,163,184,0.15)] max-w-md">
              <div class="text-6xl mb-4 opacity-40">💭</div>
              <h3 class="text-lg font-medium text-slate-700/80 mb-2 tracking-wide">
                no messages yet
              </h3>
              <p class="text-sm text-slate-600/70 leading-relaxed">
                the conversation will appear here once you send a message. we're waiting patiently (but not too patiently).
              </p>
            </div>
          </div>
        <% else %>
          <!-- Message cards -->
          <%= for message <- @deduplicated_messages do %>
            <% card_id = Helpers.generate_card_id(message) %>
            <% role = Map.get(message, :role) || Map.get(message, "role") %>
            <% source = get_in(message, [:metadata, :source]) || get_in(message, ["metadata", "source"]) %>
            <%= cond do %>
              <% source == :error || source == "error" -> %>
                <ErrorCard.render error_message={extract_error_message(message)} card_id={card_id} />
              <% role == "user" || role == :user || source == :user || source == "user" -> %>
                <UserCard.render
                  message={message}
                  expanded_images={@expanded_images}
                  card_id={card_id}
                  on_expand="expand_image"
                  on_collapse="collapse_image"
                  target={@myself}
                />
              <% true -> %>
                <AssistantCard.render message={message} card_id={card_id} />
            <% end %>
          <% end %>
          <!-- Thinking indicator when AI is processing -->
          <%= if @current_step == :llm_request or @current_step == "llm_request" do %>
            <div class="flex items-center gap-3 px-4 py-3 bg-gradient-to-br from-indigo-50/50 to-blue-50/30 rounded-2xl border-l-[3px] border-indigo-300/40 shadow-sm">
              <div class="flex gap-1.5">
                <div class="w-2 h-2 bg-indigo-400 rounded-full animate-bounce" style="animation-delay: 0ms;"></div>
                <div class="w-2 h-2 bg-indigo-400 rounded-full animate-bounce" style="animation-delay: 150ms;"></div>
                <div class="w-2 h-2 bg-indigo-400 rounded-full animate-bounce" style="animation-delay: 300ms;"></div>
              </div>
              <span class="text-sm text-indigo-600/80 font-medium">thinking...</span>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       expanded_images: MapSet.new(),
       messages: [],
       deduplicated_messages: [],
       current_step: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Deduplicate messages by metadata.id
    messages = Map.get(assigns, :messages, [])
    deduplicated = deduplicate_messages(messages)
    current_step = Map.get(assigns, :current_step)

    {:ok,
     assign(socket,
       messages: messages,
       deduplicated_messages: deduplicated,
       current_step: current_step
     )}
  end

  @impl true
  def handle_event("expand_image", %{"card" => card_id}, socket) do
    expanded_images = MapSet.put(socket.assigns.expanded_images, card_id)
    {:noreply, assign(socket, :expanded_images, expanded_images)}
  end

  @impl true
  def handle_event("collapse_image", %{"card" => card_id}, socket) do
    expanded_images = MapSet.delete(socket.assigns.expanded_images, card_id)
    {:noreply, assign(socket, :expanded_images, expanded_images)}
  end

  # Private Functions

  # Made public for testing
  def deduplicate_messages(messages) do
    messages
    |> Enum.reduce({[], MapSet.new()}, fn message, {acc, seen_ids} ->
      msg_id =
        get_in(message, [:metadata, :id]) ||
          get_in(message, ["metadata", "id"]) ||
          "fallback_#{:erlang.phash2(message)}"

      if MapSet.member?(seen_ids, msg_id) do
        {acc, seen_ids}
      else
        {acc ++ [message], MapSet.put(seen_ids, msg_id)}
      end
    end)
    |> elem(0)
  end

  # Made public for testing
  def extract_error_message(message) do
    content = Map.get(message, :content) || Map.get(message, "content")

    cond do
      is_binary(content) -> content
      is_list(content) -> Enum.map_join(content, " ", &extract_text_from_block/1)
      true -> inspect(content)
    end
  end

  defp extract_text_from_block(block) when is_binary(block), do: block

  defp extract_text_from_block(block) when is_map(block) do
    Map.get(block, :text) || Map.get(block, "text") || ""
  end

  defp extract_text_from_block(_), do: ""
end
