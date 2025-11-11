defmodule Koalemos.Lenses.WireframeEditor.ErrorRecoveryTest do
  @moduledoc """
  Integration test for JavaScript error detection and recovery.

  Tests that an agent can:
  1. Trigger an interaction that causes a JavaScript error
  2. See the error in captured console output
  3. Understand what went wrong from the error message
  4. Fix the code and retry successfully

  This validates error feedback for Sprint 7 Phase 7.
  """
  use ExUnit.Case, async: false

  alias Koalemos.Lenses.WireframeEditor
  alias Koalemos.Caches.{DOMStateCache, ConsoleCache, ScreenshotCache, WireframeStateCache}

  setup do
    routine_id = "error-test-#{:erlang.unique_integer([:positive])}"

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

  describe "error recovery feedback loop" do
    test "agent sees JavaScript error in console", %{routine_id: routine_id} do
      # Step 1: Build a counter with a buggy increment function
      lens_state = build_buggy_counter()
      WireframeStateCache.put_state(routine_id, lens_state)

      # Step 2: Agent triggers increment (will cause error)
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
        %{"action" => "click", "element_id" => "increment-btn"},
        %{lens_state: lens_state, routine_id: routine_id}
      )

      Task.await(task)
      assert result =~ "Successfully triggered"

      # Step 3: Capture state showing JavaScript error
      capture_task = Task.async(fn ->
        :timer.sleep(100)
        simulate_javascript_error(routine_id, lens_state, "TypeError: Cannot read property 'value' of null")
      end)

      {:ok, captured_state} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task)

      # Agent should see:
      # - Error in console output
      assert length(captured_state.console_output) > 0
      error_logs = Enum.filter(captured_state.console_output, fn log -> log.level == "error" end)
      assert length(error_logs) > 0

      error_log = hd(error_logs)
      assert error_log.message =~ "TypeError"
      assert error_log.message =~ "null"

      # - DOM unchanged (error prevented update)
      counter_value = find_element_by_id(captured_state.dom_tree, "counter-value")
      assert counter_value.content == "0"  # Still 0, didn't increment
    end

    test "agent detects missing element error and fixes it", %{routine_id: routine_id} do
      # Initial buggy counter (missing display element)
      lens_state = build_buggy_counter()
      WireframeStateCache.put_state(routine_id, lens_state)

      # Try to increment (causes error)
      task1 = Task.async(fn ->
        :timer.sleep(100)
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "interaction:response:#{routine_id}",
          {:interaction_complete, %{"success" => true}}
        )
      end)

      {_result1, _} = WireframeEditor.execute(
        :trigger_interaction,
        %{"action" => "click", "element_id" => "increment-btn"},
        %{lens_state: lens_state, routine_id: routine_id}
      )

      Task.await(task1)

      # Capture state showing error
      capture_task1 = Task.async(fn ->
        :timer.sleep(100)
        simulate_javascript_error(routine_id, lens_state, "TypeError: Cannot read property 'value' of null")
      end)

      {:ok, state1} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task1)

      error_log = Enum.find(state1.console_output, fn log -> log.level == "error" end)
      assert error_log != nil
      assert error_log.message =~ "TypeError"

      # Agent would fix the bug (in real scenario, they'd use update_element tool)
      # For test, simulate the fixed version
      fixed_lens_state = build_working_counter()
      WireframeStateCache.put_state(routine_id, fixed_lens_state)

      # Clear console from previous attempt (agent starts fresh after fixing)
      ConsoleCache.clear_messages(routine_id)

      # Try increment again (should work now)
      task2 = Task.async(fn ->
        :timer.sleep(100)
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "interaction:response:#{routine_id}",
          {:interaction_complete, %{"success" => true}}
        )
      end)

      {_result2, _} = WireframeEditor.execute(
        :trigger_interaction,
        %{"action" => "click", "element_id" => "increment-btn"},
        %{lens_state: fixed_lens_state, routine_id: routine_id}
      )

      Task.await(task2)

      # Capture state showing success
      capture_task2 = Task.async(fn ->
        :timer.sleep(100)
        simulate_successful_increment(routine_id, fixed_lens_state)
      end)

      {:ok, state2} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task2)

      # No errors this time
      error_logs = Enum.filter(state2.console_output, fn log -> log.level == "error" end)
      assert length(error_logs) == 0

      # Counter successfully incremented
      counter_value = find_element_by_id(state2.dom_tree, "counter-value")
      assert counter_value.content == "1"

      # Success log present
      assert Enum.any?(state2.console_output, fn log ->
        log.level == "log" and String.contains?(log.message, "incremented")
      end)
    end
  end

  # Helper: Build a buggy counter (missing proper null checks)
  defp build_buggy_counter do
    %{
      designed: %{
        dom_tree: %{
          tag: "div",
          id: "root",
          classes: ["counter-app"],
          attributes: %{},
          handlers: %{},
          content: nil,
          children: [
            %{
              tag: "div",
              id: "counter-value",
              classes: ["value"],
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
            }
          ]
        },
        custom_css: %{},
        custom_functions: %{
          # Buggy function - tries to access .value on a div (which doesn't have it)
          "incrementCounter" => """
          function incrementCounter() {
            const display = document.getElementById('counter-display');
            const current = parseInt(display.value);
            display.value = current + 1;
            console.log('Counter incremented to', current + 1);
          }
          """
        },
        custom_variables: %{},
        init_scripts: %{},
        handlers: %{
          "increment-btn" => %{click: "incrementCounter()"}
        }
      },
      modifications: []
    }
  end

  # Helper: Build a working counter
  defp build_working_counter do
    %{
      designed: %{
        dom_tree: %{
          tag: "div",
          id: "root",
          classes: ["counter-app"],
          attributes: %{},
          handlers: %{},
          content: nil,
          children: [
            %{
              tag: "div",
              id: "counter-value",
              classes: ["value"],
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
            }
          ]
        },
        custom_css: %{},
        custom_functions: %{
          # Fixed function - correctly uses textContent
          "incrementCounter" => """
          function incrementCounter() {
            const display = document.getElementById('counter-value');
            const current = parseInt(display.textContent);
            display.textContent = current + 1;
            console.log('Counter incremented to', current + 1);
          }
          """
        },
        custom_variables: %{},
        init_scripts: %{},
        handlers: %{
          "increment-btn" => %{click: "incrementCounter()"}
        }
      },
      modifications: []
    }
  end

  # Simulate JavaScript error occurring
  defp simulate_javascript_error(routine_id, lens_state, error_message) do
    # DOM unchanged (error prevented update)
    dom_tree_js = convert_to_js_format(lens_state.designed.dom_tree)

    DOMStateCache.add_dom_state(routine_id, %{
      "liveDOMTree" => dom_tree_js,
      "changeType" => "snapshot",
      "timestamp" => System.system_time(:millisecond)
    })

    # Error message in console
    ConsoleCache.add_message(routine_id, %{
      level: "error",
      message: error_message,
      timestamp: System.system_time(:millisecond)
    })

    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "snapshot:response:#{routine_id}",
      {:snapshot_ready, routine_id, DateTime.utc_now()}
    )
  end

  # Simulate successful increment
  defp simulate_successful_increment(routine_id, lens_state) do
    # Update counter value to 1
    modified_tree = update_element_content(lens_state.designed.dom_tree, "counter-value", "1")
    dom_tree_js = convert_to_js_format(modified_tree)

    DOMStateCache.add_dom_state(routine_id, %{
      "liveDOMTree" => dom_tree_js,
      "changeType" => "snapshot",
      "timestamp" => System.system_time(:millisecond)
    })

    # Success log
    ConsoleCache.add_message(routine_id, %{
      level: "log",
      message: "Counter incremented to 1",
      timestamp: System.system_time(:millisecond)
    })

    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "snapshot:response:#{routine_id}",
      {:snapshot_ready, routine_id, DateTime.utc_now()}
    )
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
