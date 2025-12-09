defmodule Koalemos.Parsers.CSSParser do
  @moduledoc """
  CSS parser for wireframe editor.

  Parses CSS into structured rules for manipulation and display.
  Uses Node.js `css` library for robust parsing.

  ## Usage

      iex> css = ".button { padding: 20px; margin: 10px; }"
      iex> {:ok, result} = CSSParser.parse(css)
      iex> result.rules
      %{".button" => %{"padding" => "20px", "margin" => "10px"}}

  ## Output Format

      %{
        rules: %{
          ".button" => %{"padding" => "20px", "margin" => "10px"},
          "h1, h2" => %{"color" => "blue"}
        }
      }

  ## Notes

  - Ignores @media, @keyframes, and other at-rules for MVP
  - Multiple selectors are joined with ", "
  - Duplicate selectors are merged
  - Invalid CSS returns {:error, reason}
  """

  @doc """
  Parse CSS string into structured rules.

  Returns `{:ok, %{rules: %{...}}}` or `{:error, reason}`.

  ## Examples

      iex> CSSParser.parse(".btn { color: red; }")
      {:ok, %{rules: %{".btn" => %{"color" => "red"}}}}

      iex> CSSParser.parse("invalid {{{")
      {:error, "CSS parsing failed: ..."}

  """
  def parse(css_content) when is_binary(css_content) do
    try do
      result = NodeJS.call!({"css_parser", :parseCSS}, [css_content])
      {:ok, %{rules: Map.get(result, "rules", %{})}}
    rescue
      e ->
        {:error, "CSS parsing failed: #{Exception.message(e)}"}
    end
  end
end
