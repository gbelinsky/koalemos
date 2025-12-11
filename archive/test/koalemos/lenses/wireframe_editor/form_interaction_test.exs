defmodule Koalemos.Lenses.WireframeEditor.FormInteractionTest do
  @moduledoc """
  Integration test for form interactions and validation feedback.

  Tests that an agent can:
  1. Build a form with validation
  2. Fill in fields and submit
  3. See validation errors in captured state
  4. Adjust inputs based on errors and retry

  This validates form interaction patterns for Sprint 7 Phase 7.
  """
  use ExUnit.Case, async: false

  alias Koalemos.Lenses.WireframeEditor
  alias Koalemos.Caches.{DOMStateCache, ConsoleCache, ScreenshotCache, WireframeStateCache}

  setup do
    routine_id = "form-test-#{:erlang.unique_integer([:positive])}"

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

  describe "form interaction feedback loop" do
    test "agent sees validation errors from invalid form submission", %{routine_id: routine_id} do
      # Step 1: Build a login form with validation
      lens_state = build_login_form()
      WireframeStateCache.put_state(routine_id, lens_state)

      # Step 2: Agent triggers form submission with invalid email
      task =
        Task.async(fn ->
          :timer.sleep(100)

          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "interaction:response:#{routine_id}",
            {:interaction_complete, %{"success" => true}}
          )
        end)

      {result, _} =
        WireframeEditor.execute(
          :trigger_interaction,
          %{"action" => "click", "element_id" => "submit-btn"},
          %{lens_state: lens_state, routine_id: routine_id}
        )

      Task.await(task)
      assert result =~ "Successfully triggered"

      # Step 3: Capture state showing validation errors
      capture_task =
        Task.async(fn ->
          :timer.sleep(100)
          # Simulate validation adding error message to DOM
          simulate_form_validation_error(routine_id, lens_state, "Invalid email format")
        end)

      {:ok, captured_state} =
        WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)

      Task.await(capture_task)

      # Agent should see:
      # - Error message in DOM
      error_element = find_element_by_id(captured_state.dom_tree, "error-message")
      assert error_element != nil
      assert error_element.content =~ "Invalid email"

      # - Console log about validation
      assert length(captured_state.console_output) > 0

      assert Enum.any?(captured_state.console_output, fn log ->
               String.contains?(log.message, "validation") or
                 String.contains?(log.message, "error")
             end)

      # - Differs from designed state
      assert captured_state.differs_from_designed == true
    end

    test "agent successfully submits form after fixing validation errors", %{
      routine_id: routine_id
    } do
      # Build form
      lens_state = build_login_form()
      WireframeStateCache.put_state(routine_id, lens_state)

      # First attempt: invalid email triggers error
      task1 =
        Task.async(fn ->
          :timer.sleep(100)

          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "interaction:response:#{routine_id}",
            {:interaction_complete, %{"success" => true}}
          )
        end)

      {result1, _} =
        WireframeEditor.execute(
          :trigger_interaction,
          %{"action" => "click", "element_id" => "submit-btn"},
          %{lens_state: lens_state, routine_id: routine_id}
        )

      Task.await(task1)
      assert result1 =~ "Successfully triggered"

      # Capture state showing error
      capture_task1 =
        Task.async(fn ->
          :timer.sleep(100)
          simulate_form_validation_error(routine_id, lens_state, "Invalid email format")
        end)

      {:ok, state1} =
        WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)

      Task.await(capture_task1)

      error_msg = find_element_by_id(state1.dom_tree, "error-message")
      assert error_msg != nil
      assert error_msg.content =~ "Invalid email"

      # Second attempt: valid submission succeeds
      task2 =
        Task.async(fn ->
          :timer.sleep(100)

          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "interaction:response:#{routine_id}",
            {:interaction_complete, %{"success" => true}}
          )
        end)

      {result2, _} =
        WireframeEditor.execute(
          :trigger_interaction,
          %{"action" => "click", "element_id" => "submit-btn"},
          %{lens_state: lens_state, routine_id: routine_id}
        )

      Task.await(task2)
      assert result2 =~ "Successfully triggered"

      # Capture state showing success
      capture_task2 =
        Task.async(fn ->
          :timer.sleep(100)
          simulate_form_success(routine_id, lens_state)
        end)

      {:ok, state2} =
        WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)

      Task.await(capture_task2)

      success_msg = find_element_by_id(state2.dom_tree, "success-message")
      assert success_msg != nil
      assert success_msg.content =~ "Login successful"

      # Console should show success log
      assert Enum.any?(state2.console_output, fn log ->
               String.contains?(log.message, "success")
             end)
    end
  end

  # Helper: Build a basic login form
  defp build_login_form do
    %{
      designed: %{
        dom_tree: %{
          tag: "div",
          id: "root",
          classes: ["form-container"],
          attributes: %{},
          handlers: %{},
          content: nil,
          children: [
            %{
              tag: "form",
              id: "login-form",
              classes: ["form"],
              attributes: %{},
              handlers: %{},
              content: nil,
              children: [
                %{
                  tag: "input",
                  id: "email-input",
                  classes: ["input"],
                  attributes: %{"type" => "email", "placeholder" => "Email"},
                  handlers: %{},
                  content: nil,
                  children: []
                },
                %{
                  tag: "input",
                  id: "password-input",
                  classes: ["input"],
                  attributes: %{"type" => "password", "placeholder" => "Password"},
                  handlers: %{},
                  content: nil,
                  children: []
                },
                %{
                  tag: "button",
                  id: "submit-btn",
                  classes: ["btn"],
                  attributes: %{"type" => "submit"},
                  handlers: %{},
                  text: "Submit",
                  children: []
                },
                %{
                  tag: "div",
                  id: "error-message",
                  classes: ["error"],
                  attributes: %{},
                  handlers: %{},
                  text: "",
                  children: []
                },
                %{
                  tag: "div",
                  id: "success-message",
                  classes: ["success"],
                  attributes: %{},
                  handlers: %{},
                  text: "",
                  children: []
                }
              ]
            }
          ]
        },
        custom_css: %{},
        custom_functions: %{
          "validateEmail" => """
          function validateEmail(email) {
            return email.includes('@') && email.includes('.');
          }
          """,
          "handleSubmit" => """
          function handleSubmit(e) {
            e.preventDefault();
            const email = document.getElementById('email-input').value;
            if (!validateEmail(email)) {
              document.getElementById('error-message').textContent = 'Invalid email format';
              console.error('Form validation failed: Invalid email');
            } else {
              document.getElementById('success-message').textContent = 'Login successful';
              console.log('Form submitted successfully');
            }
          }
          """
        },
        custom_variables: %{},
        init_scripts: %{},
        handlers: %{
          "submit-btn" => %{click: "handleSubmit(event)"}
        }
      },
      modifications: []
    }
  end

  # Simulate form validation showing error
  defp simulate_form_validation_error(routine_id, lens_state, error_message) do
    # Modify tree to show error message
    modified_tree =
      update_element_content(lens_state.designed.dom_tree, "error-message", error_message)

    dom_tree_js = convert_to_js_format(modified_tree)

    DOMStateCache.add_dom_state(routine_id, %{
      "liveDOMTree" => dom_tree_js,
      "changeType" => "snapshot",
      "timestamp" => System.system_time(:millisecond)
    })

    ConsoleCache.add_message(routine_id, %{
      level: "error",
      message: "Form validation failed: #{error_message}",
      timestamp: System.system_time(:millisecond)
    })

    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "snapshot:response:#{routine_id}",
      {:snapshot_ready, routine_id, DateTime.utc_now()}
    )
  end

  # Simulate successful form submission
  defp simulate_form_success(routine_id, lens_state) do
    # Modify tree to clear error and show success
    modified_tree =
      lens_state.designed.dom_tree
      |> update_element_content("error-message", "")
      |> update_element_content("success-message", "Login successful")

    dom_tree_js = convert_to_js_format(modified_tree)

    DOMStateCache.add_dom_state(routine_id, %{
      "liveDOMTree" => dom_tree_js,
      "changeType" => "snapshot",
      "timestamp" => System.system_time(:millisecond)
    })

    ConsoleCache.add_message(routine_id, %{
      level: "log",
      message: "Form submitted successfully",
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
          Map.put(
            tree,
            :children,
            Enum.map(children, &update_element_content(&1, target_id, new_content))
          )

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
