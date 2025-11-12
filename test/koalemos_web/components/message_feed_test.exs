defmodule KoalemosWeb.MessageFeedTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias KoalemosWeb.MessageFeed

  # NOTE: Component rendering tests require proper LiveView/Component context and are
  # difficult to test in isolation. The component is visually and functionally tested
  # via the samples page at /samples.

  describe "deduplicate_messages/1" do
    test "removes duplicate messages by id" do
      messages = [
        %{
          role: "user",
          content: "Hello",
          metadata: %{id: "msg-1", timestamp: 1_234_567_890}
        },
        %{
          role: "user",
          content: "Hello",
          metadata: %{id: "msg-1", timestamp: 1_234_567_890}
        }
      ]

      deduplicated = MessageFeed.deduplicate_messages(messages)

      assert length(deduplicated) == 1
      assert hd(deduplicated).metadata.id == "msg-1"
    end

    test "keeps messages with different ids" do
      messages = [
        %{
          role: "user",
          content: "Hello",
          metadata: %{id: "msg-1", timestamp: 1_234_567_890}
        },
        %{
          role: "user",
          content: "World",
          metadata: %{id: "msg-2", timestamp: 1_234_567_891}
        }
      ]

      deduplicated = MessageFeed.deduplicate_messages(messages)

      assert length(deduplicated) == 2
    end

    test "handles messages without metadata.id by generating fallback id" do
      messages = [
        %{
          role: "user",
          content: "Hello"
        },
        %{
          role: "user",
          content: "World"
        }
      ]

      deduplicated = MessageFeed.deduplicate_messages(messages)

      # Should keep both since they have different content hashes
      assert length(deduplicated) == 2
    end

    test "preserves message order after deduplication" do
      messages = [
        %{
          role: "user",
          content: "First",
          metadata: %{id: "msg-1", timestamp: 1_234_567_890}
        },
        %{
          role: "assistant",
          content: "Second",
          metadata: %{id: "msg-2", timestamp: 1_234_567_891}
        },
        %{
          role: "user",
          content: "Third",
          metadata: %{id: "msg-3", timestamp: 1_234_567_892}
        }
      ]

      deduplicated = MessageFeed.deduplicate_messages(messages)

      assert Enum.at(deduplicated, 0).content == "First"
      assert Enum.at(deduplicated, 1).content == "Second"
      assert Enum.at(deduplicated, 2).content == "Third"
    end
  end

  # NOTE: handle_event tests require proper LiveView socket setup and are difficult
  # to test in isolation. The component's event handling is visually tested via the
  # samples page at /samples.

  describe "extract_error_message/1" do
    test "extracts string content" do
      message = %{content: "Error occurred"}
      assert MessageFeed.extract_error_message(message) == "Error occurred"
    end

    test "extracts text from list of blocks" do
      message = %{
        content: [
          %{type: "text", text: "Error part 1"},
          %{type: "text", text: "Error part 2"}
        ]
      }

      result = MessageFeed.extract_error_message(message)
      assert result =~ "Error part 1"
      assert result =~ "Error part 2"
    end

    test "handles empty content" do
      message = %{content: ""}
      assert MessageFeed.extract_error_message(message) == ""
    end
  end
end
