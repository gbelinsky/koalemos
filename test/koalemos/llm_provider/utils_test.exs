defmodule Koalemos.LLMProvider.UtilsTest do
  use ExUnit.Case, async: true
  alias Koalemos.LLMProvider.Utils
  doctest Koalemos.LLMProvider.Utils

  describe "strip_metadata/1" do
    test "removes metadata from message" do
      message = %{
        role: "user",
        content: [%{type: "text", text: "Hello"}],
        metadata: %{id: "msg_123", timestamp: "2024-10-27"}
      }

      result = Utils.strip_metadata(message)

      assert result == %{
        role: "user",
        content: [%{type: "text", text: "Hello"}]
      }
      refute Map.has_key?(result, :metadata)
    end

    test "keeps message without metadata unchanged" do
      message = %{role: "assistant", content: []}

      result = Utils.strip_metadata(message)

      assert result == message
    end
  end

  describe "filter_empty_assistant_messages/1" do
    test "filters out assistant messages with empty array content" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hi"}]},
        %{role: "assistant", content: []},
        %{role: "user", content: [%{type: "text", text: "Hello?"}]}
      ]

      result = Utils.filter_empty_assistant_messages(messages)

      assert length(result) == 2
      assert Enum.all?(result, fn msg -> msg.role == "user" end)
    end

    test "filters out assistant messages with empty string content" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hi"}]},
        %{role: "assistant", content: ""}
      ]

      result = Utils.filter_empty_assistant_messages(messages)

      assert length(result) == 1
      assert hd(result).role == "user"
    end

    test "filters out assistant messages with nil content" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hi"}]},
        %{role: "assistant", content: nil}
      ]

      result = Utils.filter_empty_assistant_messages(messages)

      assert length(result) == 1
    end

    test "keeps non-empty assistant messages" do
      messages = [
        %{role: "user", content: [%{type: "text", text: "Hi"}]},
        %{role: "assistant", content: [%{type: "text", text: "Hello!"}]}
      ]

      result = Utils.filter_empty_assistant_messages(messages)

      assert length(result) == 2
    end

    test "does not filter empty user messages" do
      messages = [
        %{role: "user", content: []},
        %{role: "user", content: [%{type: "text", text: "Hi"}]}
      ]

      result = Utils.filter_empty_assistant_messages(messages)

      assert length(result) == 2
    end
  end

  describe "keep_only_last_screenshot/1" do
    test "keeps only the last screenshot when multiple exist" do
      messages = [
        %{role: "user", content: [%{"type" => "image", "source" => %{"data" => "old1"}}]},
        %{role: "user", content: [%{"type" => "text", "text" => "Hi"}]},
        %{role: "user", content: [%{"type" => "image", "source" => %{"data" => "old2"}}]},
        %{role: "user", content: [%{"type" => "image", "source" => %{"data" => "latest"}}]}
      ]

      result = Utils.keep_only_last_screenshot(messages)

      # Count messages with images
      messages_with_images = Enum.count(result, fn msg ->
        Enum.any?(msg.content, fn block -> Map.get(block, "type") == "image" end)
      end)

      assert messages_with_images == 1
      assert Enum.at(result, 3).content |> hd() |> Map.get("source") |> Map.get("data") == "latest"
    end

    test "handles messages with no screenshots" do
      messages = [
        %{role: "user", content: [%{"type" => "text", "text" => "Hi"}]},
        %{role: "assistant", content: [%{"type" => "text", "text" => "Hello"}]}
      ]

      result = Utils.keep_only_last_screenshot(messages)

      assert result == messages
    end

    test "handles atom keys for type field" do
      messages = [
        %{role: "user", content: [%{type: "image", source: %{data: "image1"}}]},
        %{role: "user", content: [%{type: "image", source: %{data: "image2"}}]}
      ]

      result = Utils.keep_only_last_screenshot(messages)

      messages_with_images = Enum.count(result, fn msg ->
        Enum.any?(msg.content, fn block -> Map.get(block, :type) == "image" end)
      end)

      assert messages_with_images == 1
    end

    test "keeps mixed content in last screenshot message" do
      messages = [
        %{role: "user", content: [%{"type" => "image", "source" => %{}}]},
        %{role: "user", content: [
          %{"type" => "text", "text" => "Look at this:"},
          %{"type" => "image", "source" => %{"data" => "latest"}}
        ]}
      ]

      result = Utils.keep_only_last_screenshot(messages)

      # Last message should have both text and image
      last_message = Enum.at(result, 1)
      assert length(last_message.content) == 2

      # First message should have empty content (image removed)
      first_message = hd(result)
      assert first_message.content == []
    end
  end
end
