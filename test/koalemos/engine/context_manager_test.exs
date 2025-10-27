defmodule Koalemos.Engine.ContextManagerTest do
  use ExUnit.Case, async: true
  alias Koalemos.Engine.ContextManager

  doctest ContextManager

  describe "apply_diff/2 - add operation" do
    test "adds new keys to empty context" do
      assert {:ok, %{user: "alice"}} = ContextManager.apply_diff(%{}, [{:add, %{user: "alice"}}])
    end

    test "adds multiple keys" do
      diff = [{:add, %{user: "alice", role: "admin"}}]
      assert {:ok, %{user: "alice", role: "admin"}} = ContextManager.apply_diff(%{}, diff)
    end

    test "preserves existing keys when adding new ones" do
      context = %{existing: "value"}
      diff = [{:add, %{new: "data"}}]
      assert {:ok, %{existing: "value", new: "data"}} = ContextManager.apply_diff(context, diff)
    end

    test "returns conflict error when key already exists" do
      context = %{user: "bob"}
      diff = [{:add, %{user: "alice"}}]
      assert {:error, {:conflict, :add, [:user]}} = ContextManager.apply_diff(context, diff)
    end

    test "returns conflict error with all conflicting keys" do
      context = %{user: "bob", role: "user"}
      diff = [{:add, %{user: "alice", role: "admin", new: "value"}}]

      assert {:error, {:conflict, :add, conflicts}} = ContextManager.apply_diff(context, diff)
      assert :user in conflicts
      assert :role in conflicts
      assert length(conflicts) == 2
    end
  end

  describe "apply_diff/2 - update operation" do
    test "updates existing keys" do
      context = %{user: "alice"}
      diff = [{:update, %{user: "bob"}}]
      assert {:ok, %{user: "bob"}} = ContextManager.apply_diff(context, diff)
    end

    test "updates multiple keys" do
      context = %{user: "alice", role: "user"}
      diff = [{:update, %{user: "bob", role: "admin"}}]
      assert {:ok, %{user: "bob", role: "admin"}} = ContextManager.apply_diff(context, diff)
    end

    test "preserves non-updated keys" do
      context = %{user: "alice", role: "user", id: 123}
      diff = [{:update, %{user: "bob"}}]
      assert {:ok, %{user: "bob", role: "user", id: 123}} = ContextManager.apply_diff(context, diff)
    end

    test "returns conflict error when key doesn't exist" do
      context = %{}
      diff = [{:update, %{user: "alice"}}]
      assert {:error, {:conflict, :update, [:user]}} = ContextManager.apply_diff(context, diff)
    end

    test "returns conflict error with all missing keys" do
      context = %{existing: "value"}
      diff = [{:update, %{user: "alice", role: "admin"}}]

      assert {:error, {:conflict, :update, missing}} = ContextManager.apply_diff(context, diff)
      assert :user in missing
      assert :role in missing
      assert length(missing) == 2
    end
  end

  describe "apply_diff/2 - add_or_update operation" do
    test "adds keys that don't exist" do
      assert {:ok, %{user: "alice"}} =
        ContextManager.apply_diff(%{}, [{:add_or_update, %{user: "alice"}}])
    end

    test "updates keys that exist" do
      context = %{user: "bob"}
      diff = [{:add_or_update, %{user: "alice"}}]
      assert {:ok, %{user: "alice"}} = ContextManager.apply_diff(context, diff)
    end

    test "handles mix of existing and new keys" do
      context = %{user: "bob"}
      diff = [{:add_or_update, %{user: "alice", role: "admin"}}]
      assert {:ok, %{user: "alice", role: "admin"}} = ContextManager.apply_diff(context, diff)
    end

    test "never produces conflicts" do
      context = %{user: "bob", role: "user"}
      diff = [{:add_or_update, %{user: "alice", role: "admin", new: "value"}}]
      assert {:ok, %{user: "alice", role: "admin", new: "value"}} =
        ContextManager.apply_diff(context, diff)
    end
  end

  describe "apply_diff/2 - append_to operation" do
    test "appends single item to existing list" do
      context = %{tags: ["a", "b"]}
      diff = [{:append_to, %{tags: "c"}}]
      assert {:ok, %{tags: ["a", "b", "c"]}} = ContextManager.apply_diff(context, diff)
    end

    test "appends multiple items to existing list" do
      context = %{tags: ["a"]}
      diff = [{:append_to, %{tags: ["b", "c"]}}]
      assert {:ok, %{tags: ["a", "b", "c"]}} = ContextManager.apply_diff(context, diff)
    end

    test "creates new list if key doesn't exist" do
      diff = [{:append_to, %{tags: "a"}}]
      assert {:ok, %{tags: ["a"]}} = ContextManager.apply_diff(%{}, diff)
    end

    test "creates list with multiple items if key doesn't exist" do
      diff = [{:append_to, %{tags: ["a", "b"]}}]
      assert {:ok, %{tags: ["a", "b"]}} = ContextManager.apply_diff(%{}, diff)
    end

    test "appends to multiple lists" do
      context = %{tags: ["a"], categories: ["x"]}
      diff = [{:append_to, %{tags: "b", categories: "y"}}]
      assert {:ok, %{tags: ["a", "b"], categories: ["x", "y"]}} =
        ContextManager.apply_diff(context, diff)
    end

    test "returns error when trying to append to non-list value" do
      context = %{count: 5}
      diff = [{:append_to, %{count: 1}}]
      assert {:error, {:invalid_append, :count, "Cannot append to non-list value"}} =
        ContextManager.apply_diff(context, diff)
    end

    test "preserves other keys when appending" do
      context = %{tags: ["a"], user: "alice"}
      diff = [{:append_to, %{tags: "b"}}]
      assert {:ok, %{tags: ["a", "b"], user: "alice"}} =
        ContextManager.apply_diff(context, diff)
    end
  end

  describe "apply_diff/2 - remove operation" do
    test "removes single key" do
      context = %{user: "alice", role: "admin"}
      diff = [{:remove, [:user]}]
      assert {:ok, %{role: "admin"}} = ContextManager.apply_diff(context, diff)
    end

    test "removes multiple keys" do
      context = %{user: "alice", role: "admin", id: 123}
      diff = [{:remove, [:user, :role]}]
      assert {:ok, %{id: 123}} = ContextManager.apply_diff(context, diff)
    end

    test "removes all keys leaving empty map" do
      context = %{user: "alice"}
      diff = [{:remove, [:user]}]
      assert {:ok, %{}} = ContextManager.apply_diff(context, diff)
    end

    test "returns conflict error when key doesn't exist" do
      context = %{user: "alice"}
      diff = [{:remove, [:role]}]
      assert {:error, {:conflict, :remove, [:role]}} = ContextManager.apply_diff(context, diff)
    end

    test "returns conflict error with all missing keys" do
      context = %{user: "alice"}
      diff = [{:remove, [:role, :id]}]

      assert {:error, {:conflict, :remove, missing}} = ContextManager.apply_diff(context, diff)
      assert :role in missing
      assert :id in missing
      assert length(missing) == 2
    end
  end

  describe "apply_diff/2 - multiple operations" do
    test "applies operations sequentially" do
      diff = [
        {:add, %{user: "alice"}},
        {:add, %{role: "user"}},
        {:update, %{role: "admin"}}
      ]
      assert {:ok, %{user: "alice", role: "admin"}} = ContextManager.apply_diff(%{}, diff)
    end

    test "applies add, append, and update" do
      diff = [
        {:add, %{messages: []}},
        {:append_to, %{messages: "hello"}},
        {:append_to, %{messages: "world"}},
        {:add, %{count: 2}}
      ]
      assert {:ok, %{messages: ["hello", "world"], count: 2}} =
        ContextManager.apply_diff(%{}, diff)
    end

    test "stops on first error" do
      context = %{user: "alice"}
      diff = [
        {:add, %{role: "admin"}},
        {:add, %{user: "bob"}},  # This should fail
        {:add, %{id: 123}}       # This shouldn't be reached
      ]

      assert {:error, {:conflict, :add, [:user]}} = ContextManager.apply_diff(context, diff)
      # Context should be unchanged after error
      assert {:ok, context_after_error_attempt} =
        ContextManager.apply_diff(context, [])
      assert context_after_error_attempt == context
    end

    test "complex multi-operation diff" do
      context = %{tags: ["initial"], user: "alice", temp: "delete_me"}

      diff = [
        {:append_to, %{tags: "added"}},
        {:update, %{user: "bob"}},
        {:add, %{role: "admin"}},
        {:remove, [:temp]},
        {:add_or_update, %{count: 1}}
      ]

      assert {:ok, result} = ContextManager.apply_diff(context, diff)
      assert result.tags == ["initial", "added"]
      assert result.user == "bob"
      assert result.role == "admin"
      assert result.count == 1
      assert not Map.has_key?(result, :temp)
    end
  end

  describe "apply_diff/2 - edge cases" do
    test "empty diff returns context unchanged" do
      context = %{user: "alice"}
      assert {:ok, ^context} = ContextManager.apply_diff(context, [])
    end

    test "empty context with empty diff" do
      assert {:ok, %{}} = ContextManager.apply_diff(%{}, [])
    end

    test "returns error for invalid diff format (not a list)" do
      assert {:error, {:invalid_diff_format, _}} = ContextManager.apply_diff(%{}, %{invalid: "diff"})
    end

    test "returns error for invalid operation tuple" do
      diff = [{:invalid_op, %{data: "value"}}]
      assert {:error, {:invalid_diff, _}} = ContextManager.apply_diff(%{}, diff)
    end

    test "returns error for invalid operation (not a tuple)" do
      diff = ["not_a_tuple"]
      assert {:error, {:invalid_diff, _}} = ContextManager.apply_diff(%{}, diff)
    end
  end

  describe "apply_context_diff!/2" do
    test "applies diff to state context successfully" do
      state = %{context: %{}, other_field: :value}
      diff = [{:add, %{user: "alice"}}]

      result = ContextManager.apply_context_diff!(state, diff)

      assert result.context == %{user: "alice"}
      assert result.other_field == :value
    end

    test "preserves other state fields" do
      state = %{
        context: %{},
        workflow_id: "test-123",
        current_step: :init,
        other_data: [1, 2, 3]
      }

      diff = [{:add, %{x: 1}}]
      result = ContextManager.apply_context_diff!(state, diff)

      assert result.context == %{x: 1}
      assert result.workflow_id == "test-123"
      assert result.current_step == :init
      assert result.other_data == [1, 2, 3]
    end

    test "raises on conflict error" do
      state = %{context: %{user: "bob"}}
      diff = [{:add, %{user: "alice"}}]

      assert_raise RuntimeError, ~r/Context update failed: \{:conflict, :add, \[:user\]\}/, fn ->
        ContextManager.apply_context_diff!(state, diff)
      end
    end

    test "raises on append error" do
      state = %{context: %{count: 5}}
      diff = [{:append_to, %{count: 1}}]

      assert_raise RuntimeError, ~r/Context update failed/, fn ->
        ContextManager.apply_context_diff!(state, diff)
      end
    end

    test "raises on invalid diff format" do
      state = %{context: %{}}

      assert_raise RuntimeError, ~r/Context update failed/, fn ->
        ContextManager.apply_context_diff!(state, "not a diff")
      end
    end
  end
end
