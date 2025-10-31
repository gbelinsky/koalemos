defmodule Koalemos.Caches.DOMStateCache do
  @moduledoc """
  GenServer for storing live DOM state snapshots from wireframe previews.

  Stores the current live DOM tree for each routine, allowing agents
  to see how their wireframes actually look after JavaScript interactions.

  ## Usage

      alias Koalemos.Caches.DOMStateCache

      # Store a DOM snapshot
      dom_update = %{
        "liveDOMTree" => %{"tag" => "div", "id" => "root", ...},
        "timestamp" => 1730400000000,
        "changeType" => "mutation"
      }
      DOMStateCache.add_dom_state("routine-123", dom_update)

      # Retrieve current DOM state
      dom_state = DOMStateCache.get_dom_state("routine-123")

      # Clear DOM state
      DOMStateCache.clear_dom_state("routine-123")

      # Clear all DOM states (useful for testing)
      DOMStateCache.clear_all()

  ## Storage Format

  DOM states are stored as:
  ```
  %{
    routine_id => %{
      live_dom_tree: %{tag: ..., id: ..., children: [...]},
      timestamp: integer,
      change_type: string,
      cached_at: DateTime
    }
  }
  ```

  ## DOM Tree Structure

  The DOM tree uses atom keys for efficiency:
  ```
  %{
    tag: "div",
    id: "my-element",
    classes: ["container", "active"],
    attributes: %{"data-value" => "123"},
    content: "text content",
    children: [%{tag: "span", ...}, ...]
  }
  ```
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Start the DOMStateCache GenServer.

  Registered as a named process for easy access throughout the application.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Add or update the live DOM state for a routine.

  Converts JavaScript DOM tree (string keys) to Elixir format (atom keys).

  ## Parameters

  - `routine_id` - The routine identifier (string)
  - `dom_update` - Map with keys: "liveDOMTree", "timestamp", "changeType"

  ## Returns

  `:ok`

  ## Examples

      iex> dom_update = %{
      ...>   "liveDOMTree" => %{"tag" => "div", "id" => "root"},
      ...>   "timestamp" => 1730400000000,
      ...>   "changeType" => "mutation"
      ...> }
      iex> DOMStateCache.add_dom_state("routine-123", dom_update)
      :ok
  """
  @spec add_dom_state(String.t(), map()) :: :ok
  def add_dom_state(routine_id, dom_update) when is_binary(routine_id) and is_map(dom_update) do
    GenServer.cast(__MODULE__, {:add_dom_state, routine_id, dom_update})
  end

  @doc """
  Get the current live DOM state for a routine.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  - Map with DOM state data if exists
  - `nil` if no DOM state for this routine

  ## Examples

      iex> dom_update = %{
      ...>   "liveDOMTree" => %{"tag" => "div"},
      ...>   "timestamp" => 123
      ...> }
      iex> DOMStateCache.add_dom_state("routine-123", dom_update)
      iex> state = DOMStateCache.get_dom_state("routine-123")
      iex> state.live_dom_tree.tag
      "div"

      iex> DOMStateCache.get_dom_state("nonexistent")
      nil
  """
  @spec get_dom_state(String.t()) :: map() | nil
  def get_dom_state(routine_id) when is_binary(routine_id) do
    GenServer.call(__MODULE__, {:get_dom_state, routine_id})
  end

  @doc """
  Clear the DOM state for a given routine.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  `:ok` (always succeeds, even if no DOM state exists)

  ## Examples

      iex> DOMStateCache.clear_dom_state("routine-123")
      :ok
  """
  @spec clear_dom_state(String.t()) :: :ok
  def clear_dom_state(routine_id) when is_binary(routine_id) do
    GenServer.cast(__MODULE__, {:clear_dom_state, routine_id})
  end

  @doc """
  Clear all DOM states.

  Useful for testing or manual cleanup.

  ## Returns

  `:ok`

  ## Examples

      iex> DOMStateCache.clear_all()
      :ok
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end

  @doc """
  Get statistics about the DOM state cache.

  ## Returns

  Map with cache statistics:
  - `total_routines` - Number of routines with cached DOM states

  ## Examples

      iex> DOMStateCache.get_stats()
      %{total_routines: 0}
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("[DOMStateCache] Starting")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:add_dom_state, routine_id, dom_update}, state) do
    # Convert the JavaScript DOM tree (string keys) to Elixir format (atom keys)
    converted_tree = convert_js_dom_tree(dom_update["liveDOMTree"])

    dom_state = %{
      live_dom_tree: converted_tree,
      timestamp: dom_update["timestamp"],
      change_type: dom_update["changeType"] || "unknown",
      cached_at: DateTime.utc_now()
    }

    new_state = Map.put(state, routine_id, dom_state)
    Logger.debug("[DOMStateCache] Stored DOM state for routine #{routine_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:clear_dom_state, routine_id}, state) do
    new_state = Map.delete(state, routine_id)
    Logger.debug("[DOMStateCache] Cleared DOM state for routine #{routine_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear_all, _state) do
    Logger.debug("[DOMStateCache] Cleared all DOM states")
    {:noreply, %{}}
  end

  @impl true
  def handle_call({:get_dom_state, routine_id}, _from, state) do
    dom_state = Map.get(state, routine_id)
    {:reply, dom_state, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_routines: map_size(state)
    }

    {:reply, stats, state}
  end

  # Private Helpers

  @doc """
  Convert JavaScript DOM tree (string keys) to Elixir format (atom keys).

  Recursively processes the tree structure, converting all nodes and children.

  ## Parameters

  - `js_tree` - JavaScript DOM node with string keys, or nil

  ## Returns

  - Converted DOM node with atom keys
  - `nil` if input is nil or invalid

  ## Examples

      iex> js_tree = %{
      ...>   "tag" => "div",
      ...>   "id" => "root",
      ...>   "classes" => ["container"],
      ...>   "children" => [%{"tag" => "span"}]
      ...> }
      iex> DOMStateCache.convert_js_dom_tree(js_tree)
      %{
        tag: "div",
        id: "root",
        classes: ["container"],
        attributes: %{},
        content: nil,
        children: [%{tag: "span", ...}]
      }
  """
  def convert_js_dom_tree(nil), do: nil

  def convert_js_dom_tree(js_tree) when is_map(js_tree) do
    %{
      tag: js_tree["tag"],
      id: js_tree["id"],
      classes: js_tree["classes"] || [],
      attributes: js_tree["attributes"] || %{},
      content: js_tree["content"],
      children: convert_js_children(js_tree["children"] || [])
    }
  end

  def convert_js_dom_tree(_), do: nil

  defp convert_js_children(children) when is_list(children) do
    children
    |> Enum.map(&convert_js_dom_tree/1)
    |> Enum.filter(&(&1 != nil))
  end

  defp convert_js_children(_), do: []
end
