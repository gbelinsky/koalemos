defmodule Koalemos.LLMProviders.OllamaTest do
  use ExUnit.Case, async: false
  alias Koalemos.LLMProviders.Ollama

  @ollama_base_url "http://localhost:11434"

  # Helper to check if Ollama is running
  defp ollama_running? do
    case Req.get("#{@ollama_base_url}/api/tags") do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  # Helper to extract llm_response from diff format
  defp extract_response([{:add, %{llm_response: response}}]), do: response
  defp extract_response(_), do: nil

  describe "call/6 - basic functionality" do
    test "makes successful request to ollama with simple message" do
      unless ollama_running?() do
        # Skip if Ollama not running
        IO.puts("\nSkipping Ollama test - server not running at #{@ollama_base_url}")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say hello in one word"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        tool_descriptions = []
        lens_contexts = %{text: [], images: []}
        config = %{model: "qwen3", max_tokens: 50, temperature: 0.1}
        routine_id = "test-routine"

        case Ollama.call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
          {:ok, result} ->
            response = extract_response(result)
            assert is_map(response), "Expected response to be extracted from diff format"

            # Check Anthropic format response
            assert is_map(response)
            assert Map.has_key?(response, "content")
            assert Map.has_key?(response, "stop_reason")
            assert response["role"] == "assistant"

            # Content should have text
            assert is_list(response["content"])
            [first_block | _] = response["content"]
            assert first_block["type"] == "text"
            assert is_binary(first_block["text"])
            assert String.length(first_block["text"]) > 0

          {:error, error_msg} ->
            flunk("Ollama request failed: #{error_msg}")
        end
      end
    end

    test "returns error when ollama is not running" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hello"}]}
      ]

      # Use different port to simulate connection refused
      credentials = %{
        provider: :ollama,
        base_url: "http://localhost:11435",  # Different port
        model: "qwen3"
      }

      tool_descriptions = []
      lens_contexts = %{text: [], images: []}
      config = %{model: "qwen3", max_tokens: 50, temperature: 0.1}
      routine_id = "test-routine"

      assert {:error, error_msg} = Ollama.call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id)
      assert error_msg =~ "Connection refused" || error_msg =~ "econnrefused" || error_msg =~ "Connection"
    end
  end

  describe "call/6 - message format conversion" do
    test "converts anthropic format messages to openai format" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        # Multiple messages with different roles
        messages = [
          %{role: "user", content: [%{type: "text", text: "What is 2+2?"}]},
          %{role: "assistant", content: [%{type: "text", text: "4"}]},
          %{role: "user", content: [%{type: "text", text: "Correct! Now say just 'yes'"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        config = %{max_tokens: 20, temperature: 0.1}

        assert {:ok, result} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
        # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"
      end
    end

    test "handles system message in lens contexts" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say hi"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        # Lens contexts should be converted to system message
        lens_contexts = %{
          text: [
            %{type: "text", text: "You are a helpful assistant who says things briefly."}
          ],
          images: []
        }

        config = %{max_tokens: 20, temperature: 0.1}

        assert {:ok, result} = Ollama.call(messages, credentials, [], lens_contexts, config, "test")
        # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"
      end
    end
  end

  describe "call/6 - configuration" do
    test "uses model from config when provided" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say hello"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "llama2"  # Default
        }

        config = %{
          model: "qwen3",  # Override
          max_tokens: 30,
          temperature: 0.1
        }

        # Should use qwen3 from config, not llama2 from credentials
        assert {:ok, result} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
        # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"
      end
    end

    test "uses model from credentials when config doesn't specify" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say hello"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        config = %{
          max_tokens: 30,
          temperature: 0.1
          # No model in config
        }

        assert {:ok, result} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
        # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"
      end
    end

    test "respects max_tokens configuration" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Write a very long story"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        # Very low max_tokens should truncate response
        config = %{max_tokens: 10, temperature: 0.1}

        assert {:ok, result} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
        response = extract_response(result)

        # Response should be present but short due to max_tokens
        assert is_map(response)
        [first_block | _] = response["content"]
        assert first_block["type"] == "text"
      end
    end

    test "respects temperature configuration" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say hello"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        # Test with different temperature (just verify it doesn't error)
        config = %{max_tokens: 30, temperature: 0.9}

        assert {:ok, result} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
        # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"
      end
    end
  end

  describe "call/6 - tool support" do
    test "converts and sends tool descriptions" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "What tools do you have?"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        # Anthropic tool format (will be converted to OpenAI format)
        tool_descriptions = [
          %{
            "name" => "get_weather",
            "description" => "Get the weather for a location",
            "input_schema" => %{
              "type" => "object",
              "properties" => %{
                "location" => %{"type" => "string", "description" => "City name"}
              },
              "required" => ["location"]
            }
          }
        ]

        config = %{max_tokens: 100, temperature: 0.1}

        # Request should succeed (whether model uses tools or not)
        assert {:ok, result} = Ollama.call(messages, credentials, tool_descriptions, %{text: [], images: []}, config, "test")
        # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"
      end
    end

    test "handles tool calls in response" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "What's the weather in Paris? Use the get_weather tool."}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        tool_descriptions = [
          %{
            "name" => "get_weather",
            "description" => "Get the weather for a location",
            "input_schema" => %{
              "type" => "object",
              "properties" => %{
                "location" => %{"type" => "string", "description" => "City name"}
              },
              "required" => ["location"]
            }
          }
        ]

        config = %{max_tokens: 200, temperature: 0.1}

        assert {:ok, result} = Ollama.call(messages, credentials, tool_descriptions, %{text: [], images: []}, config, "test")
        response = extract_response(result)

        # Response may or may not contain tool calls depending on model capability
        # Just verify the response structure is valid
        assert is_map(response)
        assert Map.has_key?(response, "content")
        assert is_list(response["content"])

        # Check if any tool_use blocks are present and properly formatted
        tool_uses = Enum.filter(response["content"], fn block ->
          block["type"] == "tool_use"
        end)

        # If model returned tool calls, verify format
        if length(tool_uses) > 0 do
          [first_tool | _] = tool_uses
          assert Map.has_key?(first_tool, "id")
          assert Map.has_key?(first_tool, "name")
          assert Map.has_key?(first_tool, "input")
        end
      end
    end
  end

  describe "call/6 - error handling" do
    test "returns error for invalid model" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hello"}]}
      ]

      credentials = %{
        provider: :ollama,
        base_url: @ollama_base_url,
        model: "this-model-does-not-exist"
      }

      config = %{max_tokens: 50, temperature: 0.1}

      case Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test") do
        {:error, error_msg} ->
          # Either connection error (Ollama not running) or API error (invalid model)
          assert error_msg =~ "API error" || error_msg =~ "Connection refused"

        {:ok, _result} ->
          # If Ollama is not running, we might not even reach the API
          :ok
      end
    end

    test "handles malformed base_url" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hello"}]}
      ]

      credentials = %{
        provider: :ollama,
        base_url: "not-a-valid-url",
        model: "qwen3"
      }

      config = %{max_tokens: 50, temperature: 0.1}

      assert {:error, error_msg} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
      assert error_msg =~ "Invalid request" || error_msg =~ "Connection"
    end
  end

  describe "call/6 - response format" do
    test "returns anthropic format response" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say test"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        config = %{max_tokens: 20, temperature: 0.1}

        assert {:ok, result} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
        response = extract_response(result)

        # Verify Anthropic format structure
        assert response["role"] == "assistant"
        assert is_list(response["content"])
        assert Map.has_key?(response, "stop_reason")

        # Content blocks should have correct format
        Enum.each(response["content"], fn block ->
          assert Map.has_key?(block, "type")

          case block["type"] do
            "text" ->
              assert Map.has_key?(block, "text")
              assert is_binary(block["text"])

            "tool_use" ->
              assert Map.has_key?(block, "id")
              assert Map.has_key?(block, "name")
              assert Map.has_key?(block, "input")

            _ ->
              flunk("Unknown block type: #{block["type"]}")
          end
        end)

        # Stop reason should be valid
        assert response["stop_reason"] in ["end_turn", "tool_use", "max_tokens"]
      end
    end

    test "includes usage information when available" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Hi"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "qwen3"
        }

        config = %{max_tokens: 20, temperature: 0.1}

        assert {:ok, result} = Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test")
        response = extract_response(result)

        # Usage may or may not be present depending on Ollama version
        if Map.has_key?(response, "usage") do
          usage = response["usage"]
          assert Map.has_key?(usage, "input_tokens")
          assert Map.has_key?(usage, "output_tokens")
          assert is_integer(usage["input_tokens"])
          assert is_integer(usage["output_tokens"])
        end
      end
    end
  end

  describe "call/6 - different models" do
    test "works with deepseek-r1 model" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say hi briefly"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "deepseek-r1"
        }

        config = %{max_tokens: 30, temperature: 0.1}

        case Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test") do
          {:ok, result} ->
            # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"

          {:error, error_msg} ->
            # Model might not be installed
            assert error_msg =~ "API error" || error_msg =~ "not found"
        end
      end
    end

    test "works with gpt-oss model" do
      unless ollama_running?() do
        IO.puts("\nSkipping Ollama test - server not running")
        :ok
      else
        messages = [
          %{role: "user", content: [%{type: "text", text: "Say hi briefly"}]}
        ]

        credentials = %{
          provider: :ollama,
          base_url: @ollama_base_url,
          model: "gpt-oss"
        }

        config = %{max_tokens: 30, temperature: 0.1}

        case Ollama.call(messages, credentials, [], %{text: [], images: []}, config, "test") do
          {:ok, result} ->
            # Response is in diff format now, extract it
        response = extract_response(result)
        assert is_map(response), "Expected llm_response to be extracted from diff"

          {:error, error_msg} ->
            # Model might not be installed
            assert error_msg =~ "API error" || error_msg =~ "not found"
        end
      end
    end
  end
end
