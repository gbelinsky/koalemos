defmodule WireframeEditorWeb.Integrations.ParsingIntegration do
  @moduledoc """
  Integration layer connecting HTML and JavaScript parsers.

  This module orchestrates the complete parsing pipeline:
  1. Parse HTML to extract DOM structure and inline scripts
  2. Parse each inline JavaScript snippet
  3. Merge results from multiple scripts
  4. Return complete wireframe structure for editor use

  ## Design-Time vs Runtime Data

  **Design-Time Data** (returned from parse_wireframe):
  - DOM tree structure
  - JavaScript handlers, functions, init scripts
  - Styles and metadata

  **Runtime Data** (managed by StateServer):
  - Initial DOM structure
  - Initial variable values
  - Console output (during execution)

  ## Handler Storage

  Event handlers are design-time data extracted during parsing and returned
  in the wireframe structure for immediate use by the wireframe editor.

  Handlers format: `%{"element-id" => %{"event-type" => %{params: [...], body: "..."}}}`

  ## Usage

      alias WireframeEditorWeb.Integrations.ParsingIntegration

      html = \"\"\"
      <div id="counter">
        <button id="btn">Count: <span id="display">0</span></button>
        <script>
          window.count = 0;
          document.getElementById('btn').addEventListener('click', function() {
            window.count++;
            document.getElementById('display').textContent = window.count;
          });
        </script>
      </div>
      \"\"\"

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, "routine-123")

      # Access complete structure
      wireframe.dom_tree           # Full DOM with nested children
      wireframe.javascript.variables    # %{"count" => 0}
      wireframe.javascript.handlers     # %{"btn" => %{"click" => %{...}}}
      wireframe.javascript.functions    # %{}
      wireframe.javascript.init_scripts # [...remaining code...]
  """

  alias WireframeEditorWeb.Parsers.HTMLParser
  alias WireframeEditorWeb.Parsers.JavaScriptParser
  alias WireframeEditorWeb.Parsers.CSSParser

  require Logger

  @doc """
  Parse HTML wireframe and extract all design-time data.

  Parses HTML structure, extracts and parses inline JavaScript, merges results
  from multiple scripts.

  ## Parameters

  - `html_string` - The HTML content to parse
  - `routine_id` - The routine identifier (for logging/context)

  ## Returns

  `{:ok, wireframe_data}` on success with structure:

      %{
        dom_tree: %{tag: "div", id: "...", children: [...]},
        scripts: [%{type: :inline, content: "..."}, %{type: :external, src: "..."}],
        styles: [%{type: :inline, content: "..."}, %{type: :external, src: "..."}],
        css_rules: %{"selector" => %{"property" => "value", ...}},
        metadata: %{title: "...", meta_tags: [...]},
        javascript: %{
          variables: %{"varName" => value},
          functions: %{"funcName" => "code"},
          handlers: %{"element-id" => %{"event" => %{params: [], body: "..."}}},
          init_scripts: ["remaining code..."]
        },
        parse_results: %{
          scripts_parsed: N,
          scripts_failed: N,
          styles_parsed: N,
          styles_failed: N,
          variables_stored: N,
          errors: [...]
        }
      }

  `{:error, reason}` on failure

  ## Examples

      iex> html = "<div><script>window.x = 1;</script></div>"
      iex> {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, "test-123")
      iex> wireframe.javascript.variables
      %{"x" => 1}
  """
  @spec parse_wireframe(String.t(), String.t()) ::
          {:ok, map()} | {:error, any()}
  def parse_wireframe(html_string, routine_id)
      when is_binary(html_string) and is_binary(routine_id) do
    with {:ok, html_result} <- HTMLParser.parse_html(html_string),
         {:ok, js_results, js_errors} <- parse_inline_scripts(html_result),
         {:ok, css_rules, css_errors} <- parse_inline_styles(html_result) do
      # Merge JavaScript results from all scripts
      merged_js = merge_javascript_results(js_results)

      # Combine errors from both JS and CSS parsing
      all_errors = js_errors ++ css_errors

      # Build complete wireframe structure
      wireframe_data = %{
        dom_tree: html_result.dom_tree,
        scripts: html_result.script_elements,
        styles: html_result.style_elements,
        css_rules: css_rules,
        metadata: html_result.metadata,
        javascript: merged_js,
        parse_results: %{
          scripts_parsed: length(js_results),
          scripts_failed: length(js_errors),
          styles_parsed: length(html_result.style_elements |> Enum.filter(&(&1.type == :inline))),
          styles_failed: length(css_errors),
          variables_stored: map_size(merged_js.variables),
          errors: all_errors
        }
      }

      {:ok, wireframe_data}
    else
      {:error, reason} = error ->
        Logger.error("[ParsingIntegration] Failed to parse HTML: #{inspect(reason)}")
        error
    end
  end

  # Parse all inline JavaScript snippets from HTML result
  @spec parse_inline_scripts(map()) :: {:ok, list(map()), list(String.t())}
  defp parse_inline_scripts(html_result) do
    inline_scripts =
      html_result.script_elements
      |> Enum.filter(&(&1.type == :inline))

    # Parse each script, collecting successes and errors
    {parsed_results, errors} =
      Enum.reduce(inline_scripts, {[], []}, fn script, {results, errs} ->
        case JavaScriptParser.parse(script.content) do
          {:ok, result} ->
            {[result | results], errs}

          {:error, reason} ->
            error_msg = "Failed to parse script: #{inspect(reason)}"
            Logger.warning("[ParsingIntegration] #{error_msg}")
            {results, [error_msg | errs]}
        end
      end)

    {:ok, Enum.reverse(parsed_results), Enum.reverse(errors)}
  end

  # Parse all inline CSS snippets from HTML result
  # CSS parser returns rules as map: %{selector => %{prop => value}}
  @spec parse_inline_styles(map()) :: {:ok, map(), list(String.t())}
  defp parse_inline_styles(html_result) do
    inline_styles =
      html_result.style_elements
      |> Enum.filter(&(&1.type == :inline))

    # Parse each style block, collecting all rules and errors
    # Rules are merged (later declarations override earlier ones)
    {all_rules, errors} =
      Enum.reduce(inline_styles, {%{}, []}, fn style, {rules, errs} ->
        case CSSParser.parse(style.content) do
          {:ok, result} ->
            {Map.merge(rules, result.rules), errs}

          {:error, reason} ->
            error_msg = "Failed to parse CSS: #{inspect(reason)}"
            Logger.warning("[ParsingIntegration] #{error_msg}")
            {rules, [error_msg | errs]}
        end
      end)

    {:ok, all_rules, Enum.reverse(errors)}
  end

  # Merge JavaScript parsing results from multiple scripts
  @spec merge_javascript_results(list(map())) :: map()
  defp merge_javascript_results(js_results) do
    %{
      variables: merge_all(js_results, :variables),
      functions: merge_all(js_results, :functions),
      handlers: merge_handlers(js_results),
      init_scripts: Enum.map(js_results, & &1.init_script)
    }
  end

  # Merge a specific field from all parsing results
  # Last script wins for duplicate keys
  @spec merge_all(list(map()), atom()) :: map()
  defp merge_all(results, field) do
    results
    |> Enum.map(&Map.get(&1, field, %{}))
    |> Enum.reduce(%{}, &Map.merge(&2, &1))
  end

  # Merge handlers from multiple scripts
  # Handles nested structure: element_id -> event_type -> handler
  @spec merge_handlers(list(map())) :: map()
  defp merge_handlers(results) do
    results
    |> Enum.map(&Map.get(&1, :handlers, %{}))
    |> Enum.reduce(%{}, fn handlers, acc ->
      Map.merge(acc, handlers, fn _element_id, events1, events2 ->
        # Merge events for the same element (last wins for duplicate event types)
        Map.merge(events1, events2)
      end)
    end)
  end
end
