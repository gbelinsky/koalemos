defmodule Koalemos.LLMProvider.Utils do
  @moduledoc """
  Common utilities for LLM provider implementations.

  Provides shared functions for message processing that are used
  across multiple provider implementations.
  """

  @doc """
  Strip metadata from a message.

  Messages in the internal format include metadata fields that should
  not be sent to LLM APIs. This function returns a clean message with
  only the API-relevant fields (role and content).

  ## Examples

      iex> msg = %{role: "user", content: "Hi", metadata: %{id: "123"}}
      iex> Koalemos.LLMProvider.Utils.strip_metadata(msg)
      %{role: "user", content: "Hi"}
  """
  def strip_metadata(message) do
    Map.take(message, [:role, :content])
  end

  @doc """
  Filter out empty assistant messages.

  Empty assistant messages (no content, empty array, or nil) should be
  removed before sending to the LLM API. This prevents API errors and
  saves tokens.

  ## Examples

      iex> messages = [
      ...>   %{role: "user", content: [%{type: "text", text: "Hi"}]},
      ...>   %{role: "assistant", content: []},
      ...>   %{role: "user", content: [%{type: "text", text: "Hello?"}]}
      ...> ]
      iex> Koalemos.LLMProvider.Utils.filter_empty_assistant_messages(messages)
      [
        %{role: "user", content: [%{type: "text", text: "Hi"}]},
        %{role: "user", content: [%{type: "text", text: "Hello?"}]}
      ]
  """
  def filter_empty_assistant_messages(messages) do
    Enum.reject(messages, fn msg ->
      msg.role == "assistant" &&
        (msg.content == [] || msg.content == "" || msg.content == nil)
    end)
  end
end
