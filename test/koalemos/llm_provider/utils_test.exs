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
end
