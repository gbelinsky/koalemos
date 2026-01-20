defmodule WireframeEditorWeb.MarkdownHelper do
  @moduledoc """
  Helper functions for rendering markdown content in Phoenix templates.
  """

  @doc """
  Converts markdown text to HTML using Earmark.

  Options:
  - :breaks - Convert line breaks to <br> tags (default: true)
  - :code_class_prefix - Prefix for code block classes (default: "language-")
  - :smartypants - Enable smart quotes and dashes (default: true)
  - :skip_wrapper - Skip the prose wrapper div (default: false)
  """
  def markdown_to_html(markdown_text, opts \\ []) when is_binary(markdown_text) do
    skip_wrapper = Keyword.get(opts, :skip_wrapper, false)
    
    default_opts = [
      breaks: true,
      code_class_prefix: "language-",
      smartypants: true
    ]

    # Remove our custom options before passing to Earmark
    earmark_opts = 
      opts
      |> Keyword.delete(:skip_wrapper)
      |> then(&Keyword.merge(default_opts, &1))

    try do
      case Earmark.as_html(markdown_text, earmark_opts) do
        {:ok, html, _messages} ->
          # Optionally wrap in a div with markdown-specific styling
          # Uses Tailwind prose plugin for consistent markdown rendering
          wrapped_html =
            if skip_wrapper do
              html
            else
              "<div class=\"markdown-content prose prose-sm prose-slate max-w-none\">#{html}</div>"
            end

          Phoenix.HTML.raw(wrapped_html)

        {:error, _html, messages} ->
          # Log the error and return the original text as a fallback
          require Logger
          Logger.warning("Markdown parsing failed: #{inspect(messages)}")
          Phoenix.HTML.html_escape(markdown_text)
      end
    rescue
      e ->
        # Catch any exceptions from Earmark (e.g., FunctionClauseError)
        require Logger
        Logger.error("Markdown parsing crashed: #{Exception.format(:error, e, __STACKTRACE__)}")

        # Return escaped text in a pre block to preserve formatting
        escaped_text = Phoenix.HTML.html_escape(markdown_text) |> Phoenix.HTML.safe_to_string()
        Phoenix.HTML.raw("<pre class=\"text-xs overflow-auto p-2 bg-slate-100 rounded\">#{escaped_text}</pre>")
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
