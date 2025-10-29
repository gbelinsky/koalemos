defmodule Koalemos.Lenses.TestLens do
  @moduledoc """
  A simple test lens that provides basic context for AI conversations.
  Used for testing and demonstrating the lens system.
  """

  @doc """
  Provides simple context about the Koalemos system.
  Returns a list of text context blocks.
  """
  def provide_context(_state) do
    [
      """
      You are a helpful AI assistant in the Koalemos chat system.
      Koalemos is a conversational AI platform that uses routines and lenses.
      Be friendly, helpful, and concise in your responses.
      """
    ]
  end
end
