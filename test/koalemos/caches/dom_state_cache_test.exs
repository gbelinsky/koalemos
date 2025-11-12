defmodule Koalemos.Caches.DOMStateCacheTest do
  use ExUnit.Case, async: false
  alias Koalemos.Caches.DOMStateCache

  setup do
    # DOMStateCache is started by the Application supervision tree
    # We just need to clear it before each test

    # Clear all DOM states before each test
    DOMStateCache.clear_all()

    # Use unique routine IDs per test to avoid conflicts
    routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"
    {:ok, routine_id: routine_id}
  end

  # Helper to create a test DOM update
  defp create_dom_update(tag \\ "div", id \\ "root") do
    %{
      "liveDOMTree" => %{
        "tag" => tag,
        "id" => id,
        "classes" => ["container"],
        "attributes" => %{"data-test" => "value"},
        "content" => "Hello",
        "children" => []
      },
      "timestamp" => System.system_time(:millisecond),
      "changeType" => "mutation"
    }
  end

  describe "add_dom_state/2" do
    test "stores DOM state successfully", %{routine_id: routine_id} do
      dom_update = create_dom_update()

      assert :ok = DOMStateCache.add_dom_state(routine_id, dom_update)

      # Verify it was stored
      state = DOMStateCache.get_dom_state(routine_id)
      assert state != nil
      assert state.live_dom_tree.tag == "div"
      assert state.live_dom_tree.id == "root"
    end

    test "overwrites existing DOM state for same routine", %{routine_id: routine_id} do
      first_update = create_dom_update("div", "first")
      second_update = create_dom_update("span", "second")

      DOMStateCache.add_dom_state(routine_id, first_update)
      DOMStateCache.add_dom_state(routine_id, second_update)

      # Should have the second DOM tree
      state = DOMStateCache.get_dom_state(routine_id)
      assert state.live_dom_tree.tag == "span"
      assert state.live_dom_tree.id == "second"
    end

    test "stores DOM states for multiple routines independently" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      dom_1 = create_dom_update("div", "one")
      dom_2 = create_dom_update("span", "two")

      DOMStateCache.add_dom_state(routine_1, dom_1)
      DOMStateCache.add_dom_state(routine_2, dom_2)

      state_1 = DOMStateCache.get_dom_state(routine_1)
      state_2 = DOMStateCache.get_dom_state(routine_2)

      assert state_1.live_dom_tree.id == "one"
      assert state_2.live_dom_tree.id == "two"
    end

    test "stores timestamp and change_type", %{routine_id: routine_id} do
      timestamp = 1_730_400_000_000

      dom_update = %{
        "liveDOMTree" => %{"tag" => "div"},
        "timestamp" => timestamp,
        "changeType" => "initial_load"
      }

      DOMStateCache.add_dom_state(routine_id, dom_update)

      state = DOMStateCache.get_dom_state(routine_id)
      assert state.timestamp == timestamp
      assert state.change_type == "initial_load"
    end

    test "defaults change_type to 'unknown' if not provided", %{routine_id: routine_id} do
      dom_update = %{
        "liveDOMTree" => %{"tag" => "div"},
        "timestamp" => 123
      }

      DOMStateCache.add_dom_state(routine_id, dom_update)

      state = DOMStateCache.get_dom_state(routine_id)
      assert state.change_type == "unknown"
    end
  end

  describe "get_dom_state/1" do
    test "returns DOM state when it exists", %{routine_id: routine_id} do
      dom_update = create_dom_update()
      DOMStateCache.add_dom_state(routine_id, dom_update)

      state = DOMStateCache.get_dom_state(routine_id)
      assert state != nil
      assert Map.has_key?(state, :live_dom_tree)
      assert Map.has_key?(state, :timestamp)
      assert Map.has_key?(state, :change_type)
      assert Map.has_key?(state, :cached_at)
    end

    test "returns nil when DOM state does not exist" do
      nonexistent_id = "nonexistent-routine-#{:erlang.unique_integer([:positive])}"

      assert DOMStateCache.get_dom_state(nonexistent_id) == nil
    end

    test "returns nil after DOM state is cleared", %{routine_id: routine_id} do
      DOMStateCache.add_dom_state(routine_id, create_dom_update())
      DOMStateCache.clear_dom_state(routine_id)

      assert DOMStateCache.get_dom_state(routine_id) == nil
    end
  end

  describe "clear_dom_state/1" do
    test "removes DOM state for specified routine", %{routine_id: routine_id} do
      DOMStateCache.add_dom_state(routine_id, create_dom_update())

      assert :ok = DOMStateCache.clear_dom_state(routine_id)
      assert DOMStateCache.get_dom_state(routine_id) == nil
    end

    test "returns :ok even if DOM state does not exist" do
      nonexistent_id = "nonexistent-#{:erlang.unique_integer([:positive])}"

      assert :ok = DOMStateCache.clear_dom_state(nonexistent_id)
    end

    test "does not affect other routines' DOM states" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      dom_1 = create_dom_update("div", "one")
      dom_2 = create_dom_update("span", "two")

      DOMStateCache.add_dom_state(routine_1, dom_1)
      DOMStateCache.add_dom_state(routine_2, dom_2)

      DOMStateCache.clear_dom_state(routine_1)

      # routine_2's DOM state should still exist
      state_2 = DOMStateCache.get_dom_state(routine_2)
      assert state_2 != nil
      assert state_2.live_dom_tree.id == "two"
      assert DOMStateCache.get_dom_state(routine_1) == nil
    end
  end

  describe "clear_all/0" do
    test "removes all DOM states" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      DOMStateCache.add_dom_state(routine_1, create_dom_update())
      DOMStateCache.add_dom_state(routine_2, create_dom_update())

      assert :ok = DOMStateCache.clear_all()

      assert DOMStateCache.get_dom_state(routine_1) == nil
      assert DOMStateCache.get_dom_state(routine_2) == nil
    end

    test "returns :ok even when cache is empty" do
      DOMStateCache.clear_all()

      assert :ok = DOMStateCache.clear_all()
    end
  end

  describe "get_stats/0" do
    test "returns correct routine count" do
      DOMStateCache.clear_all()

      stats = DOMStateCache.get_stats()
      assert stats.total_routines == 0

      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      DOMStateCache.add_dom_state(routine_1, create_dom_update())
      DOMStateCache.add_dom_state(routine_2, create_dom_update())

      stats = DOMStateCache.get_stats()
      assert stats.total_routines == 2
    end
  end

  describe "convert_js_dom_tree/1" do
    test "converts JavaScript DOM tree with string keys to atom keys" do
      js_tree = %{
        "tag" => "div",
        "id" => "root",
        "classes" => ["container", "active"],
        "attributes" => %{"data-value" => "123"},
        "content" => "Hello World"
      }

      converted = DOMStateCache.convert_js_dom_tree(js_tree)

      assert converted.tag == "div"
      assert converted.id == "root"
      assert converted.classes == ["container", "active"]
      assert converted.attributes == %{"data-value" => "123"}
      assert converted.content == "Hello World"
      assert converted.children == []
    end

    test "handles nil input" do
      assert DOMStateCache.convert_js_dom_tree(nil) == nil
    end

    test "handles invalid input" do
      assert DOMStateCache.convert_js_dom_tree("not a map") == nil
      assert DOMStateCache.convert_js_dom_tree(123) == nil
    end

    test "converts nested children recursively" do
      js_tree = %{
        "tag" => "div",
        "id" => "parent",
        "children" => [
          %{"tag" => "span", "id" => "child1"},
          %{"tag" => "span", "id" => "child2"}
        ]
      }

      converted = DOMStateCache.convert_js_dom_tree(js_tree)

      assert length(converted.children) == 2
      assert Enum.at(converted.children, 0).tag == "span"
      assert Enum.at(converted.children, 0).id == "child1"
      assert Enum.at(converted.children, 1).id == "child2"
    end

    test "filters out nil children" do
      js_tree = %{
        "tag" => "div",
        "children" => [
          %{"tag" => "span"},
          nil,
          "invalid",
          %{"tag" => "div"}
        ]
      }

      converted = DOMStateCache.convert_js_dom_tree(js_tree)

      # Should only have 2 valid children
      assert length(converted.children) == 2
    end

    test "handles missing optional fields" do
      js_tree = %{"tag" => "div"}

      converted = DOMStateCache.convert_js_dom_tree(js_tree)

      assert converted.tag == "div"
      assert converted.id == nil
      assert converted.classes == []
      assert converted.attributes == %{}
      assert converted.content == nil
      assert converted.children == []
    end
  end

  describe "supervision" do
    test "starts with the application" do
      # The GenServer should be started by setup
      # Verify it's accessible by trying an operation
      routine_id = "supervision-test-#{:erlang.unique_integer([:positive])}"

      assert :ok = DOMStateCache.add_dom_state(routine_id, create_dom_update())
      assert DOMStateCache.get_dom_state(routine_id) != nil
    end

    test "is registered as a named process" do
      # Should be able to find the process by name
      pid = Process.whereis(DOMStateCache)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "integration" do
    test "full workflow: add, get, clear" do
      routine_id = "workflow-test-#{:erlang.unique_integer([:positive])}"
      dom_update = create_dom_update("article", "main-content")

      # Store DOM state
      assert :ok = DOMStateCache.add_dom_state(routine_id, dom_update)

      # Retrieve DOM state
      state = DOMStateCache.get_dom_state(routine_id)
      assert state != nil
      assert state.live_dom_tree.tag == "article"
      assert state.live_dom_tree.id == "main-content"

      # Clear DOM state
      assert :ok = DOMStateCache.clear_dom_state(routine_id)

      # Verify cleared
      assert DOMStateCache.get_dom_state(routine_id) == nil
    end

    test "handles complex nested DOM trees" do
      routine_id = "complex-tree-test-#{:erlang.unique_integer([:positive])}"

      dom_update = %{
        "liveDOMTree" => %{
          "tag" => "div",
          "id" => "app",
          "classes" => ["container"],
          "children" => [
            %{
              "tag" => "header",
              "id" => "header",
              "children" => [
                %{"tag" => "h1", "content" => "Title"},
                %{
                  "tag" => "nav",
                  "children" => [
                    %{"tag" => "a", "content" => "Home"},
                    %{"tag" => "a", "content" => "About"}
                  ]
                }
              ]
            },
            %{
              "tag" => "main",
              "children" => [
                %{"tag" => "p", "content" => "Content"}
              ]
            }
          ]
        },
        "timestamp" => 123
      }

      DOMStateCache.add_dom_state(routine_id, dom_update)

      state = DOMStateCache.get_dom_state(routine_id)
      assert state.live_dom_tree.tag == "div"
      assert length(state.live_dom_tree.children) == 2

      header = Enum.at(state.live_dom_tree.children, 0)
      assert header.tag == "header"
      assert length(header.children) == 2
    end
  end
end
