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
  alias KoalemosWeb.MessageCards.ThinkingCard

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
          <!-- Iterate over grouped items (messages and thinking chains) -->
          <%= for {item_data, idx} <- Enum.with_index(@grouped_items) do %>
            <% {type, data} = item_data %>
            <%= case type do %>
              <% :message -> %>
                <% message = data %>
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
              <% :thinking_chain -> %>
                <% chain_messages = data %>
                <% chain_id = "thinking-chain-#{idx}" %>
                <ThinkingCard.render
                  messages={chain_messages}
                  card_id={chain_id}
                  expanded={MapSet.member?(@expanded_thinking, chain_id)}
                  on_toggle="toggle_thinking"
                  target={@myself}
                />
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
          <!-- Error card at bottom (full width) -->
          <%= if @last_error do %>
            <ErrorCard.render error_message={@last_error} card_id="routine-error" />
          <% end %>
          <!-- Completion card at bottom (full width) -->
          <%= if @status == :completed && !@last_error do %>
            <div class="bg-green-50 border-2 border-green-300 rounded-lg p-4 shadow-sm">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0">
                  <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="text-sm font-semibold text-green-800 mb-1">Routine Completed</h3>
                  <p class="text-sm text-green-700">The conversation has ended successfully.</p>
                </div>
              </div>
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
       expanded_thinking: MapSet.new(),
       messages: [],
       deduplicated_messages: [],
       grouped_items: [],
       current_step: nil,
       status: :running,
       last_error: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Deduplicate messages by metadata.id
    messages = Map.get(assigns, :messages, [])
    deduplicated = deduplicate_messages(messages)

    # Group messages into renderable items (regular messages and thinking chains)
    grouped_items = group_messages_into_items(deduplicated)

    current_step = Map.get(assigns, :current_step)
    status = Map.get(assigns, :status, :running)
    last_error = Map.get(assigns, :last_error)

    {:ok,
     assign(socket,
       messages: messages,
       deduplicated_messages: deduplicated,
       grouped_items: grouped_items,
       current_step: current_step,
       status: status,
       last_error: last_error
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

  @impl true
  def handle_event("toggle_thinking", %{"card" => card_id}, socket) do
    expanded_thinking = socket.assigns.expanded_thinking

    updated_set =
      if MapSet.member?(expanded_thinking, card_id) do
        MapSet.delete(expanded_thinking, card_id)
      else
        MapSet.put(expanded_thinking, card_id)
      end

    {:noreply, assign(socket, :expanded_thinking, updated_set)}
  end

  # Private Functions

  # Group messages into renderable items: regular messages and thinking chains
  # A thinking chain is a sequence of consecutive thinking messages
  # Chains are split when thought_number resets to 1
  # Text from all messages in a chain is collected and shown before the thinking card
  defp group_messages_into_items(messages) do
    # First pass: collect all tool_use_ids for sequential_thinking
    thinking_tool_ids = collect_thinking_tool_ids(messages)

    # Second pass: group messages
    {items, current_thinking, _last_thought_num} =
      Enum.reduce(messages, {[], [], nil}, fn message, {items, current_thinking, last_thought_num} ->
        if is_thinking_message?(message, thinking_tool_ids) do
          thought_num = extract_thought_number(message)

          # Check if this is a chain reset (thought_number went back to 1 after previous chain)
          is_chain_reset = thought_num == 1 && last_thought_num != nil && last_thought_num > 1

          if is_chain_reset do
            # End previous chain - emit collected text + thinking card
            items = emit_thinking_chain(items, current_thinking)

            # Start new chain with this message
            {items, [message], thought_num}
          else
            # Continue current chain
            {items, current_thinking ++ [message], thought_num}
          end
        else
          # Regular message - end any current chain first
          items = emit_thinking_chain(items, current_thinking)

          {items ++ [{:message, message}], [], nil}
        end
      end)

    # Handle any remaining thinking chain
    emit_thinking_chain(items, current_thinking)
  end

  # Emit a thinking chain: extract all text, show text cards first, then thinking card
  defp emit_thinking_chain(items, []), do: items

  defp emit_thinking_chain(items, thinking_messages) do
    # Collect all text from all messages in the chain
    all_text =
      thinking_messages
      |> Enum.map(&extract_text_from_message/1)
      |> Enum.reject(&(&1 == ""))

    # Add text messages first
    items =
      Enum.reduce(all_text, items, fn text, acc ->
        # Use first message's metadata for the text card
        text_message = create_text_only_message(List.first(thinking_messages), text)
        acc ++ [{:message, text_message}]
      end)

    # Then add the thinking chain
    items ++ [{:thinking_chain, thinking_messages}]
  end

  defp collect_thinking_tool_ids(messages) do
    messages
    |> Enum.flat_map(fn message ->
      content = Map.get(message, :content) || Map.get(message, "content")

      case content do
        content when is_list(content) ->
          content
          |> Enum.filter(fn item ->
            type = Map.get(item, :type) || Map.get(item, "type")
            name = Map.get(item, :name) || Map.get(item, "name")

            (type == "tool_use" || type == :tool_use) &&
              (name == "sequential_thinking" || name == :sequential_thinking)
          end)
          |> Enum.map(fn item ->
            Map.get(item, :id) || Map.get(item, "id")
          end)

        _ ->
          []
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp is_thinking_message?(message, thinking_tool_ids) do
    content = Map.get(message, :content) || Map.get(message, "content")

    case content do
      content when is_list(content) ->
        Enum.any?(content, fn item ->
          type = Map.get(item, :type) || Map.get(item, "type")
          name = Map.get(item, :name) || Map.get(item, "name")
          tool_use_id = Map.get(item, :tool_use_id) || Map.get(item, "tool_use_id")

          # Check if it's a tool_use for sequential_thinking
          is_thinking_tool_use = (type == "tool_use" || type == :tool_use) &&
            (name == "sequential_thinking" || name == :sequential_thinking)

          # Check if it's a tool_result that references a thinking tool
          is_thinking_tool_result = (type == "tool_result" || type == :tool_result) &&
            MapSet.member?(thinking_tool_ids, tool_use_id)

          is_thinking_tool_use || is_thinking_tool_result
        end)

      _ ->
        false
    end
  end

  defp extract_thought_number(message) do
    content = Map.get(message, :content) || Map.get(message, "content")

    case content do
      content when is_list(content) ->
        Enum.find_value(content, fn item ->
          type = Map.get(item, :type) || Map.get(item, "type")
          name = Map.get(item, :name) || Map.get(item, "name")

          if (type == "tool_use" || type == :tool_use) &&
               (name == "sequential_thinking" || name == :sequential_thinking) do
            input = Map.get(item, :input) || Map.get(item, "input") || %{}
            Map.get(input, "thought_number") || Map.get(input, :thought_number)
          end
        end)

      _ ->
        nil
    end
  end

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

  # Extract text content from a message
  defp extract_text_from_message(message) do
    content = Map.get(message, :content) || Map.get(message, "content")

    case content do
      content when is_list(content) ->
        content
        |> Enum.filter(fn item ->
          type = Map.get(item, :type) || Map.get(item, "type")
          type == "text" || type == :text
        end)
        |> Enum.map(fn item ->
          Map.get(item, :text) || Map.get(item, "text") || ""
        end)
        |> Enum.join("\n")
        |> String.trim()

      content when is_binary(content) ->
        content

      _ ->
        ""
    end
  end

  # Create a text-only version of a message (strips out tool_use blocks)
  defp create_text_only_message(message, text_content) do
    %{
      role: Map.get(message, :role) || Map.get(message, "role"),
      content: text_content,
      metadata: Map.get(message, :metadata) || Map.get(message, "metadata") || %{}
    }
  end
end
