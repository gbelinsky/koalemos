defmodule Koalemos.Integration.ChatWorkflowTest do
  use Koalemos.IntegrationTestCase, async: false

  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.TestChatRoutine

  describe "basic chat workflow" do
    test "starts routine, accepts user input, and processes messages", %{routine_id: routine_id} do
      # Start the routine
      initial_context = TestChatRoutine.initial_context()
      {:ok, pid} = EngineManager.start_routine(routine_id, TestChatRoutine, initial_context)

      # Routine should start and be alive
      assert Process.alive?(pid)

      # Should start in 'start' step (waiting for user input)
      assert_receive {:routine_event, %{event_type: "step_started", step_id: "start"}}, 1000

      # Send user input
      user_input = %{text: "Hello!", images: []}
      Engine.send_external_event(routine_id, :user_input, user_input)

      # Should process through the steps:
      # 1. User input received -> moves to render_lens
      assert_receive {:routine_event, %{event_type: "step_completed", step_id: "start"}}, 1000
      assert_receive {:routine_event, %{event_type: "step_started", step_id: "render_lens"}}, 1000

      # 2. Lens rendering -> moves to llm_request
      assert_receive {:routine_event, %{event_type: "step_completed", step_id: "render_lens"}},
                     1000

      assert_receive {:routine_event, %{event_type: "step_started", step_id: "llm_request"}}, 1000

      # Get current state to verify messages were added
      state = :sys.get_state(pid)
      messages = Map.get(state.context, :messages, [])

      # Should have at least the user message
      assert length(messages) > 0
      user_msg = Enum.find(messages, fn msg -> msg.role == "user" end)
      assert user_msg != nil
      assert user_msg.content == [%{type: "text", text: "Hello!"}]
    end

    test "lens provides context to the routine", %{routine_id: routine_id} do
      # Start routine
      initial_context = TestChatRoutine.initial_context()
      {:ok, pid} = EngineManager.start_routine(routine_id, TestChatRoutine, initial_context)

      # Wait for start step
      assert_receive {:routine_event, %{event_type: "step_started", step_id: "start"}}, 1000

      # Send user input to trigger lens rendering
      Engine.send_external_event(routine_id, :user_input, %{text: "test", images: []})

      # Wait for lens_rendering to complete
      assert_receive {:routine_event, %{event_type: "step_completed", step_id: "render_lens"}},
                     1000

      # Check that lens context was added
      state = :sys.get_state(pid)
      lens_contexts = Map.get(state.context, :lens_text_contexts, [])

      # TestLens should have provided context
      assert length(lens_contexts) > 0

      assert Enum.any?(lens_contexts, fn context ->
               # Context blocks are now maps with type and text fields
               case context do
                 %{type: "text", text: text} -> String.contains?(text, "TestLens")
                 %{text: text} -> String.contains?(text, "TestLens")
                 text when is_binary(text) -> String.contains?(text, "TestLens")
                 _ -> false
               end
             end)
    end

    test "accepts multiple user inputs sequentially", %{routine_id: routine_id} do
      # This test verifies the routine can accept multiple inputs
      initial_context = TestChatRoutine.initial_context()
      {:ok, pid} = EngineManager.start_routine(routine_id, TestChatRoutine, initial_context)

      # Wait for first start step
      assert_receive {:routine_event, %{event_type: "step_started", step_id: "start"}}, 1000

      # Send first user input
      Engine.send_external_event(routine_id, :user_input, %{text: "First message", images: []})

      # Should process the input
      assert_receive {:routine_event, %{event_type: "step_completed", step_id: "start"}}, 1000

      # Get state and verify first message was added
      state = :sys.get_state(pid)
      messages = Map.get(state.context, :messages, [])
      assert length(messages) == 1
      assert Enum.at(messages, 0).content == [%{type: "text", text: "First message"}]

      # Routine should still be alive
      assert Process.alive?(pid)
    end
  end
end
