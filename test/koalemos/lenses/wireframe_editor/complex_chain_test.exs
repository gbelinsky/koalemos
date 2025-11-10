defmodule Koalemos.Lenses.WireframeEditor.ComplexChainTest do
  @moduledoc """
  Integration test for complex multi-step interaction chains.

  Tests that an agent can:
  1. Build an interactive UI with multiple components
  2. Perform a sequence of interactions
  3. See cumulative state changes after each step
  4. Use provide_context to understand the current state
  5. Make decisions based on what they observe

  This validates complex workflows for Sprint 7 Phase 7.
  """
  use ExUnit.Case, async: false

  alias Koalemos.Lenses.WireframeEditor
  alias Koalemos.Caches.{DOMStateCache, ConsoleCache, ScreenshotCache, WireframeStateCache}

  setup do
    routine_id = "chain-test-#{:erlang.unique_integer([:positive])}"

    # Clear all caches
    DOMStateCache.clear_all()
    ConsoleCache.clear_all()
    ScreenshotCache.clear_all()

    # Cleanup on exit
    on_exit(fn ->
      WireframeStateCache.delete_state(routine_id)
      DOMStateCache.clear_dom_state(routine_id)
      ConsoleCache.clear_messages(routine_id)
      ScreenshotCache.clear(routine_id)
    end)

    {:ok, routine_id: routine_id}
  end

  describe "complex interaction chain" do
    test "agent builds todo app and tests full workflow", %{routine_id: routine_id} do
      # Step 1: Build initial todo app
      lens_state = build_todo_app()
      WireframeStateCache.put_state(routine_id, lens_state)

      # Step 2: Add first todo item
      task1 = Task.async(fn ->
        :timer.sleep(100)
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "interaction:response:#{routine_id}",
          {:interaction_complete, %{"success" => true}}
        )
      end)

      {result1, _} = WireframeEditor.execute(
        :trigger_interaction,
        %{"action" => "click", "element_id" => "add-btn"},
        %{lens_state: lens_state, routine_id: routine_id}
      )

      Task.await(task1)
      assert result1 =~ "Successfully triggered"

      # Capture state after adding first item
      capture_task1 = Task.async(fn ->
        :timer.sleep(100)
        simulate_todo_added(routine_id, lens_state, [%{id: "todo-1", text: "Buy milk", completed: false}])
      end)

      {:ok, state1} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task1)

      # Agent should see first todo in list
      todo_list = find_element_by_id(state1.dom_tree, "todo-list")
      assert todo_list != nil
      assert length(todo_list.children) == 1

      first_todo = hd(todo_list.children)
      assert first_todo.id == "todo-1"

      # Console log about adding
      assert Enum.any?(state1.console_output, fn log ->
        String.contains?(log.message, "Todo") and String.contains?(log.message, "added")
      end)

      # Step 3: Add second todo item
      task2 = Task.async(fn ->
        :timer.sleep(100)
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "interaction:response:#{routine_id}",
          {:interaction_complete, %{"success" => true}}
        )
      end)

      {result2, _} = WireframeEditor.execute(
        :trigger_interaction,
        %{"action" => "click", "element_id" => "add-btn"},
        %{lens_state: lens_state, routine_id: routine_id}
      )

      Task.await(task2)
      assert result2 =~ "Successfully triggered"

      # Capture state after adding second item
      capture_task2 = Task.async(fn ->
        :timer.sleep(100)
        simulate_todo_added(routine_id, lens_state, [
          %{id: "todo-1", text: "Buy milk", completed: false},
          %{id: "todo-2", text: "Walk dog", completed: false}
        ])
      end)

      {:ok, state2} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task2)

      # Agent should see two todos
      todo_list2 = find_element_by_id(state2.dom_tree, "todo-list")
      assert length(todo_list2.children) == 2

      # Step 4: Complete first todo
      task3 = Task.async(fn ->
        :timer.sleep(100)
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "interaction:response:#{routine_id}",
          {:interaction_complete, %{"success" => true}}
        )
      end)

      {result3, _} = WireframeEditor.execute(
        :trigger_interaction,
        %{"action" => "click", "element_id" => "todo-1-checkbox"},
        %{lens_state: lens_state, routine_id: routine_id}
      )

      Task.await(task3)
      assert result3 =~ "Successfully triggered"

      # Capture state showing completed todo
      capture_task3 = Task.async(fn ->
        :timer.sleep(100)
        simulate_todo_added(routine_id, lens_state, [
          %{id: "todo-1", text: "Buy milk", completed: true},
          %{id: "todo-2", text: "Walk dog", completed: false}
        ])
      end)

      {:ok, state3} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task3)

      # Agent should see first todo marked as completed
      completed_todo = find_element_by_id(state3.dom_tree, "todo-1")
      assert completed_todo != nil
      assert Enum.member?(completed_todo.classes, "completed")

      # Console shows completion
      assert Enum.any?(state3.console_output, fn log ->
        String.contains?(log.message, "completed") or String.contains?(log.message, "checked")
      end)

      # Verify captured state has all the context agent needs
      assert state3.dom_tree != nil
      assert is_list(state3.console_output)
      assert state3.differs_from_designed == true
    end

    test "agent debugs interaction issues through multiple attempts", %{routine_id: routine_id} do
      # Build interactive counter
      lens_state = build_interactive_counter()
      WireframeStateCache.put_state(routine_id, lens_state)

      # Test sequence: increment, capture, increment again, capture, verify cumulative changes
      interactions = [
        {%{"action" => "click", "element_id" => "increment-btn"}, 1},
        {%{"action" => "click", "element_id" => "increment-btn"}, 2},
        {%{"action" => "click", "element_id" => "double-btn"}, 4},
        {%{"action" => "click", "element_id" => "reset-btn"}, 0}
      ]

      Enum.reduce(interactions, 0, fn {interaction_args, expected_value}, _acc ->
        # Trigger interaction
        task = Task.async(fn ->
          :timer.sleep(100)
          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "interaction:response:#{routine_id}",
            {:interaction_complete, %{"success" => true}}
          )
        end)

        {result, _} = WireframeEditor.execute(
          :trigger_interaction,
          interaction_args,
          %{lens_state: lens_state, routine_id: routine_id}
        )

        Task.await(task)
        assert result =~ "Successfully triggered"

        # Capture and verify
        capture_task = Task.async(fn ->
          :timer.sleep(100)
          simulate_counter_value(routine_id, lens_state, expected_value, interaction_args["element_id"])
        end)

        {:ok, state} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
        Task.await(capture_task)

        # Verify counter value matches expected
        counter_display = find_element_by_id(state.dom_tree, "counter-display")
        assert counter_display.content == to_string(expected_value)

        expected_value
      end)
    end
  end

  # Helper: Build a todo app
  defp build_todo_app do
    %{
      designed: %{
        dom_tree: %{
          tag: "div",
          id: "root",
          classes: ["todo-app"],
          attributes: %{},
          handlers: %{},
          content: nil,
          children: [
            %{
              tag: "button",
              id: "add-btn",
              classes: ["btn"],
              attributes: %{},
              handlers: %{},
              text: "Add Todo",
              children: []
            },
            %{
              tag: "ul",
              id: "todo-list",
              classes: ["list"],
              attributes: %{},
              handlers: %{},
              content: nil,
              children: []  # Start empty
            }
          ]
        },
        custom_css: %{},
        custom_functions: %{},
        custom_variables: %{},
        init_scripts: %{},
        handlers: %{}
      },
      modifications: []
    }
  end

  # Helper: Build an interactive counter with multiple operations
  defp build_interactive_counter do
    %{
      designed: %{
        dom_tree: %{
          tag: "div",
          id: "root",
          classes: ["counter"],
          attributes: %{},
          handlers: %{},
          content: nil,
          children: [
            %{
              tag: "div",
              id: "counter-display",
              classes: ["display"],
              attributes: %{},
              handlers: %{},
              text: "0",
              children: []
            },
            %{
              tag: "button",
              id: "increment-btn",
              classes: ["btn"],
              attributes: %{},
              handlers: %{},
              text: "Increment",
              children: []
            },
            %{
              tag: "button",
              id: "double-btn",
              classes: ["btn"],
              attributes: %{},
              handlers: %{},
              text: "Double",
              children: []
            },
            %{
              tag: "button",
              id: "reset-btn",
              classes: ["btn"],
              attributes: %{},
              handlers: %{},
              text: "Reset",
              children: []
            }
          ]
        },
        custom_css: %{},
        custom_functions: %{},
        custom_variables: %{},
        init_scripts: %{},
        handlers: %{}
      },
      modifications: []
    }
  end

  # Simulate todo items being added/updated
  defp simulate_todo_added(routine_id, lens_state, todos) do
    # Build todo list with current todos
    todo_elements = Enum.map(todos, fn todo ->
      classes = if todo.completed, do: ["todo-item", "completed"], else: ["todo-item"]

      %{
        tag: "li",
        id: todo.id,
        classes: classes,
        attributes: %{},
        handlers: %{},
        content: nil,
        children: [
          %{
            tag: "input",
            id: "#{todo.id}-checkbox",
            classes: ["checkbox"],
            attributes: %{"type" => "checkbox", "checked" => to_string(todo.completed)},
            handlers: %{},
            content: nil,
            children: []
          },
          %{
            tag: "span",
            id: "#{todo.id}-text",
            classes: ["text"],
            attributes: %{},
            handlers: %{},
            text: todo.text,
            children: []
          }
        ]
      }
    end)

    # Update todo list in tree
    modified_tree = update_todo_list(lens_state.designed.dom_tree, todo_elements)
    dom_tree_js = convert_to_js_format(modified_tree)

    DOMStateCache.add_dom_state(routine_id, %{
      "liveDOMTree" => dom_tree_js,
      "changeType" => "snapshot",
      "timestamp" => System.system_time(:millisecond)
    })

    # Add console messages
    Enum.each(todos, fn todo ->
      status = if todo.completed, do: "completed", else: "added"
      ConsoleCache.add_message(routine_id, %{
        level: "log",
        message: "Todo #{status}: #{todo.text}",
        timestamp: System.system_time(:millisecond)
      })
    end)

    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "snapshot:response:#{routine_id}",
      {:snapshot_ready, routine_id, DateTime.utc_now()}
    )
  end

  # Simulate counter value change
  defp simulate_counter_value(routine_id, lens_state, new_value, button_id) do
    modified_tree = update_element_content(lens_state.designed.dom_tree, "counter-display", to_string(new_value))
    dom_tree_js = convert_to_js_format(modified_tree)

    DOMStateCache.add_dom_state(routine_id, %{
      "liveDOMTree" => dom_tree_js,
      "changeType" => "snapshot",
      "timestamp" => System.system_time(:millisecond)
    })

    action = case button_id do
      "increment-btn" -> "incremented"
      "double-btn" -> "doubled"
      "reset-btn" -> "reset"
      _ -> "changed"
    end

    ConsoleCache.add_message(routine_id, %{
      level: "log",
      message: "Counter #{action} to #{new_value}",
      timestamp: System.system_time(:millisecond)
    })

    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "snapshot:response:#{routine_id}",
      {:snapshot_ready, routine_id, DateTime.utc_now()}
    )
  end

  # Update todo list children
  defp update_todo_list(tree, todo_elements) when is_map(tree) do
    if tree[:id] == "todo-list" do
      Map.put(tree, :children, todo_elements)
    else
      case tree[:children] do
        children when is_list(children) ->
          Map.put(tree, :children, Enum.map(children, &update_todo_list(&1, todo_elements)))
        _ ->
          tree
      end
    end
  end

  # Recursively update an element's content by ID
  defp update_element_content(tree, target_id, new_content) when is_map(tree) do
    if tree[:id] == target_id do
      Map.put(tree, :text, new_content)
    else
      case tree[:children] do
        children when is_list(children) ->
          Map.put(tree, :children, Enum.map(children, &update_element_content(&1, target_id, new_content)))
        _ ->
          tree
      end
    end
  end

  # Convert Elixir-format DOM tree to JavaScript format
  defp convert_to_js_format(nil), do: nil

  defp convert_to_js_format(tree) when is_map(tree) do
    text_content = tree[:content] || tree[:text]

    %{
      "tag" => tree.tag,
      "id" => tree[:id],
      "classes" => tree[:classes] || [],
      "attributes" => tree[:attributes] || %{},
      "content" => text_content,
      "children" => Enum.map(tree[:children] || [], &convert_to_js_format/1)
    }
  end

  # Helper to find element by ID in DOM tree
  defp find_element_by_id(%{id: id} = element, target_id) when id == target_id, do: element
  defp find_element_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child -> find_element_by_id(child, target_id) end)
  end
  defp find_element_by_id(_, _), do: nil
end
