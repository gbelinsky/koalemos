defmodule Koalemos.Steps.Agent.ResponseParsingTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.Agent.ResponseParsing

  describe "execute/2 - text-only responses" do
    test "parses text-only response and appends assistant message" do
      state = %{
        routine_id: "routine-123",
        context: %{
          llm_response: %{
            "content" => [
              %{"type" => "text", "text" => "Hello! How can I help you?"}
            ],
            "usage" => %{"input_tokens" => 10, "output_tokens" => 8}
          },
          messages: [
            %{role: "user", content: [%{type: "text", text: "Hi"}]}
          ]
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      # Should append assistant message
      assert Keyword.has_key?(diff, :append_to)
      [assistant_message] = diff[:append_to][:messages]

      assert assistant_message.role == "assistant"
      assert assistant_message.content == [%{"type" => "text", "text" => "Hello! How can I help you?"}]
      assert assistant_message.metadata.source == :agent
      assert assistant_message.metadata.routine_id == "routine-123"
      assert assistant_message.metadata.usage == %{"input_tokens" => 10, "output_tokens" => 8}

      # Should not have tool_calls
      refute Keyword.has_key?(diff, :add_or_update)
    end

    test "parses response with multiple text blocks" do
      state = %{
        routine_id: "routine-456",
        context: %{
          llm_response: %{
            "content" => [
              %{"type" => "text", "text" => "First part."},
              %{"type" => "text", "text" => "Second part."}
            ]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      [assistant_message] = diff[:append_to][:messages]
      assert length(assistant_message.content) == 2
    end

    test "parses response with no usage data" do
      state = %{
        routine_id: "routine-789",
        context: %{
          llm_response: %{
            "content" => [
              %{"type" => "text", "text" => "Response without usage"}
            ]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      [assistant_message] = diff[:append_to][:messages]
      assert assistant_message.metadata.usage == %{}
    end
  end

  describe "execute/2 - tool call responses" do
    test "extracts single tool call" do
      state = %{
        routine_id: "routine-123",
        context: %{
          llm_response: %{
            "content" => [
              %{"type" => "text", "text" => "Let me check that for you."},
              %{
                "type" => "tool_use",
                "id" => "tool_123",
                "name" => "get_weather",
                "input" => %{"location" => "San Francisco"}
              }
            ]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      # Should have both message and tool_calls
      assert Keyword.has_key?(diff, :append_to)
      assert Keyword.has_key?(diff, :add_or_update)

      # Check tool_calls
      tool_calls = diff[:add_or_update][:tool_calls]
      assert length(tool_calls) == 1

      [tool_call] = tool_calls
      assert tool_call.id == "tool_123"
      assert tool_call.name == "get_weather"
      assert tool_call.input == %{"location" => "San Francisco"}
    end

    test "extracts multiple tool calls" do
      state = %{
        routine_id: "routine-456",
        context: %{
          llm_response: %{
            "content" => [
              %{
                "type" => "tool_use",
                "id" => "tool_1",
                "name" => "search",
                "input" => %{"query" => "elixir"}
              },
              %{
                "type" => "tool_use",
                "id" => "tool_2",
                "name" => "calculate",
                "input" => %{"expression" => "2+2"}
              }
            ]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      tool_calls = diff[:add_or_update][:tool_calls]
      assert length(tool_calls) == 2

      assert Enum.at(tool_calls, 0).id == "tool_1"
      assert Enum.at(tool_calls, 1).id == "tool_2"
    end

    test "handles tool call with empty input" do
      state = %{
        routine_id: "routine-789",
        context: %{
          llm_response: %{
            "content" => [
              %{
                "type" => "tool_use",
                "id" => "tool_empty",
                "name" => "no_args_tool"
                # No "input" key
              }
            ]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      tool_calls = diff[:add_or_update][:tool_calls]
      [tool_call] = tool_calls
      assert tool_call.input == %{}
    end

    test "mixed content with text and tools" do
      state = %{
        routine_id: "routine-mixed",
        context: %{
          llm_response: %{
            "content" => [
              %{"type" => "text", "text" => "Let me help with that."},
              %{
                "type" => "tool_use",
                "id" => "tool_abc",
                "name" => "help_tool",
                "input" => %{"task" => "assist"}
              },
              %{"type" => "text", "text" => "One moment..."}
            ]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      # Message should contain all content
      [assistant_message] = diff[:append_to][:messages]
      assert length(assistant_message.content) == 3

      # Tool calls should only extract tool_use blocks
      tool_calls = diff[:add_or_update][:tool_calls]
      assert length(tool_calls) == 1
      assert Enum.at(tool_calls, 0).name == "help_tool"
    end
  end

  describe "execute/2 - edge cases" do
    test "handles empty content array" do
      state = %{
        routine_id: "routine-empty",
        context: %{
          llm_response: %{
            "content" => []
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      [assistant_message] = diff[:append_to][:messages]
      assert assistant_message.content == []

      # No tool calls
      refute Keyword.has_key?(diff, :add_or_update)
    end

    test "handles response with only tool calls (no text)" do
      state = %{
        routine_id: "routine-tools-only",
        context: %{
          llm_response: %{
            "content" => [
              %{
                "type" => "tool_use",
                "id" => "tool_only",
                "name" => "direct_tool",
                "input" => %{}
              }
            ]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      # Message should contain tool_use block
      [assistant_message] = diff[:append_to][:messages]
      assert length(assistant_message.content) == 1

      # Tool calls extracted
      tool_calls = diff[:add_or_update][:tool_calls]
      assert length(tool_calls) == 1
    end
  end

  describe "execute/2 - error handling" do
    test "returns error when content is not a list" do
      state = %{
        routine_id: "routine-error",
        context: %{
          llm_response: %{
            "content" => "string instead of list"
          }
        }
      }

      assert {:error, error_msg} = ResponseParsing.execute(%{}, state)
      assert error_msg =~ "Expected content to be a list"
    end

    test "returns error when content is missing" do
      state = %{
        routine_id: "routine-missing",
        context: %{
          llm_response: %{
            "usage" => %{}
          }
        }
      }

      assert {:error, error_msg} = ResponseParsing.execute(%{}, state)
      assert error_msg =~ "No content found in LLM response"
    end

    test "returns error when llm_response is nil" do
      state = %{
        routine_id: "routine-nil",
        context: %{}
      }

      assert {:error, error_msg} = ResponseParsing.execute(%{}, state)
      assert error_msg =~ "No content found in LLM response"
    end

    test "returns error when llm_response is malformed" do
      state = %{
        routine_id: "routine-malformed",
        context: %{
          llm_response: "not a map"
        }
      }

      assert {:error, error_msg} = ResponseParsing.execute(%{}, state)
      assert error_msg =~ "No content found in LLM response"
    end
  end

  describe "execute/2 - metadata" do
    test "includes routine_id in assistant message metadata" do
      state = %{
        routine_id: "custom-routine-999",
        context: %{
          llm_response: %{
            "content" => [%{"type" => "text", "text" => "Test"}]
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      [assistant_message] = diff[:append_to][:messages]
      assert assistant_message.metadata.routine_id == "custom-routine-999"
      assert assistant_message.metadata.source == :agent
    end

    test "passes through usage metadata" do
      usage_data = %{
        "input_tokens" => 100,
        "output_tokens" => 50,
        "cache_read_input_tokens" => 20
      }

      state = %{
        routine_id: "routine-usage",
        context: %{
          llm_response: %{
            "content" => [%{"type" => "text", "text" => "Response"}],
            "usage" => usage_data
          }
        }
      }

      assert {:ok, diff} = ResponseParsing.execute(%{}, state)

      [assistant_message] = diff[:append_to][:messages]
      assert assistant_message.metadata.usage == usage_data
    end
  end
end
