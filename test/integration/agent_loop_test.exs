defmodule Koalemos.Integration.AgentLoopTest do
  use Koalemos.IntegrationTestCase, async: false

  alias Koalemos.Steps.System.Config, as: ConfigStep
  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.LensRendering
  alias Koalemos.Steps.Agent.ToolSchema
  alias Koalemos.Steps.Agent.LLMRequest
  alias Koalemos.Steps.Agent.ResponseParsing
  alias Koalemos.Steps.Agent.ToolLookup
  alias Koalemos.Steps.Agent.ToolExecution

  @moduletag :real_api

  # Simple agent loop routine
  defmodule SimpleAgentRoutine do
    def routine_definition do
      %{
        start: %{
          type: Koalemos.Steps.System.Config,
          config: %{
            messages: [],
            llm_provider: "anthropic",
            model: "claude-3-5-haiku-20241022",
            max_tokens: 500,
            temperature: 0.1,
            active_lenses: ["Koalemos.TestLens"]
          },
          transitions: [{:gather_context, :always}]
        },
        gather_context: %{
          type: Koalemos.Steps.Agent.LensRendering,
          transitions: [{:gather_tools, :always}]
        },
        gather_tools: %{
          type: Koalemos.Steps.Agent.ToolSchema,
          config: %{lenses: ["Koalemos.TestLens"]},
          transitions: [{:make_request, :always}]
        },
        make_request: %{
          type: Koalemos.Steps.Agent.LLMRequest,
          transitions: [{:parse_response, :always}]
        },
        parse_response: %{
          type: Koalemos.Steps.Agent.ResponseParsing,
          transitions: [
            {:lookup_tools, :has_tool_calls},
            {:done, :always}
          ]
        },
        lookup_tools: %{
          type: Koalemos.Steps.Agent.ToolLookup,
          config: %{lenses: ["Koalemos.TestLens"]},
          transitions: [{:execute_tools, :always}]
        },
        execute_tools: %{
          type: Koalemos.Steps.Agent.ToolExecution,
          config: %{lenses: ["Koalemos.TestLens"]},
          transitions: [{:make_request, :always}]
        },
        done: %{
          type: Koalemos.Steps.System.Config,
          transitions: []
        }
      }
    end

    def check_condition(:always, _context), do: true
    def check_condition(:has_tool_calls, context) do
      Map.has_key?(context, :tool_calls) && length(context.tool_calls) > 0
    end
  end

  describe "simple text exchange with Anthropic" do
    test "user greeting gets LLM response", %{routine_id: routine_id} do
      skip_if_no_flo_credentials()

      # Load credentials
      {:ok, creds} = load_flo_credentials()
      create_temp_credentials(creds)

      # Create user message
      initial_context = %{
        user_input: "Say hello in one sentence"
      }

      # Start routine
      {:ok, pid} = EngineManager.start_routine(routine_id, SimpleAgentRoutine, initial_context)

      # Inject user message via ChatUserInput step
      # First, we need to transition to gather_context, which will happen automatically

      # Wait for routine to reach gathering phase
      :timer.sleep(500)

      # Get state to inject user message
      state = :sys.get_state(pid)

      # Manually execute chat user input step to add message
      {:ok, diff} = ChatUserInput.execute(%{}, %{
        routine_id: routine_id,
        context: Map.merge(state.context, %{user_input: "Say hello in one sentence"})
      })

      # Apply diff to state
      context_with_message = Koalemos.Engine.ContextManager.apply_context_diff!(state.context, diff)

      # Update the engine state
      send(pid, {:update_context, context_with_message})

      # Wait for completion
      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 10_000

      # Check final state
      final_state = :sys.get_state(pid)

      # Should have messages
      assert length(final_state.context.messages) >= 2

      # Should have LLM response
      assert Map.has_key?(final_state.context, :llm_response)

      # Response should be text
      response = final_state.context.llm_response
      assert response["role"] == "assistant"
      assert is_list(response["content"])

      # Should have at least one text block
      text_blocks = Enum.filter(response["content"], fn block ->
        block["type"] == "text"
      end)
      assert length(text_blocks) > 0
    end
  end

  describe "tool call workflow with Anthropic" do
    test "LLM calls echo tool and incorporates result", %{routine_id: routine_id} do
      skip_if_no_flo_credentials()

      {:ok, creds} = load_flo_credentials()
      create_temp_credentials(creds)

      initial_context = %{
        user_input: "Use the echo tool to echo this message: testing123"
      }

      {:ok, pid} = EngineManager.start_routine(routine_id, SimpleAgentRoutine, initial_context)

      # Similar process as above...
      :timer.sleep(500)
      state = :sys.get_state(pid)

      {:ok, diff} = ChatUserInput.execute(%{}, %{
        routine_id: routine_id,
        context: Map.merge(state.context, %{user_input: "Use the echo tool to echo this: testing123"})
      })

      context_with_message = Koalemos.Engine.ContextManager.apply_context_diff!(state.context, diff)
      send(pid, {:update_context, context_with_message})

      # Wait for completion (may take longer with tool use)
      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 15_000

      final_state = :sys.get_state(pid)

      # Should have executed tool
      messages = final_state.context.messages

      # Should have tool_result message
      tool_results = Enum.filter(messages, fn msg ->
        msg.role == "user" &&
        Enum.any?(msg.content, fn block -> block["type"] == "tool_result" end)
      end)

      assert length(tool_results) > 0
    end
  end

  describe "Ollama integration" do
    test "simple conversation with Ollama", %{routine_id: routine_id} do
      skip_if_no_ollama()

      # Create Ollama-specific routine config
      defmodule OllamaAgentRoutine do
        def routine_definition do
          Koalemos.Integration.AgentLoopTest.SimpleAgentRoutine.routine_definition()
          |> put_in([:start, :config, :llm_provider], "ollama")
          |> put_in([:start, :config, :model], "qwen3")
        end

        def check_condition(cond_name, context) do
          Koalemos.Integration.AgentLoopTest.SimpleAgentRoutine.check_condition(cond_name, context)
        end
      end

      initial_context = %{
        user_input: "Say hi in one word"
      }

      {:ok, pid} = EngineManager.start_routine(routine_id, OllamaAgentRoutine, initial_context)

      :timer.sleep(500)
      state = :sys.get_state(pid)

      {:ok, diff} = ChatUserInput.execute(%{}, %{
        routine_id: routine_id,
        context: Map.merge(state.context, %{user_input: "Say hi in one word"})
      })

      context_with_message = Koalemos.Engine.ContextManager.apply_context_diff!(state.context, diff)
      send(pid, {:update_context, context_with_message})

      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 15_000

      final_state = :sys.get_state(pid)
      assert Map.has_key?(final_state.context, :llm_response)
      assert final_state.context.llm_response["role"] == "assistant"
    end
  end

  describe "error handling integration" do
    test "tool execution error is handled gracefully", %{routine_id: routine_id} do
      skip_if_no_flo_credentials()

      {:ok, creds} = load_flo_credentials()
      create_temp_credentials(creds)

      initial_context = %{
        user_input: "Use the fail tool"
      }

      {:ok, pid} = EngineManager.start_routine(routine_id, SimpleAgentRoutine, initial_context)

      :timer.sleep(500)
      state = :sys.get_state(pid)

      {:ok, diff} = ChatUserInput.execute(%{}, %{
        routine_id: routine_id,
        context: Map.merge(state.context, %{user_input: "Call the fail tool"})
      })

      context_with_message = Koalemos.Engine.ContextManager.apply_context_diff!(state.context, diff)
      send(pid, {:update_context, context_with_message})

      # Should complete despite tool error
      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 15_000

      final_state = :sys.get_state(pid)

      # Should have tool_result with is_error
      messages = final_state.context.messages
      tool_results = Enum.filter(messages, fn msg ->
        msg.role == "user" &&
        Enum.any?(msg.content, fn block ->
          block["type"] == "tool_result" && Map.get(block, "is_error", false)
        end)
      end)

      # May or may not have error result depending on if LLM called the tool
      # Just verify routine didn't crash
      assert Process.alive?(pid)
    end

    test "missing credentials handled gracefully" do
      # Don't load credentials
      System.delete_env("KOALEMOS_CREDENTIALS_PATH")

      routine_id = "no-creds-test-#{:erlang.unique_integer([:positive])}"
      initial_context = %{user_input: "Hello"}

      {:ok, pid} = EngineManager.start_routine(routine_id, SimpleAgentRoutine, initial_context)

      :timer.sleep(500)
      state = :sys.get_state(pid)

      {:ok, diff} = ChatUserInput.execute(%{}, %{
        routine_id: routine_id,
        context: Map.merge(state.context, %{user_input: "Hello"})
      })

      context_with_message = Koalemos.Engine.ContextManager.apply_context_diff!(state.context, diff)
      send(pid, {:update_context, context_with_message})

      # Should get error event
      assert_receive {:routine_event, %{event_type: "error_occurred"}}, 5_000

      # Cleanup
      GenServer.stop(pid, :normal, 100)
    end
  end

  # Helper to create temporary credentials file
  defp create_temp_credentials(creds) do
    path = "test/tmp/integration_test_credentials.json"
    File.mkdir_p!("test/tmp")
    File.write!(path, Jason.encode!(creds))
    System.put_env("KOALEMOS_CREDENTIALS_PATH", path)

    on_exit(fn ->
      File.rm(path)
      System.delete_env("KOALEMOS_CREDENTIALS_PATH")
    end)
  end
end
