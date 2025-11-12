defmodule Koalemos.Engine.ObserverTest do
  # Not async because we're using a named GenServer
  use ExUnit.Case, async: false
  alias Koalemos.Engine.Observer

  @test_log_file "tmp/test_events.log"

  setup do
    # Clean up log file before each test
    File.rm(@test_log_file)
    File.mkdir_p("tmp")

    # Start Observer if not running
    case GenServer.whereis(Observer) do
      nil -> start_supervised!(Observer)
      _pid -> :ok
    end

    # Subscribe to PubSub topics for testing
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine_events")

    on_exit(fn ->
      # Clean up log file after test
      File.rm(@test_log_file)
    end)

    :ok
  end

  describe "record_event/1 - basic functionality" do
    test "records event and broadcasts to PubSub" do
      event = %{
        routine_id: "test-123",
        event_type: "step_started",
        metadata: %{step: :init}
      }

      Observer.record_event(event)

      # Should receive PubSub broadcast
      assert_receive {:routine_event, received_event}, 1000

      assert received_event.routine_id == "test-123"
      assert received_event.event_type == "step_started"
    end

    test "broadcasts to routine-specific topic" do
      routine_id = "specific-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")

      event = %{routine_id: routine_id, event_type: "test"}

      Observer.record_event(event)

      # Should receive on routine-specific topic
      assert_receive {:routine_event, received_event}, 1000
      assert received_event.routine_id == routine_id
    end

    test "handles events without routine_id" do
      event = %{event_type: "global_event", data: "test"}

      Observer.record_event(event)

      # Should still broadcast to global topic
      assert_receive {:routine_event, received_event}, 1000
      assert received_event.event_type == "global_event"
    end
  end

  describe "serialization" do
    test "serializes DateTime to ISO8601 string" do
      dt = ~U[2024-10-27 12:00:00Z]
      event = %{routine_id: "test", datetime_field: dt}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert is_binary(received.datetime_field)
      assert received.datetime_field == "2024-10-27T12:00:00Z"
    end

    test "serializes tuples to lists" do
      event = %{routine_id: "test", tuple_data: {:ok, "result", 123}}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      # Atoms within tuples also get serialized to strings
      assert received.tuple_data == ["ok", "result", 123]
    end

    test "serializes nested tuples" do
      event = %{routine_id: "test", data: {:error, {:nested, "value"}}}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      # Atoms within tuples also get serialized to strings
      assert received.data == ["error", ["nested", "value"]]
    end

    test "serializes functions to string representation" do
      fun = fn x -> x + 1 end
      event = %{routine_id: "test", function: fun}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert is_binary(received.function)
      assert String.starts_with?(received.function, "#Function<")
    end

    test "serializes PIDs to string" do
      pid = self()
      event = %{routine_id: "test", pid: pid}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert is_binary(received.pid)
      assert String.starts_with?(received.pid, "#PID<")
    end

    test "serializes references to string" do
      ref = make_ref()
      event = %{routine_id: "test", ref: ref}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert is_binary(received.ref)
      assert String.starts_with?(received.ref, "#Ref<")
    end

    test "strips Elixir prefix from module atoms" do
      event = %{routine_id: "test", module: Koalemos.Engine.Observer}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert received.module == "Koalemos.Engine.Observer"
    end

    test "preserves plain atoms" do
      event = %{routine_id: "test", status: :ok, type: :test}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert received.status == "ok"
      assert received.type == "test"
    end

    test "handles complex nested structures" do
      event = %{
        routine_id: "test",
        complex: %{
          list: [1, {:tuple, "value"}, %{nested: :map}],
          datetime: ~U[2024-10-27 12:00:00Z],
          pid: self()
        }
      }

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert is_list(received.complex.list)
      assert is_binary(received.complex.datetime)
      assert is_binary(received.complex.pid)
    end
  end

  describe "message change detection" do
    test "broadcasts new messages to message-specific topic" do
      routine_id = "msg-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      # Send context_changed event with a message
      event = %{
        routine_id: routine_id,
        event_type: "context_changed",
        context_diff: [
          [:append_to, %{messages: %{role: "user", content: "hello", metadata: %{id: "msg-1"}}}]
        ]
      }

      Observer.record_event(event)

      # Should receive new message broadcast
      assert_receive {:new_messages, messages}, 1000
      assert length(messages) == 1
      # Messages come through with atom keys converted to strings
      first_msg = hd(messages)
      assert first_msg["content"] == "hello" or first_msg[:content] == "hello"
    end

    test "does not broadcast duplicate messages" do
      routine_id = "dedup-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      message = %{role: "user", content: "hello", metadata: %{id: "msg-1"}}

      # Send same message twice
      event = %{
        routine_id: routine_id,
        event_type: "context_changed",
        context_diff: [[:append_to, %{messages: message}]]
      }

      Observer.record_event(event)
      assert_receive {:new_messages, _}, 1000

      # Send again - should not receive duplicate
      Observer.record_event(event)
      refute_receive {:new_messages, _}, 100
    end

    test "tracks messages across multiple events" do
      routine_id = "multi-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      # First message
      event1 = %{
        routine_id: routine_id,
        event_type: "context_changed",
        context_diff: [[:append_to, %{messages: %{content: "first", metadata: %{id: "msg-1"}}}]]
      }

      Observer.record_event(event1)
      assert_receive {:new_messages, messages}, 1000
      assert length(messages) == 1

      # Second message
      event2 = %{
        routine_id: routine_id,
        event_type: "context_changed",
        context_diff: [[:append_to, %{messages: %{content: "second", metadata: %{id: "msg-2"}}}]]
      }

      Observer.record_event(event2)
      assert_receive {:new_messages, messages}, 1000
      assert length(messages) == 1
      second_msg = hd(messages)
      assert second_msg["content"] == "second" or second_msg[:content] == "second"
    end

    test "handles messages without metadata by generating ID" do
      routine_id = "no-meta-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      # Message without metadata
      event = %{
        routine_id: routine_id,
        event_type: "context_changed",
        context_diff: [[:append_to, %{messages: %{content: "no metadata"}}]]
      }

      Observer.record_event(event)
      # Messages without metadata get a generated "legacy_<hash>" ID
      # The system handles this gracefully by generating an ID from content hash
      assert_receive {:new_messages, messages}, 1000
      # Should receive the message even without explicit metadata
      assert is_list(messages)
    end

    test "handles list of messages in append_to" do
      routine_id = "list-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      messages = [
        %{content: "first", metadata: %{id: "msg-1"}},
        %{content: "second", metadata: %{id: "msg-2"}}
      ]

      event = %{
        routine_id: routine_id,
        event_type: "context_changed",
        context_diff: [[:append_to, %{messages: messages}]]
      }

      Observer.record_event(event)
      assert_receive {:new_messages, received_messages}, 1000
      assert length(received_messages) == 2
    end

    test "ignores events without messages" do
      routine_id = "no-msg-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      event = %{
        routine_id: routine_id,
        event_type: "context_changed",
        context_diff: [[:add, %{other_data: "value"}]]
      }

      Observer.record_event(event)
      refute_receive {:new_messages, _}, 100
    end

    test "ignores non-context_changed events" do
      routine_id = "other-event-routine-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      event = %{
        routine_id: routine_id,
        event_type: "step_started",
        metadata: %{messages: [%{content: "should be ignored"}]}
      }

      Observer.record_event(event)
      refute_receive {:new_messages, _}, 100
    end
  end

  describe "workflow_id compatibility" do
    test "accepts workflow_id as alias for routine_id" do
      workflow_id = "workflow-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{workflow_id}")

      event = %{workflow_id: workflow_id, event_type: "test"}

      Observer.record_event(event)

      assert_receive {:routine_event, received}, 1000
      assert received.workflow_id == workflow_id
    end

    test "extracts messages using workflow_id" do
      workflow_id = "wf-msg-#{:rand.uniform(10000)}"
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{workflow_id}:messages")

      event = %{
        workflow_id: workflow_id,
        event_type: "context_changed",
        context_diff: [[:append_to, %{messages: %{content: "test", metadata: %{id: "msg-1"}}}]]
      }

      Observer.record_event(event)
      assert_receive {:new_messages, messages}, 1000
      assert length(messages) == 1
    end
  end
end
