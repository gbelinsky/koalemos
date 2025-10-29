defmodule KoalemosWeb.ChatPanelTest do
  use ExUnit.Case, async: true

  alias KoalemosWeb.ChatPanel

  describe "create_user_message/2" do
    test "creates text-only message" do
      text = "Hello, world!"
      images = []

      message = ChatPanel.create_user_message(text, images)

      assert message.role == "user"
      assert message.content == "Hello, world!"
      assert message.metadata.source == :user
      assert is_binary(message.metadata.id)
      assert is_integer(message.metadata.timestamp)
    end

    test "creates message with text and images" do
      text = "Check out this image"

      images = [
        %{
          base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
          media_type: "image/png",
          filename: "test.png",
          size: 100
        }
      ]

      message = ChatPanel.create_user_message(text, images)

      assert message.role == "user"
      assert is_list(message.content)
      assert length(message.content) == 2

      [text_block, image_block] = message.content

      assert text_block.type == "text"
      assert text_block.text == "Check out this image"

      assert image_block.type == "image"
      assert image_block.source.data == List.first(images).base64
      assert image_block.source.media_type == "image/png"

      assert message.metadata.source == :user
    end

    test "creates message with images only (no text)" do
      text = ""

      images = [
        %{
          base64: "abc123",
          media_type: "image/jpeg",
          filename: "photo.jpg",
          size: 200
        }
      ]

      message = ChatPanel.create_user_message(text, images)

      assert message.role == "user"
      assert is_list(message.content)
      assert length(message.content) == 1

      [image_block] = message.content

      assert image_block.type == "image"
      assert image_block.source.data == "abc123"
      assert image_block.source.media_type == "image/jpeg"
    end

    test "creates message with multiple images" do
      text = "Two images"

      images = [
        %{base64: "img1", media_type: "image/png", filename: "1.png", size: 100},
        %{base64: "img2", media_type: "image/jpeg", filename: "2.jpg", size: 200}
      ]

      message = ChatPanel.create_user_message(text, images)

      assert is_list(message.content)
      assert length(message.content) == 3

      [text_block, img1_block, img2_block] = message.content

      assert text_block.type == "text"
      assert img1_block.type == "image"
      assert img1_block.source.data == "img1"
      assert img2_block.type == "image"
      assert img2_block.source.data == "img2"
    end

    test "message IDs are unique" do
      msg1 = ChatPanel.create_user_message("test1", [])
      msg2 = ChatPanel.create_user_message("test2", [])

      assert msg1.metadata.id != msg2.metadata.id
    end
  end
end
