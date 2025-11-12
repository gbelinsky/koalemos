defmodule KoalemosWeb.MessageCards.HelpersTest do
  use ExUnit.Case, async: true
  import KoalemosWeb.MessageCards.Helpers

  describe "generate_card_id/1" do
    test "generates ID from binary timestamp" do
      message = %{metadata: %{timestamp: "2024-10-28T12:00:00Z"}}
      id = generate_card_id(message)
      assert String.starts_with?(id, "card_")
      assert is_binary(id)
    end

    test "generates ID from integer timestamp" do
      message = %{metadata: %{timestamp: 1_234_567_890}}
      id = generate_card_id(message)
      assert id == "card_1234567890"
    end

    test "generates ID from DateTime" do
      dt = DateTime.utc_now()
      message = %{metadata: %{timestamp: dt}}
      id = generate_card_id(message)
      assert String.starts_with?(id, "card_")
    end

    test "generates fallback ID when no timestamp" do
      message = %{content: "test"}
      id = generate_card_id(message)
      assert String.starts_with?(id, "card_")
    end
  end

  describe "extract_text_content/1" do
    test "returns string content as-is" do
      assert extract_text_content("Hello world") == "Hello world"
    end

    test "extracts text from content array" do
      content = [
        %{type: "text", text: "Hello "},
        %{type: "text", text: "world"}
      ]

      assert extract_text_content(content) == "Hello  world"
    end

    test "extracts text from content array with string keys" do
      content = [
        %{"type" => "text", "text" => "Hello "},
        %{"type" => "text", "text" => "world"}
      ]

      assert extract_text_content(content) == "Hello  world"
    end

    test "ignores non-text items in array" do
      content = [
        %{type: "text", text: "Hello"},
        %{type: "image", source: %{}},
        %{type: "text", text: "world"}
      ]

      assert extract_text_content(content) == "Hello world"
    end

    test "handles tool_result content" do
      content = [
        %{type: "tool_result", content: "Tool output"}
      ]

      assert extract_text_content(content) == "Tool output"
    end

    test "handles other types by inspecting" do
      content = %{some: "map"}
      result = extract_text_content(content)
      assert result =~ "some"
    end

    test "handles empty list" do
      assert extract_text_content([]) == ""
    end
  end

  describe "extract_text_and_images/1" do
    test "extracts text and images from content array" do
      content = [
        %{type: "text", text: "Hello"},
        %{type: "image", source: %{data: "base64data"}},
        %{type: "text", text: "world"}
      ]

      {text, images} = extract_text_and_images(content)
      assert text == "Hello world"
      assert length(images) == 1
      assert hd(images).type == "image"
    end

    test "extracts text and images with string keys" do
      content = [
        %{"type" => "text", "text" => "Test"},
        %{"type" => "image", "source" => %{"data" => "xyz"}}
      ]

      {text, images} = extract_text_and_images(content)
      assert text == "Test"
      assert length(images) == 1
    end

    test "handles string content" do
      {text, images} = extract_text_and_images("Just text")
      assert text == "Just text"
      assert images == []
    end

    test "removes [with N image(s)] pattern from string" do
      {text, images} = extract_text_and_images("Message [with 2 image(s)]")
      assert text == "Message"
      assert images == []
    end

    test "handles empty content" do
      {text, images} = extract_text_and_images([])
      assert text == ""
      assert images == []
    end

    test "handles nil or other types" do
      {text, images} = extract_text_and_images(nil)
      assert text == ""
      assert images == []
    end
  end

  describe "has_images?/1" do
    test "returns true for message with image in content array" do
      message = %{
        content: [
          %{type: "text", text: "Test"},
          %{type: "image", source: %{}}
        ]
      }

      assert has_images?(message) == true
    end

    test "returns true for message with image (string keys)" do
      message = %{
        content: [
          %{"type" => "text", "text" => "Test"},
          %{"type" => "image", "source" => %{}}
        ]
      }

      assert has_images?(message) == true
    end

    test "returns false for message without images" do
      message = %{
        content: [%{type: "text", text: "Test"}]
      }

      assert has_images?(message) == false
    end

    test "returns true for string content with [with N image(s)] pattern" do
      message = %{content: "Test [with 2 image(s)]"}
      assert has_images?(message) == true
    end

    test "returns false for plain string content" do
      message = %{content: "Just text"}
      assert has_images?(message) == false
    end

    test "returns false for empty content" do
      message = %{content: []}
      assert has_images?(message) == false
    end
  end
end
