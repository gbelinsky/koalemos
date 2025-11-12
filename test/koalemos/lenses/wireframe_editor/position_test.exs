defmodule Koalemos.Lenses.WireframeEditor.PositionTest do
  use ExUnit.Case, async: true
  alias Koalemos.Lenses.WireframeEditor.DOMHandler

  setup do
    # Create a basic wireframe with a parent container and some children
    wireframe = %{
      id: "root",
      tag: "div",
      classes: [],
      children: [
        %{
          id: "container",
          tag: "div",
          classes: ["container"],
          children: [
            %{id: "first-child", tag: "div", content: "First", classes: [], children: []},
            %{id: "second-child", tag: "div", content: "Second", classes: [], children: []},
            %{id: "third-child", tag: "div", content: "Third", classes: [], children: []}
          ]
        }
      ]
    }

    lens_state = %{
      designed: %{dom_tree: wireframe},
      modifications: []
    }

    {:ok, lens_state: lens_state}
  end

  describe "modify_elements position parameter" do
    test "adds element at 'first' position", %{lens_state: lens_state} do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "new-first",
            "content" => "I am first!",
            "position" => "first"
          }
        ]
      }

      {result, updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that operation succeeded
      assert result =~ "Successfully modified 1 element(s)"

      # Verify element is at first position
      updated_tree = updates[:designed].dom_tree
      container = find_element_by_id(updated_tree, "container")
      assert length(container.children) == 4
      assert hd(container.children).id == "new-first"
      assert Enum.at(container.children, 1).id == "first-child"
    end

    test "adds element at 'last' position (default)", %{lens_state: lens_state} do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "new-last",
            "content" => "I am last!",
            "position" => "last"
          }
        ]
      }

      {result, updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that operation succeeded
      assert result =~ "Successfully modified"

      # Verify element is at last position
      updated_tree = updates[:designed].dom_tree
      container = find_element_by_id(updated_tree, "container")
      assert length(container.children) == 4
      assert List.last(container.children).id == "new-last"
      assert Enum.at(container.children, 2).id == "third-child"
    end

    test "adds element with no position parameter defaults to 'last'", %{lens_state: lens_state} do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "default-position",
            "content" => "Default position"
          }
        ]
      }

      {result, updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that operation succeeded
      assert result =~ "Successfully modified"

      # Verify element is at last position (default behavior)
      updated_tree = updates[:designed].dom_tree
      container = find_element_by_id(updated_tree, "container")
      assert length(container.children) == 4
      assert List.last(container.children).id == "default-position"
    end

    test "adds element 'before' reference element", %{lens_state: lens_state} do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "before-second",
            "content" => "Before second",
            "position" => "before",
            "reference_id" => "second-child"
          }
        ]
      }

      {result, updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that operation succeeded
      assert result =~ "Successfully modified"

      # Verify element is before second-child
      updated_tree = updates[:designed].dom_tree
      container = find_element_by_id(updated_tree, "container")
      assert length(container.children) == 4
      assert Enum.at(container.children, 0).id == "first-child"
      assert Enum.at(container.children, 1).id == "before-second"
      assert Enum.at(container.children, 2).id == "second-child"
      assert Enum.at(container.children, 3).id == "third-child"
    end

    test "adds element 'after' reference element", %{lens_state: lens_state} do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "after-second",
            "content" => "After second",
            "position" => "after",
            "reference_id" => "second-child"
          }
        ]
      }

      {result, updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that operation succeeded
      assert result =~ "Successfully modified"

      # Verify element is after second-child
      updated_tree = updates[:designed].dom_tree
      container = find_element_by_id(updated_tree, "container")
      assert length(container.children) == 4
      assert Enum.at(container.children, 0).id == "first-child"
      assert Enum.at(container.children, 1).id == "second-child"
      assert Enum.at(container.children, 2).id == "after-second"
      assert Enum.at(container.children, 3).id == "third-child"
    end

    test "returns error when reference_id not found for 'before' position", %{
      lens_state: lens_state
    } do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "new-element",
            "content" => "New",
            "position" => "before",
            "reference_id" => "nonexistent"
          }
        ]
      }

      {result, _updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that operation failed with proper error
      assert result =~ "All operations failed"
      assert result =~ "Reference element 'nonexistent' not found"
    end

    test "returns error when reference_id not found for 'after' position", %{
      lens_state: lens_state
    } do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "new-element",
            "content" => "New",
            "position" => "after",
            "reference_id" => "nonexistent"
          }
        ]
      }

      {result, _updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that operation failed with proper error
      assert result =~ "All operations failed"
      assert result =~ "Reference element 'nonexistent' not found"
    end

    test "multiple additions with different positions", %{lens_state: lens_state} do
      tool_args = %{
        "add_elements" => [
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "new-first",
            "content" => "First",
            "position" => "first"
          },
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "new-last",
            "content" => "Last",
            "position" => "last"
          },
          %{
            "parent_id" => "container",
            "tag" => "div",
            "id" => "after-first-child",
            "content" => "After first child",
            "position" => "after",
            "reference_id" => "first-child"
          }
        ]
      }

      {result, updates} = DOMHandler.modify_elements(lens_state, tool_args)

      # Check that all operations succeeded
      assert result =~ "Successfully modified 3 element(s)"

      # Verify final order
      # Note: Additions are processed in sequence, so:
      # 1. new-first is added first (0: new-first, 1: first-child, 2: second-child, 3: third-child)
      # 2. new-last is added last (0: new-first, 1: first-child, 2: second-child, 3: third-child, 4: new-last)
      # 3. after-first-child is added after first-child (0: new-first, 1: first-child, 2: after-first-child, 3: second-child, 4: third-child, 5: new-last)
      updated_tree = updates[:designed].dom_tree
      container = find_element_by_id(updated_tree, "container")
      assert length(container.children) == 6
      assert Enum.at(container.children, 0).id == "new-first"
      assert Enum.at(container.children, 1).id == "first-child"
      assert Enum.at(container.children, 2).id == "after-first-child"
      assert Enum.at(container.children, 3).id == "second-child"
      assert Enum.at(container.children, 4).id == "third-child"
      assert Enum.at(container.children, 5).id == "new-last"
    end
  end

  # Helper to find element by ID in tree
  defp find_element_by_id(%{id: id} = element, target_id) when id == target_id, do: element

  defp find_element_by_id(%{children: children}, target_id) do
    Enum.find_value(children, fn child -> find_element_by_id(child, target_id) end)
  end

  defp find_element_by_id(_, _), do: nil
end
