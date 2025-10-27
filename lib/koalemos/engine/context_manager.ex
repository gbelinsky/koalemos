defmodule Koalemos.Engine.ContextManager do
  @moduledoc """
  Manages context updates for routine execution using a diff-based approach.

  The ContextManager applies atomic operations to a context map, with conflict
  detection and validation. This allows steps in a routine to modify the
  execution context in a controlled and traceable way.

  ## Diff Operations

  ### Add
  Adds new keys to the context. Fails if any key already exists.

      iex> ContextManager.apply_diff(%{}, [{:add, %{user: "alice"}}])
      {:ok, %{user: "alice"}}

      iex> ContextManager.apply_diff(%{user: "bob"}, [{:add, %{user: "alice"}}])
      {:error, {:conflict, :add, [:user]}}

  ### Update
  Updates existing keys. Fails if any key doesn't exist.

      iex> ContextManager.apply_diff(%{user: "alice"}, [{:update, %{user: "bob"}}])
      {:ok, %{user: "bob"}}

      iex> ContextManager.apply_diff(%{}, [{:update, %{user: "alice"}}])
      {:error, {:conflict, :update, [:user]}}

  ### Add or Update
  Adds keys if they don't exist, updates if they do. Never fails on conflicts.

      iex> ContextManager.apply_diff(%{}, [{:add_or_update, %{user: "alice"}}])
      {:ok, %{user: "alice"}}

      iex> ContextManager.apply_diff(%{user: "bob"}, [{:add_or_update, %{user: "alice"}}])
      {:ok, %{user: "alice"}}

  ### Append To
  Appends items to existing lists, or creates a new list if the key doesn't exist.
  Fails if the existing value is not a list.

      iex> ContextManager.apply_diff(%{tags: ["a"]}, [{:append_to, %{tags: "b"}}])
      {:ok, %{tags: ["a", "b"]}}

      iex> ContextManager.apply_diff(%{}, [{:append_to, %{tags: ["a", "b"]}}])
      {:ok, %{tags: ["a", "b"]}}

      iex> ContextManager.apply_diff(%{count: 5}, [{:append_to, %{count: 1}}])
      {:error, {:invalid_append, :count, "Cannot append to non-list value"}}

  ### Remove
  Removes keys from the context. Fails if any key doesn't exist.

      iex> ContextManager.apply_diff(%{user: "alice"}, [{:remove, [:user]}])
      {:ok, %{}}

      iex> ContextManager.apply_diff(%{}, [{:remove, [:user]}])
      {:error, {:conflict, :remove, [:user]}}

  ## Multiple Operations

  Operations are applied sequentially:

      iex> diff = [
      ...>   {:add, %{user: "alice"}},
      ...>   {:add, %{count: 0}},
      ...>   {:update, %{count: 5}}
      ...> ]
      iex> ContextManager.apply_diff(%{}, diff)
      {:ok, %{user: "alice", count: 5}}

  """

  @type context :: map()
  @type diff_operation ::
          {:add, map()}
          | {:update, map()}
          | {:add_or_update, map()}
          | {:append_to, map()}
          | {:remove, list()}
  @type diff :: [diff_operation()]
  @type error_reason ::
          {:conflict, atom(), list()}
          | {:invalid_append, atom(), String.t()}
          | {:invalid_diff, any()}
          | {:invalid_diff_format, any()}

  @doc """
  Applies a list of diff operations to a context map.

  Returns `{:ok, new_context}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> ContextManager.apply_diff(%{}, [{:add, %{x: 1}}])
      {:ok, %{x: 1}}

      iex> ContextManager.apply_diff(%{}, [])
      {:ok, %{}}

  """
  @spec apply_diff(context(), diff()) :: {:ok, context()} | {:error, error_reason()}
  def apply_diff(context, diff) when is_list(diff) do
    try do
      new_context =
        Enum.reduce(diff, context, fn
          {:add, additions}, acc when is_map(additions) ->
            # Check for conflicts - can't add existing keys
            conflicts = Map.keys(additions) |> Enum.filter(&Map.has_key?(acc, &1))
            if conflicts != [], do: throw({:conflict, :add, conflicts})

            Map.merge(acc, additions)

          {:update, updates}, acc when is_map(updates) ->
            # Check for conflicts - can't update non-existing keys
            missing = Map.keys(updates) |> Enum.filter(&(!Map.has_key?(acc, &1)))
            if missing != [], do: throw({:conflict, :update, missing})

            Map.merge(acc, updates)

          {:add_or_update, changes}, acc when is_map(changes) ->
            # Add if key doesn't exist, update if it does - no conflict checking
            Map.merge(acc, changes)

          {:append_to, appends}, acc when is_map(appends) ->
            # Append values to existing arrays (or create new arrays if key doesn't exist)
            Enum.reduce(appends, acc, fn {key, value}, current_acc ->
              existing = Map.get(current_acc, key, [])

              # Ensure existing value is a list
              unless is_list(existing) do
                throw({:invalid_append, key, "Cannot append to non-list value"})
              end

              # Support both single items and lists of items
              items_to_append = if is_list(value), do: value, else: [value]

              Map.put(current_acc, key, existing ++ items_to_append)
            end)

          {:remove, keys}, acc when is_list(keys) ->
            # Check for conflicts - can't remove non-existing keys
            missing = keys |> Enum.filter(&(!Map.has_key?(acc, &1)))
            if missing != [], do: throw({:conflict, :remove, missing})

            Map.drop(acc, keys)

          invalid, _acc ->
            throw({:invalid_diff, invalid})
        end)

      {:ok, new_context}
    catch
      {:conflict, operation, keys} ->
        {:error, {:conflict, operation, keys}}

      {:invalid_append, key, reason} ->
        {:error, {:invalid_append, key, reason}}

      {:invalid_diff, diff_item} ->
        {:error, {:invalid_diff, diff_item}}
    end
  end

  def apply_diff(_context, diff) do
    {:error, {:invalid_diff_format, diff}}
  end

  @doc """
  Applies a diff to the context in the engine state, raising on error.

  This is a convenience function for when you want to fail fast on context
  update errors rather than handling the error explicitly.

  ## Examples

      iex> state = %{context: %{}, other: :data}
      iex> ContextManager.apply_context_diff!(state, [{:add, %{x: 1}}])
      %{context: %{x: 1}, other: :data}

      iex> state = %{context: %{x: 1}, other: :data}
      iex> ContextManager.apply_context_diff!(state, [{:add, %{x: 2}}])
      ** (RuntimeError) Context update failed: {:conflict, :add, [:x]}

  """
  @spec apply_context_diff!(map(), diff()) :: map()
  def apply_context_diff!(state, diff) do
    case apply_diff(state.context, diff) do
      {:ok, new_context} -> %{state | context: new_context}
      {:error, reason} -> raise "Context update failed: #{inspect(reason)}"
    end
  end
end
