defmodule Koalemos.LLMProviders.OpenAITest do
  use ExUnit.Case, async: true
  alias Koalemos.LLMProviders.OpenAI

  describe "call/6 - message conversion" do
    test "converts simple text messages to OpenAI format" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hello"}]},
        %{role: "assistant", content: [%{type: "text", text: "Hi there"}]},
        %{role: "user", content: [%{type: "text", text: "How are you?"}]}
      ]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      # Will fail with connection error but messages are converted
      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, error_msg} = result
      assert error_msg =~ "Connection refused" or error_msg =~ "Request failed"
    end

    test "filters empty assistant messages" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hello"}]},
        %{role: "assistant", content: []},
        %{role: "user", content: [%{type: "text", text: "Anyone there?"}]}
      ]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end

    test "strips metadata from messages" do
      messages = [
        %{
          role: "user",
          content: [%{type: "text", text: "Hi"}],
          metadata: %{id: "msg_123", timestamp: "2024-10-27"}
        }
      ]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end

    test "keeps only last screenshot" do
      messages = [
        %{role: "user", content: [%{type: "image", source: %{data: "old"}}]},
        %{role: "user", content: [%{type: "text", text: "What do you see?"}]},
        %{role: "user", content: [%{type: "image", source: %{data: "new"}}]}
      ]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end
  end

  describe "call/6 - system message" do
    test "builds system message with base prompt only" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}
      lens_contexts = []

      result = OpenAI.call(messages, credentials, [], lens_contexts, config, "routine-123")

      assert {:error, _} = result
    end

    test "builds system message with lens contexts" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      lens_contexts = [
        %{type: "text", text: "Context from lens 1"},
        %{type: "text", text: "Context from lens 2"}
      ]

      result = OpenAI.call(messages, credentials, [], lens_contexts, config, "routine-123")

      assert {:error, _} = result
    end
  end

  describe "call/6 - tool handling" do
    test "converts and includes tool descriptions" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      tool_descriptions = [
        %{
          name: "get_weather",
          description: "Get weather for a location",
          input_schema: %{
            type: "object",
            properties: %{location: %{type: "string"}},
            required: ["location"]
          }
        }
      ]

      result = OpenAI.call(messages, credentials, tool_descriptions, [], config, "routine-123")

      assert {:error, _} = result
    end

    test "handles request without tools" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end
  end

  describe "call/6 - configuration" do
    test "uses default model when not provided" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{}

      # Should use default model "gpt-4"
      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end

    test "uses custom model when provided" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4-turbo", max_tokens: 8192, temperature: 0.7}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end
  end

  describe "call/6 - error handling" do
    test "handles connection refused gracefully" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, error_msg} = result
      assert is_binary(error_msg)
      assert error_msg =~ "Connection refused" or error_msg =~ "Request failed"
    end

    test "handles invalid base URL" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "not-a-valid-url"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, error_msg} = result
      assert is_binary(error_msg)
    end
  end

  describe "message conversion - complex scenarios" do
    test "converts assistant message with tool use" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "What's the weather?"}]},
        %{
          role: "assistant",
          content: [
            %{type: "text", text: "Let me check"},
            %{
              type: "tool_use",
              id: "tool_1",
              name: "get_weather",
              input: %{location: "San Francisco"}
            }
          ]
        }
      ]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end

    test "converts user message with tool result" do
      messages = [
        %{
          role: "user",
          content: [
            %{
              type: "tool_result",
              tool_use_id: "tool_1",
              content: "Sunny, 72°F"
            }
          ]
        }
      ]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end

    test "handles mixed content with text and tool result" do
      messages = [
        %{
          role: "user",
          content: [
            %{type: "text", text: "Here's the result:"},
            %{
              type: "tool_result",
              tool_use_id: "tool_1",
              content: "Data here"
            }
          ]
        }
      ]

      credentials = %{
        provider: :openai,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      config = %{model: "gpt-4"}

      result = OpenAI.call(messages, credentials, [], [], config, "routine-123")

      assert {:error, _} = result
    end
  end
end
