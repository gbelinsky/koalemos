defmodule Koalemos.OpenAIFormatConverterTest do
  use ExUnit.Case, async: true
  alias Koalemos.OpenAIFormatConverter

  describe "convert_messages_to_openai/1" do
    test "converts simple text message" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hello"}]}
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      assert length(result) == 1
      assert [%{"role" => "user", "content" => "Hello"}] = result
    end

    test "converts multiple messages" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "What is 2+2?"}]},
        %{role: "assistant", content: [%{type: "text", text: "4"}]},
        %{role: "user", content: [%{type: "text", text: "Correct!"}]}
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      assert length(result) == 3
      assert Enum.at(result, 0) == %{"role" => "user", "content" => "What is 2+2?"}
      assert Enum.at(result, 1) == %{"role" => "assistant", "content" => "4"}
      assert Enum.at(result, 2) == %{"role" => "user", "content" => "Correct!"}
    end

    test "converts message with multiple text blocks" do
      messages = [
        %{
          role: "user",
          content: [
            %{type: "text", text: "First part"},
            %{type: "text", text: "Second part"}
          ]
        }
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      assert length(result) == 1
      assert [%{"role" => "user", "content" => "First part\nSecond part"}] = result
    end

    test "converts assistant message with tool use" do
      messages = [
        %{
          role: "assistant",
          content: [
            %{type: "text", text: "Let me check the weather"},
            %{
              type: "tool_use",
              id: "tool_123",
              name: "get_weather",
              input: %{location: "Paris"}
            }
          ]
        }
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      assert length(result) == 1
      [message] = result

      assert message["role"] == "assistant"
      assert message["content"] == "Let me check the weather"
      assert length(message["tool_calls"]) == 1

      [tool_call] = message["tool_calls"]
      assert tool_call["id"] == "tool_123"
      assert tool_call["type"] == "function"
      assert tool_call["function"]["name"] == "get_weather"
      assert Jason.decode!(tool_call["function"]["arguments"]) == %{"location" => "Paris"}
    end

    test "converts user message with tool result" do
      messages = [
        %{
          role: "user",
          content: [
            %{
              type: "tool_result",
              tool_use_id: "tool_123",
              content: "Weather is sunny, 22°C"
            }
          ]
        }
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      assert length(result) == 1
      [tool_message] = result

      assert tool_message["role"] == "tool"
      assert tool_message["tool_call_id"] == "tool_123"
      assert tool_message["content"] == "Weather is sunny, 22°C"
    end

    test "converts message with mixed content (text and tool result)" do
      messages = [
        %{
          role: "user",
          content: [
            %{type: "text", text: "Here's the result:"},
            %{
              type: "tool_result",
              tool_use_id: "tool_123",
              content: "42"
            }
          ]
        }
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      assert length(result) == 2
      # Text message first
      assert Enum.at(result, 0) == %{"role" => "user", "content" => "Here's the result:"}
      # Tool result message second
      assert Enum.at(result, 1) == %{
               "role" => "tool",
               "tool_call_id" => "tool_123",
               "content" => "42"
             }
    end

    test "skips empty messages" do
      messages = [
        %{role: "user", content: []},
        %{role: "assistant", content: [%{type: "text", text: "Hello"}]},
        %{role: "user", content: nil}
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      # Only the assistant message should remain
      assert length(result) == 1
      assert [%{"role" => "assistant", "content" => "Hello"}] = result
    end

    test "handles string content directly" do
      messages = [
        %{role: "user", content: "Plain string message"}
      ]

      result = OpenAIFormatConverter.convert_messages_to_openai(messages)

      assert length(result) == 1
      assert [%{"role" => "user", "content" => "Plain string message"}] = result
    end
  end

  describe "build_system_message/1" do
    test "builds system message with base text only" do
      lens_contexts = []

      result = OpenAIFormatConverter.build_system_message(lens_contexts)

      assert result["role"] == "system"
      # Base text is empty for OpenAI/Ollama (only Anthropic needs Claude Code identity)
      assert result["content"] == ""
    end

    test "builds system message with lens contexts" do
      lens_contexts = [
        %{type: "text", text: "Additional context 1"},
        %{type: "text", text: "Additional context 2"}
      ]

      result = OpenAIFormatConverter.build_system_message(lens_contexts)

      assert result["role"] == "system"
      assert result["content"] =~ "Additional context 1"
      assert result["content"] =~ "Additional context 2"
    end

    test "handles empty lens contexts gracefully" do
      lens_contexts = [
        %{type: "text", text: ""},
        %{type: "other", data: "ignored"}
      ]

      result = OpenAIFormatConverter.build_system_message(lens_contexts)

      assert result["role"] == "system"
      # Empty contexts are filtered out, should return empty string
      assert result["content"] == ""
    end
  end

  describe "convert_response_to_anthropic/1" do
    test "converts simple text response" do
      openai_response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "Hello there!"
            },
            "finish_reason" => "stop"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 10,
          "completion_tokens" => 5
        }
      }

      assert {:ok, result} = OpenAIFormatConverter.convert_response_to_anthropic(openai_response)

      assert result["role"] == "assistant"
      assert result["stop_reason"] == "end_turn"
      assert length(result["content"]) == 1

      [text_block] = result["content"]
      assert text_block["type"] == "text"
      assert text_block["text"] == "Hello there!"

      # Check usage mapping
      assert result["usage"]["input_tokens"] == 10
      assert result["usage"]["output_tokens"] == 5
    end

    test "converts response with tool calls" do
      openai_response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "Let me check",
              "tool_calls" => [
                %{
                  "id" => "tool_456",
                  "type" => "function",
                  "function" => %{
                    "name" => "get_weather",
                    "arguments" => "{\"location\":\"Tokyo\"}"
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ]
      }

      assert {:ok, result} = OpenAIFormatConverter.convert_response_to_anthropic(openai_response)

      assert result["role"] == "assistant"
      assert result["stop_reason"] == "tool_use"
      assert length(result["content"]) == 2

      # Text block first
      [text_block, tool_block] = result["content"]
      assert text_block["type"] == "text"
      assert text_block["text"] == "Let me check"

      # Tool use block second
      assert tool_block["type"] == "tool_use"
      assert tool_block["id"] == "tool_456"
      assert tool_block["name"] == "get_weather"
      assert tool_block["input"] == %{"location" => "Tokyo"}
    end

    test "converts response with reasoning field (qwen3 style)" do
      openai_response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "",
              "reasoning" => "Let me think about this step by step..."
            },
            "finish_reason" => "stop"
          }
        ]
      }

      assert {:ok, result} = OpenAIFormatConverter.convert_response_to_anthropic(openai_response)

      assert result["role"] == "assistant"
      assert length(result["content"]) == 1

      [text_block] = result["content"]
      assert text_block["type"] == "text"
      assert text_block["text"] == "Let me think about this step by step..."
    end

    test "converts response with length finish reason" do
      openai_response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "This is a long response that got cut off"
            },
            "finish_reason" => "length"
          }
        ]
      }

      assert {:ok, result} = OpenAIFormatConverter.convert_response_to_anthropic(openai_response)

      assert result["stop_reason"] == "max_tokens"
    end

    test "handles empty content gracefully" do
      openai_response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => ""
            },
            "finish_reason" => "stop"
          }
        ]
      }

      assert {:ok, result} = OpenAIFormatConverter.convert_response_to_anthropic(openai_response)

      # Empty content should result in empty content array
      assert result["content"] == []
    end

    test "handles response without usage" do
      openai_response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "Hello"
            },
            "finish_reason" => "stop"
          }
        ]
      }

      assert {:ok, result} = OpenAIFormatConverter.convert_response_to_anthropic(openai_response)

      # Usage field should not be present
      refute Map.has_key?(result, "usage")
    end

    test "returns error when no choices in response" do
      openai_response = %{
        "choices" => []
      }

      assert {:error, "No choices in response"} =
               OpenAIFormatConverter.convert_response_to_anthropic(openai_response)
    end

    test "handles malformed tool call arguments" do
      openai_response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                %{
                  "id" => "tool_789",
                  "type" => "function",
                  "function" => %{
                    "name" => "test_tool",
                    "arguments" => "not valid json"
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ]
      }

      assert {:ok, result} = OpenAIFormatConverter.convert_response_to_anthropic(openai_response)

      # Should handle gracefully with empty input
      [tool_block] = Enum.filter(result["content"], fn b -> b["type"] == "tool_use" end)
      assert tool_block["input"] == %{}
    end
  end

  describe "convert_content_array_message/2" do
    test "converts tool result with list content" do
      content_array = [
        %{
          "type" => "tool_result",
          "tool_use_id" => "tool_999",
          "content" => [
            %{"type" => "text", "text" => "Line 1"},
            %{"type" => "text", "text" => "Line 2"}
          ]
        }
      ]

      result = OpenAIFormatConverter.convert_content_array_message("user", content_array)

      assert length(result) == 1
      [tool_message] = result

      assert tool_message["role"] == "tool"
      assert tool_message["tool_call_id"] == "tool_999"
      # List content should be joined
      assert tool_message["content"] == "Line 1\nLine 2"
    end
  end
end
