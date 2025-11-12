defmodule KoalemosWeb.MarkdownHelper do
  @moduledoc """
  Helper functions for rendering markdown content in Phoenix templates.
  """

  @doc """
  Converts markdown text to HTML using Earmark.

  Options:
  - :breaks - Convert line breaks to <br> tags (default: true)
  - :code_class_prefix - Prefix for code block classes (default: "language-")
  - :smartypants - Enable smart quotes and dashes (default: true)
  """
  def markdown_to_html(markdown_text, opts \\ []) when is_binary(markdown_text) do
    default_opts = [
      breaks: true,
      code_class_prefix: "language-",
      smartypants: true
    ]

    options = Keyword.merge(default_opts, opts)

    case Earmark.as_html(markdown_text, options) do
      {:ok, html, _messages} ->
        # Wrap in a div with markdown-specific styling
        # Uses Tailwind prose plugin for consistent markdown rendering
        wrapped_html =
          "<div class=\"markdown-content prose prose-sm prose-slate max-w-none\">#{html}</div>"

        Phoenix.HTML.raw(wrapped_html)

      {:error, _html, messages} ->
        # Log the error and return the original text as a fallback
        require Logger
        Logger.warning("Markdown parsing failed: #{inspect(messages)}")
        Phoenix.HTML.html_escape(markdown_text)
    end
  end

  @doc """
  Safely renders markdown content, handling nil and empty strings gracefully.
  """
  def safe_markdown_to_html(content, opts \\ [])
  def safe_markdown_to_html(nil, _opts), do: ""
  def safe_markdown_to_html("", _opts), do: ""

  def safe_markdown_to_html(content, opts) when is_binary(content) do
    markdown_to_html(content, opts)
  end

  def safe_markdown_to_html(content, _opts) do
    # Handle non-string content by converting to string first
    content
    |> to_string()
    |> markdown_to_html()
  end
end
