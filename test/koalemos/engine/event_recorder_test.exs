defmodule Koalemos.Engine.EventRecorderTest do
  use ExUnit.Case, async: false
  alias Koalemos.Engine.{EventRecorder, Observer}

  setup do
    # Start Observer if not running
    case GenServer.whereis(Observer) do
      nil -> start_supervised!(Observer)
      _pid -> :ok
    end

    # Subscribe to PubSub to capture events that Observer broadcasts
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine_events")

    # Clear any pending messages
    receive do
      _ -> :ok
    after
      0 -> :ok
    end

    :ok
  end

  describe "record_event/3" do
    test "extracts routine_id from state" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :init
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      assert event.routine_id == "test-123"
    end

    test "extracts routine_module from state.module" do
      state = %{
        routine_id: "test-123",
        module: MyApp.Routines.Example,
        current_step: :init
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      # Module atoms get serialized to strings by Observer
      assert event.routine_module == "MyApp.Routines.Example"
    end

    test "extracts step_id from state.current_step" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :execute
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      assert event.step_id == "execute"
    end

    test "falls back to state.current_node for step_id" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_node: :legacy_step
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      assert event.step_id == "legacy_step"
    end

    test "prefers current_step over current_node" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :new_step,
        current_node: :old_node
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      assert event.step_id == "new_step"
    end

    test "supports workflow_id as alias for routine_id" do
      state = %{
        workflow_id: "workflow-123",
        module: MyRoutine,
        current_step: :init
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      # workflow_id should be in the event (compatibility)
      assert event.workflow_id == "workflow-123"
    end

    test "sets event_type from parameter" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :init
      }

      EventRecorder.record_event(state, "custom_event_type")

      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "custom_event_type"
    end

    test "merges additional fields into event" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :init
      }

      additional = %{
        metadata: %{key: "value"},
        custom_field: 42
      }

      EventRecorder.record_event(state, "test_event", additional)

      assert_receive {:routine_event, event}, 1000
      # Observer serializes map keys - atom keys may stay as atoms
      assert event.metadata[:key] == "value" or event.metadata["key"] == "value"
      assert event.custom_field == 42
    end

    test "additional fields can override base fields" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :init
      }

      # Override routine_id in additional fields
      additional = %{routine_id: "override-456"}

      EventRecorder.record_event(state, "test_event", additional)

      assert_receive {:routine_event, event}, 1000
      # Additional fields take precedence
      assert event.routine_id == "override-456"
    end

    test "works with empty additional fields" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :init
      }

      EventRecorder.record_event(state, "test_event", %{})

      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "test_event"
    end

    test "works when additional fields parameter omitted" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :init
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "test_event"
    end

    test "handles state with extra fields gracefully" do
      state = %{
        routine_id: "test-123",
        module: MyRoutine,
        current_step: :init,
        # Extra fields that aren't used
        context: %{user: "alice"},
        status: :running,
        other_data: [1, 2, 3]
      }

      EventRecorder.record_event(state, "test_event")

      assert_receive {:routine_event, event}, 1000
      # Only extracts the fields it needs
      assert event.routine_id == "test-123"
      assert event.step_id == "init"
    end
  end

  describe "record_routine_started/4" do
    test "records routine_started event with all parameters" do
      EventRecorder.record_routine_started(
        "routine-abc",
        MyApp.Routines.Test,
        %{initial: "context"},
        true
      )

      assert_receive {:routine_event, event}, 1000
      assert event.routine_id == "routine-abc"
      assert event.routine_module == "MyApp.Routines.Test"
      assert event.event_type == "routine_started"
    end

    test "sets step_id to :start" do
      EventRecorder.record_routine_started(
        "routine-abc",
        MyApp.Routines.Test,
        %{},
        true
      )

      assert_receive {:routine_event, event}, 1000
      assert event.step_id == "start"
    end

    test "includes initial context in context_diff" do
      initial_context = %{user: "alice", mode: "test"}

      EventRecorder.record_routine_started(
        "routine-abc",
        MyApp.Routines.Test,
        initial_context,
        true
      )

      assert_receive {:routine_event, event}, 1000
      # context_diff is serialized, check structure exists
      assert is_map(event.context_diff)
      # The :add key and values are in there, just verify structure
      add_data = event.context_diff[:add] || event.context_diff["add"]
      assert add_data[:user] == "alice" or add_data["user"] == "alice"
    end

    test "includes auto_execute in metadata" do
      EventRecorder.record_routine_started(
        "routine-abc",
        MyApp.Routines.Test,
        %{},
        true
      )

      assert_receive {:routine_event, event}, 1000
      # Check metadata contains auto_execute (key might be atom or string)
      auto_exec = event.metadata[:auto_execute] || event.metadata["auto_execute"]
      assert auto_exec == true or auto_exec == "true"
    end

    test "handles auto_execute false" do
      EventRecorder.record_routine_started(
        "routine-abc",
        MyApp.Routines.Test,
        %{},
        false
      )

      assert_receive {:routine_event, event}, 1000
      # Check metadata contains auto_execute false (key might be atom or string)
      auto_exec = event.metadata[:auto_execute] || event.metadata["auto_execute"]
      assert auto_exec == false or auto_exec == "false"
    end

    test "handles empty initial context" do
      EventRecorder.record_routine_started(
        "routine-abc",
        MyApp.Routines.Test,
        %{},
        true
      )

      assert_receive {:routine_event, event}, 1000
      # Just verify the structure exists
      assert is_map(event.context_diff)
      add_data = event.context_diff[:add] || event.context_diff["add"]
      assert is_map(add_data)
    end

    test "handles complex initial context" do
      initial_context = %{
        user: %{name: "alice", id: 123},
        config: %{debug: true, timeout: 5000},
        items: [1, 2, 3]
      }

      EventRecorder.record_routine_started(
        "routine-abc",
        MyApp.Routines.Test,
        initial_context,
        true
      )

      assert_receive {:routine_event, event}, 1000
      # Verify structure exists (serialization may change exact format)
      assert is_map(event.context_diff)
      # Check both atom and string keys for nested structure
      add_data = event.context_diff[:add] || event.context_diff["add"]
      assert is_map(add_data)
    end
  end

  describe "integration with Observer" do
    test "events are broadcast to PubSub topics" do
      # Subscribe to routine-specific topic
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:integration-test")

      state = %{
        routine_id: "integration-test",
        module: MyRoutine,
        current_step: :test
      }

      EventRecorder.record_event(state, "integration_event")

      # Should receive on both global and routine-specific topics
      assert_receive {:routine_event, _event}, 1000
    end

    test "multiple events are recorded independently" do
      state = %{
        routine_id: "multi-test",
        module: MyRoutine,
        current_step: :step1
      }

      EventRecorder.record_event(state, "event1")
      EventRecorder.record_event(state, "event2")
      EventRecorder.record_event(state, "event3")

      assert_receive {:routine_event, event1}, 1000
      assert_receive {:routine_event, event2}, 1000
      assert_receive {:routine_event, event3}, 1000

      assert event1.event_type == "event1"
      assert event2.event_type == "event2"
      assert event3.event_type == "event3"
    end
  end
end
