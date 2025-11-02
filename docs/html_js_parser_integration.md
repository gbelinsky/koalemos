# HTML and JavaScript Parser Integration

This document shows how to use the HTMLParser and JavaScriptParser together in a pipeline pattern for complete wireframe analysis.

## Pipeline Pattern

The parsers are independent and composable. Use them together to extract both structure and behavior from HTML wireframes:

```elixir
# Step 1: Parse HTML structure
{:ok, html_result} = Koalemos.Parsers.HTMLParser.parse_html(html_string)

# Step 2: Extract JavaScript from inline scripts
inline_scripts = Enum.filter(html_result.script_elements, fn script ->
  script.type == :inline
end)

parsed_scripts = Enum.map(inline_scripts, fn script ->
  case Koalemos.Parsers.JavaScriptParser.parse(script.content) do
    {:ok, result} -> result
    {:error, _reason} -> nil
  end
end)
|> Enum.reject(&is_nil/1)

# Step 3: Combine results
complete_analysis = %{
  dom_tree: html_result.dom_tree,
  styles: html_result.style_elements,
  metadata: html_result.metadata,
  javascript: %{
    variables: merge_all(parsed_scripts, :variables),
    functions: merge_all(parsed_scripts, :functions),
    handlers: merge_all(parsed_scripts, :handlers),
    init_scripts: Enum.map(parsed_scripts, & &1.init_script)
  }
}
```

## Example: Complete Wireframe Analysis

```elixir
html = """
<!DOCTYPE html>
<html>
<head>
  <title>Counter App</title>
  <style>
    .counter { font-size: 24px; }
    .button { padding: 10px; }
  </style>
  <script>
    window.count = 0;
    window.increment = () => {
      count++;
      updateDisplay();
    };
  </script>
</head>
<body>
  <div id="app">
    <div id="counter" class="counter">0</div>
    <button id="inc-btn" class="button">Increment</button>
  </div>
  <script>
    document.getElementById('inc-btn').addEventListener('click', function() {
      window.increment();
    });
  </script>
</body>
</html>
"""

# Parse it
{:ok, html_result} = Koalemos.Parsers.HTMLParser.parse_html(html)

# Extract JavaScript
inline_scripts = Enum.filter(html_result.script_elements, & &1.type == :inline)
{:ok, js1} = Koalemos.Parsers.JavaScriptParser.parse(Enum.at(inline_scripts, 0).content)
{:ok, js2} = Koalemos.Parsers.JavaScriptParser.parse(Enum.at(inline_scripts, 1).content)

# Results:
# html_result.dom_tree - Full DOM tree with div#app, div#counter, button#inc-btn
# html_result.style_elements - CSS for .counter and .button
# html_result.metadata - Title "Counter App"
# js1.variables - %{"count" => 0}
# js1.functions - %{"increment" => "() => { ... }"}
# js2.handlers - %{"inc-btn" => %{"click" => %{params: [], body: "window.increment();"}}}
```

## Use Cases

### 1. Wireframe Editor
- Parse HTML to get DOM tree for manipulation
- Parse JavaScript to understand behavior
- Modify tree and regenerate HTML + JS

### 2. Static Analysis
- Extract all variables and their initial values
- Map element IDs to their event handlers
- Identify unused functions or handlers

### 3. Documentation Generation
- Extract component structure from DOM
- Document component behaviors from handlers
- Generate API documentation from functions

## Error Handling

Both parsers return `{:ok, result}` or `{:error, reason}`. Handle errors gracefully:

```elixir
with {:ok, html_result} <- HTMLParser.parse_html(html),
     {:ok, js_result} <- JavaScriptParser.parse(script_content) do
  # Success: use results
  process_results(html_result, js_result)
else
  {:error, reason} ->
    Logger.error("Parse failed: #{reason}")
    {:error, reason}
end
```

## Performance Notes

- **HTMLParser**: Fast, Floki-based parsing (~milliseconds for typical wireframes)
- **JavaScriptParser**: AST-based, more expensive (~10-50ms per script depending on size)
- **Recommendation**: Cache parsed results when possible, especially for large JavaScript files

## Future Enhancements

- **CSS Parser** (Sprint 6): Parse and manipulate CSS rules
- **HTML Generation**: Regenerate HTML from modified DOM tree
- **JavaScript Generation**: Reconstruct scripts from parsed components
