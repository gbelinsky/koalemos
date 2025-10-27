defmodule Koalemos.Utils.MessageBuilderTest do
  use ExUnit.Case, async: true
  alias Koalemos.Utils.MessageBuilder

  describe "build_user_message/2" do
    test "creates basic user message with text" do
      message = MessageBuilder.build_user_message("Hello world")

      assert message.role == "user"
      assert message.content == [%{type: "text", text: "Hello world"}]
      assert is_map(message.metadata)
      assert is_binary(message.metadata.id)
      assert is_binary(message.metadata.timestamp)
    end

    test "accepts custom id option" do
      message = MessageBuilder.build_user_message("Test", id: "custom-123")

      assert message.metadata.id == "custom-123"
    end

    test "accepts custom timestamp option" do
      timestamp = "2024-10-27T12:00:00Z"
      message = MessageBuilder.build_user_message("Test", timestamp: timestamp)

      assert message.metadata.timestamp == timestamp
    end

    test "accepts source option" do
      message = MessageBuilder.build_user_message("Test", source: :user)

      assert message.metadata.source == :user
    end

    test "accepts routine_id option" do
      message = MessageBuilder.build_user_message("Test", routine_id: "routine-123")

      assert message.metadata.routine_id == "routine-123"
    end

    test "combines multiple options" do
      message = MessageBuilder.build_user_message("Test",
        id: "msg-1",
        timestamp: "2024-10-27T12:00:00Z",
        source: :system,
        routine_id: "routine-456"
      )

      assert message.metadata.id == "msg-1"
      assert message.metadata.timestamp == "2024-10-27T12:00:00Z"
      assert message.metadata.source == :system
      assert message.metadata.routine_id == "routine-456"
    end

    test "defaults source to :unknown when not provided" do
      message = MessageBuilder.build_user_message("Test")

      assert message.metadata.source == :unknown
    end
  end

  describe "build_user_message_with_content/2" do
    test "creates message with text content part" do
      message = MessageBuilder.build_user_message_with_content([{:text, "Hello"}])

      assert message.role == "user"
      assert message.content == [%{type: "text", text: "Hello"}]
    end

    test "creates message with image content part" do
      base64_data = "iVBORw0KGgoAAAANSUhEUg"
      message = MessageBuilder.build_user_message_with_content([{:image, base64_data, "image/jpeg"}])

      assert message.role == "user"
      assert [image_content] = message.content
      assert image_content.type == "image"
      assert image_content.source.type == "base64"
      assert image_content.source.media_type == "image/jpeg"
      assert image_content.source.data == base64_data
    end

    test "creates message with image_url content part" do
      url = "https://example.com/image.jpg"
      message = MessageBuilder.build_user_message_with_content([{:image_url, url}])

      assert message.role == "user"
      assert [image_content] = message.content
      assert image_content.type == "image"
      assert image_content.source.type == "url"
      assert image_content.source.url == url
    end

    test "creates message with mixed content parts" do
      message = MessageBuilder.build_user_message_with_content([
        {:text, "Look at this:"},
        {:image, "base64data", "image/png"},
        {:text, "What do you see?"}
      ])

      assert message.role == "user"
      assert length(message.content) == 3
      assert Enum.at(message.content, 0).type == "text"
      assert Enum.at(message.content, 1).type == "image"
      assert Enum.at(message.content, 2).type == "text"
    end

    test "raises ArgumentError for invalid content part" do
      assert_raise ArgumentError, fn ->
        MessageBuilder.build_user_message_with_content([{:invalid, "data"}])
      end
    end

    test "accepts options like build_user_message" do
      message = MessageBuilder.build_user_message_with_content(
        [{:text, "Test"}],
        id: "msg-1",
        routine_id: "routine-123"
      )

      assert message.metadata.id == "msg-1"
      assert message.metadata.routine_id == "routine-123"
    end
  end

  describe "build_assistant_message/2" do
    test "creates basic assistant message" do
      content = [%{type: "text", text: "I can help with that"}]
      message = MessageBuilder.build_assistant_message(content)

      assert message.role == "assistant"
      assert message.content == content
      assert is_map(message.metadata)
    end

    test "accepts options" do
      content = [%{type: "text", text: "Response"}]
      message = MessageBuilder.build_assistant_message(content,
        id: "msg-1",
        routine_id: "routine-123"
      )

      assert message.metadata.id == "msg-1"
      assert message.metadata.routine_id == "routine-123"
    end
  end

  describe "build_tool_result_message/3" do
    test "creates basic tool result message" do
      message = MessageBuilder.build_tool_result_message("tool-123", "Success!")

      assert message.role == "user"
      assert [content_block] = message.content
      assert content_block.type == "tool_result"
      assert content_block.tool_use_id == "tool-123"
      assert content_block.content == "Success!"
      refute Map.has_key?(content_block, :is_error)
    end

    test "creates tool result message with is_error flag" do
      message = MessageBuilder.build_tool_result_message("tool-456", "Failed!", is_error: true)

      assert [content_block] = message.content
      assert content_block.is_error == true
    end

    test "accepts options" do
      message = MessageBuilder.build_tool_result_message("tool-789", "Done",
        routine_id: "routine-123"
      )

      assert message.metadata.routine_id == "routine-123"
    end
  end

  describe "validate_message/1" do
    test "validates user message with text content" do
      message = %{
        role: "user",
        content: [%{type: "text", text: "Hello"}]
      }

      assert MessageBuilder.validate_message(message) == :ok
    end

    test "validates assistant message with text content" do
      message = %{
        role: "assistant",
        content: [%{type: "text", text: "Response"}]
      }

      assert MessageBuilder.validate_message(message) == :ok
    end

    test "validates message with image content (base64)" do
      message = %{
        role: "user",
        content: [
          %{
            type: "image",
            source: %{
              type: "base64",
              media_type: "image/jpeg",
              data: "base64data"
            }
          }
        ]
      }

      assert MessageBuilder.validate_message(message) == :ok
    end

    test "validates message with image content (url)" do
      message = %{
        role: "user",
        content: [
          %{
            type: "image",
            source: %{
              type: "url",
              url: "https://example.com/image.jpg"
            }
          }
        ]
      }

      assert MessageBuilder.validate_message(message) == :ok
    end

    test "validates message with tool result content" do
      message = %{
        role: "user",
        content: [
          %{
            type: "tool_result",
            tool_use_id: "tool-123",
            content: "Success"
          }
        ]
      }

      assert MessageBuilder.validate_message(message) == :ok
    end

    test "validates message with tool use content" do
      message = %{
        role: "assistant",
        content: [%{type: "tool_use"}]
      }

      assert MessageBuilder.validate_message(message) == :ok
    end

    test "validates supported image media types" do
      for media_type <- ["image/jpeg", "image/png", "image/gif", "image/webp"] do
        message = %{
          role: "user",
          content: [
            %{
              type: "image",
              source: %{type: "base64", media_type: media_type, data: "data"}
            }
          ]
        }

        assert MessageBuilder.validate_message(message) == :ok
      end
    end

    test "rejects invalid role" do
      message = %{role: "system", content: [%{type: "text", text: "Test"}]}

      assert {:error, error_msg} = MessageBuilder.validate_message(message)
      assert error_msg =~ "Invalid message format"
    end

    test "rejects message without content list" do
      message = %{role: "user", content: "string"}

      assert {:error, error_msg} = MessageBuilder.validate_message(message)
      assert error_msg =~ "Invalid message format"
    end

    test "rejects invalid content block" do
      message = %{
        role: "user",
        content: [%{invalid: "block"}]
      }

      assert {:error, "Invalid content blocks"} = MessageBuilder.validate_message(message)
    end

    test "rejects unsupported image media type" do
      message = %{
        role: "user",
        content: [
          %{
            type: "image",
            source: %{type: "base64", media_type: "image/bmp", data: "data"}
          }
        ]
      }

      assert {:error, "Invalid content blocks"} = MessageBuilder.validate_message(message)
    end
  end

  describe "metadata generation" do
    test "generates unique message IDs" do
      msg1 = MessageBuilder.build_user_message("Test 1")
      msg2 = MessageBuilder.build_user_message("Test 2")

      assert msg1.metadata.id != msg2.metadata.id
      assert String.starts_with?(msg1.metadata.id, "msg_")
      assert String.starts_with?(msg2.metadata.id, "msg_")
    end

    test "generates ISO 8601 timestamps" do
      message = MessageBuilder.build_user_message("Test")

      # Verify timestamp is valid ISO 8601 format
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(message.metadata.timestamp)
    end

    test "handles additional metadata keys" do
      message = MessageBuilder.build_user_message("Test", usage: %{tokens: 100})

      assert message.metadata.usage == %{tokens: 100}
    end

    test "base metadata takes precedence over additional keys" do
      message = MessageBuilder.build_user_message("Test",
        id: "custom-id",
        custom_field: "value"
      )

      assert message.metadata.id == "custom-id"
      assert message.metadata.custom_field == "value"
    end
  end
end
