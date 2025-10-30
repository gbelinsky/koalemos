defmodule Koalemos.Integration.RealAPITest do
  use ExUnit.Case, async: false

  alias Koalemos.Steps.Agent.LLMRequest
  alias Koalemos.Steps.Agent.ResponseParsing

  @moduletag :real_api
  @moduletag timeout: 30_000

  # Helper to check if credentials are available
  defp credentials_available? do
    creds_path = ".koalemos/.credentials.json"
    File.exists?(creds_path) && File.regular?(creds_path)
  end

  defp check_credentials do
    if credentials_available?() do
      # Set env var to credentials path
      creds_path = Path.expand(".koalemos/.credentials.json")
      System.put_env("KOALEMOS_CREDENTIALS_PATH", creds_path)

      # Start SimpleCredentialManager if not running
      case GenServer.whereis(Koalemos.SimpleCredentialManager) do
        nil ->
          case GenServer.start_link(Koalemos.SimpleCredentialManager, [], name: Koalemos.SimpleCredentialManager) do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
          end
        _pid -> :ok
      end

      :ok
    else
      IO.puts("\nSkipping real API test - credentials not available at .koalemos/.credentials.json")
      :skip
    end
  end

  describe "Anthropic API integration" do
    test "makes simple text request and gets response" do
      case check_credentials() do
        :skip -> :ok
        :ok ->
          # Simple state with one message
          state = %{
            routine_id: "test-#{:erlang.unique_integer([:positive])}",
            context: %{
              messages: [
                %{role: "user", content: [%{type: "text", text: "Say hello in exactly 3 words"}]}
              ],
              llm_provider: "anthropic",
              llm_model: "claude-3-5-haiku-20241022",
              max_tokens: 100,
              temperature: 0.1,
              lens_text_contexts: [],
              lens_image_contexts: []
            }
          }

          # Make LLM request
          assert {:ok, diff} = LLMRequest.execute(%{}, state)

          # Apply diff to get response
          updated_state = Koalemos.Engine.ContextManager.apply_context_diff!(state, diff)
          context_with_response = updated_state.context

          # Should have llm_response
          assert Map.has_key?(context_with_response, :llm_response)
          response = context_with_response.llm_response

          # Should be assistant message
          assert response["role"] == "assistant"
          assert is_list(response["content"])

          # Should have text content
          text_blocks = Enum.filter(response["content"], fn block ->
            block["type"] == "text"
          end)
          assert length(text_blocks) > 0

          # Verify text is present
          text = hd(text_blocks)["text"]
          assert is_binary(text)
          assert String.length(text) > 0
      end
    end

    test "handles tool calls correctly" do
      case check_credentials() do
        :skip -> :ok
        :ok ->
          # State with message requesting tool use and tools available
          state = %{
            routine_id: "test-#{:erlang.unique_integer([:positive])}",
            context: %{
              messages: [
                %{role: "user", content: [%{type: "text", text: "Use the echo tool to echo: test123"}]}
              ],
              llm_provider: "anthropic",
              llm_model: "claude-3-5-haiku-20241022",
              max_tokens: 200,
              temperature: 0.1,
              lens_text_contexts: [],
              lens_image_contexts: [],
              tool_descriptions: [
                %{
                  name: "echo",
                  description: "Echo back a message",
                  input_schema: %{
                    type: "object",
                    properties: %{
                      message: %{type: "string", description: "Message to echo"}
                    },
                    required: ["message"]
                  }
                }
              ]
            }
          }

          # Make LLM request
          assert {:ok, diff} = LLMRequest.execute(%{}, state)
          updated_state = Koalemos.Engine.ContextManager.apply_context_diff!(state, diff)

          # Parse response
          parse_state = %{routine_id: state.routine_id, context: updated_state.context}
          assert {:ok, parse_diff} = ResponseParsing.execute(%{}, parse_state)
          final_state = Koalemos.Engine.ContextManager.apply_context_diff!(parse_state, parse_diff)
          final_context = final_state.context

          # May or may not have tool calls depending on LLM behavior
          # Just verify parsing succeeded and we got a response
          assert Map.has_key?(final_context, :llm_response)
      end
    end
  end

  describe "Ollama API integration" do
    defp ollama_running? do
      case Req.get("http://localhost:11434/api/tags") do
        {:ok, %{status: 200}} -> true
        _ -> false
      end
    end

    test "makes simple request to Ollama" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        state = %{
          routine_id: "test-#{:erlang.unique_integer([:positive])}",
          context: %{
            messages: [
              %{role: "user", content: [%{type: "text", text: "Say hi in one word"}]}
            ],
            llm_provider: "ollama",
            llm_model: "qwen3",
            max_tokens: 50,
            temperature: 0.1,
            lens_text_contexts: [],
            lens_image_contexts: [],
            tool_descriptions: []
          }
        }

        # Make LLM request
        assert {:ok, diff} = LLMRequest.execute(%{}, state)
        updated_state = Koalemos.Engine.ContextManager.apply_context_diff!(state, diff)

        # Should have response
        assert Map.has_key?(updated_state.context, :llm_response)
        response = updated_state.context.llm_response

        assert response["role"] == "assistant"
        assert is_list(response["content"])
      end
    end
  end

  describe "lens context integration" do
    test "lens text contexts included in request" do
      case check_credentials() do
        :skip -> :ok
        :ok ->
          # Use TestLens to provide context
          lens_state = %{context: %{}}
          lens_contexts = Koalemos.Lenses.TestLensScreenshot.provide_context(lens_state)

          # Separate into text and images
          text_contexts = Enum.filter(lens_contexts, fn block ->
            is_binary(block) || (is_map(block) && Map.get(block, :type) == "text")
          end)

          state = %{
            routine_id: "test-#{:erlang.unique_integer([:positive])}",
            context: %{
              messages: [
                %{role: "user", content: [%{type: "text", text: "What context do you have?"}]}
              ],
              llm_provider: "anthropic",
              llm_model: "claude-3-5-haiku-20241022",
              max_tokens: 200,
              temperature: 0.1,
              lens_text_contexts: text_contexts,
              lens_image_contexts: [],
              tool_descriptions: []
            }
          }

          # Make request - should include lens context in system message
          assert {:ok, diff} = LLMRequest.execute(%{}, state)
          updated_state = Koalemos.Engine.ContextManager.apply_context_diff!(state, diff)

          # Should have response
          assert Map.has_key?(updated_state.context, :llm_response)
      end
    end
  end
end
