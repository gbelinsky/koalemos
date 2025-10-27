defmodule Koalemos.Steps.User.ChatUserInputTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.User.ChatUserInput

  describe "handle_event/3 - plain string input" do
    test "formats plain string as user message" do
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, "Hello world", state)
      assert [append_to: %{messages: [message]}] = diff

      assert message.role == "user"
      assert message.content == [%{type: "text", text: "Hello world"}]
      assert message.metadata.source == :user
      assert message.metadata.routine_id == "routine-123"
      assert is_binary(message.metadata.id)
      assert is_binary(message.metadata.timestamp)
    end

    test "handles empty string" do
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, "", state)
      assert [append_to: %{messages: [message]}] = diff
      assert message.content == [%{type: "text", text: ""}]
    end

    test "handles multi-line string" do
      input = "Line 1\nLine 2\nLine 3"
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff
      assert message.content == [%{type: "text", text: input}]
    end
  end

  describe "handle_event/3 - structured input" do
    test "formats %{user_input: text} as user message" do
      state = %{routine_id: "routine-456", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, %{user_input: "Structured input"}, state)
      assert [append_to: %{messages: [message]}] = diff

      assert message.role == "user"
      assert message.content == [%{type: "text", text: "Structured input"}]
      assert message.metadata.routine_id == "routine-456"
    end
  end

  describe "handle_event/3 - image input" do
    test "formats text with images" do
      input = %{
        text: "Describe this image",
        images: [
          %{base64: "base64data1", media_type: "image/jpeg"},
          %{base64: "base64data2", media_type: "image/png"}
        ]
      }
      state = %{routine_id: "routine-789", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff

      assert message.role == "user"
      assert length(message.content) == 3

      assert Enum.at(message.content, 0) == %{type: "text", text: "Describe this image"}

      assert Enum.at(message.content, 1).type == "image"
      assert Enum.at(message.content, 1).source.type == "base64"
      assert Enum.at(message.content, 1).source.media_type == "image/jpeg"
      assert Enum.at(message.content, 1).source.data == "base64data1"

      assert Enum.at(message.content, 2).type == "image"
      assert Enum.at(message.content, 2).source.media_type == "image/png"
      assert Enum.at(message.content, 2).source.data == "base64data2"
    end

    test "formats images only (no text)" do
      input = %{
        images: [
          %{base64: "imagedata", media_type: "image/webp"}
        ]
      }
      state = %{routine_id: "routine-999", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff

      assert message.role == "user"
      assert length(message.content) == 1
      assert Enum.at(message.content, 0).type == "image"
      assert Enum.at(message.content, 0).source.data == "imagedata"
    end

    test "handles empty images list gracefully" do
      # Empty images list doesn't match the guard, falls through to unsupported
      input = %{images: []}
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [add: %{error: error}] = diff
      assert error =~ "Unsupported user input format"
    end
  end

  describe "handle_event/3 - pre-formatted messages" do
    test "extracts and rebuilds user message from messages array" do
      input = %{
        messages: [
          %{
            role: "user",
            content: [%{type: "text", text: "Pre-formatted message"}]
          }
        ]
      }
      state = %{routine_id: "routine-abc", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff

      assert message.role == "user"
      assert message.content == [%{type: "text", text: "Pre-formatted message"}]
      assert message.metadata.routine_id == "routine-abc"
    end

    test "handles string keys in pre-formatted messages" do
      input = %{
        messages: [
          %{
            "role" => "user",
            "content" => [%{"type" => "text", "text" => "String keys"}]
          }
        ]
      }
      state = %{routine_id: "routine-def", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff

      assert message.role == "user"
      # Content is normalized to atom keys
      assert message.content == [%{type: "text", text: "String keys"}]
    end

    test "extracts first user message when multiple messages present" do
      input = %{
        messages: [
          %{role: "assistant", content: [%{type: "text", text: "AI response"}]},
          %{role: "user", content: [%{type: "text", text: "User message"}]},
          %{role: "user", content: [%{type: "text", text: "Another user message"}]}
        ]
      }
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff

      # Should get the first user message
      assert message.content == [%{type: "text", text: "User message"}]
    end

    test "returns error when no user message found in messages" do
      input = %{
        messages: [
          %{role: "assistant", content: [%{type: "text", text: "Only assistant"}]}
        ]
      }
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [add: %{error: error}] = diff
      assert error == "No user message found in pre-formatted input"
    end

    test "returns error when messages array is empty" do
      input = %{messages: []}
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [add: %{error: error}] = diff
      assert error == "No user message found in pre-formatted input"
    end

    test "handles non-list content in pre-formatted message" do
      input = %{
        messages: [
          %{role: "user", content: "not a list"}
        ]
      }
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff
      # Fallback: inspect the content as text
      assert message.content == [%{type: "text", text: "\"not a list\""}]
    end

    test "handles nested string keys in image content" do
      input = %{
        messages: [
          %{
            "role" => "user",
            "content" => [
              %{"type" => "text", "text" => "Image test"},
              %{
                "type" => "image",
                "source" => %{
                  "type" => "base64",
                  "media_type" => "image/jpeg",
                  "data" => "base64data"
                }
              }
            ]
          }
        ]
      }
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, input, state)
      assert [append_to: %{messages: [message]}] = diff

      assert message.role == "user"
      assert length(message.content) == 2
      assert Enum.at(message.content, 0) == %{type: "text", text: "Image test"}

      # Verify nested map normalization
      image_block = Enum.at(message.content, 1)
      assert image_block.type == "image"
      assert image_block.source.type == "base64"
      assert image_block.source.media_type == "image/jpeg"
      assert image_block.source.data == "base64data"
    end
  end

  describe "handle_event/3 - error handling" do
    test "returns error for unsupported format" do
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, %{unknown: "format"}, state)
      assert [add: %{error: error}] = diff
      assert error =~ "Unsupported user input format"
    end

    test "returns error for nil input" do
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, nil, state)
      assert [add: %{error: error}] = diff
      assert error =~ "Unsupported user input format"
    end

    test "returns error for number input" do
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, 123, state)
      assert [add: %{error: error}] = diff
      assert error =~ "Unsupported user input format"
    end

    test "returns error for list input" do
      state = %{routine_id: "routine-123", context: %{}}

      assert {:ok, diff} = ChatUserInput.handle_event(:user_input, ["not", "valid"], state)
      assert [add: %{error: error}] = diff
      assert error =~ "Unsupported user input format"
    end
  end

  describe "handle_event/3 - metadata generation" do
    test "generates unique message IDs" do
      state = %{routine_id: "routine-123", context: %{}}

      {:ok, diff1} = ChatUserInput.handle_event(:user_input, "Message 1", state)
      {:ok, diff2} = ChatUserInput.handle_event(:user_input, "Message 2", state)

      [append_to: %{messages: [msg1]}] = diff1
      [append_to: %{messages: [msg2]}] = diff2

      assert msg1.metadata.id != msg2.metadata.id
    end

    test "sets source to :user" do
      state = %{routine_id: "routine-123", context: %{}}

      {:ok, diff} = ChatUserInput.handle_event(:user_input, "Test", state)
      [append_to: %{messages: [message]}] = diff

      assert message.metadata.source == :user
    end

    test "includes routine_id in metadata" do
      state = %{routine_id: "custom-routine-id", context: %{}}

      {:ok, diff} = ChatUserInput.handle_event(:user_input, "Test", state)
      [append_to: %{messages: [message]}] = diff

      assert message.metadata.routine_id == "custom-routine-id"
    end

    test "generates ISO 8601 timestamp" do
      state = %{routine_id: "routine-123", context: %{}}

      {:ok, diff} = ChatUserInput.handle_event(:user_input, "Test", state)
      [append_to: %{messages: [message]}] = diff

      # Verify timestamp is valid ISO 8601 format
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(message.metadata.timestamp)
    end
  end

  describe "handle_event/3 - message appending" do
    test "uses append_to for messages array" do
      state = %{routine_id: "routine-123", context: %{}}

      {:ok, diff} = ChatUserInput.handle_event(:user_input, "Test", state)

      # Should use append_to, not add or add_or_update
      assert [append_to: %{messages: _}] = diff
    end

    test "appends single message" do
      state = %{routine_id: "routine-123", context: %{}}

      {:ok, diff} = ChatUserInput.handle_event(:user_input, "Test", state)
      assert [append_to: %{messages: messages}] = diff
      assert length(messages) == 1
    end
  end
end
