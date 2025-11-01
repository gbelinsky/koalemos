defmodule Koalemos.Integrations.ParsingIntegrationTest do
  use ExUnit.Case, async: false
  alias Koalemos.Integrations.ParsingIntegration
  alias Koalemos.Caches.DOMStateCache
  alias Koalemos.Caches.VariableStateCache

  setup do
    # Clear all caches before each test
    DOMStateCache.clear_all()
    VariableStateCache.clear_all()

    # Use unique routine IDs per test to avoid conflicts
    routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"
    {:ok, routine_id: routine_id}
  end

  describe "parse_wireframe/2" do
    test "parses simple HTML with inline JavaScript", %{routine_id: routine_id} do
      html = """
      <div id="counter">
        <button id="btn">Click me</button>
        <script>
          window.count = 0;
          window.increment = function() { window.count++; };
        </script>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Check DOM structure (script tag filtered out, only button remains)
      assert wireframe.dom_tree.tag == "div"
      assert wireframe.dom_tree.id == "counter"
      assert length(wireframe.dom_tree.children) == 1

      # Check JavaScript extraction
      assert wireframe.javascript.variables == %{"count" => 0}
      assert Map.has_key?(wireframe.javascript.functions, "increment")

      # Check parse results
      assert wireframe.parse_results.scripts_parsed == 1
      assert wireframe.parse_results.scripts_failed == 0
      assert wireframe.parse_results.variables_stored == 1
    end

    test "extracts and merges handlers from inline scripts", %{routine_id: routine_id} do
      html = """
      <div>
        <button id="btn">Click</button>
        <input id="field" />
        <script>
          document.getElementById('btn').addEventListener('click', function(event) {
            console.log('clicked');
          });
          document.getElementById('field').addEventListener('focus', function() {
            console.log('focused');
          });
        </script>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Check handlers extracted
      assert Map.has_key?(wireframe.javascript.handlers, "btn")
      assert Map.has_key?(wireframe.javascript.handlers, "field")

      # Check button click handler
      btn_handlers = wireframe.javascript.handlers["btn"]
      assert Map.has_key?(btn_handlers, "click")
      assert btn_handlers["click"].params == ["event"]
      assert btn_handlers["click"].body =~ "console.log('clicked')"

      # Check field focus handler
      field_handlers = wireframe.javascript.handlers["field"]
      assert Map.has_key?(field_handlers, "focus")
      assert field_handlers["focus"].params == []
      assert field_handlers["focus"].body =~ "console.log('focused')"
    end

    test "merges handlers from multiple scripts", %{routine_id: routine_id} do
      html = """
      <div>
        <button id="btn">Click</button>
        <script>
          document.getElementById('btn').addEventListener('click', function() {
            console.log('first click handler');
          });
        </script>
        <script>
          document.getElementById('btn').addEventListener('blur', function() {
            console.log('blur handler');
          });
        </script>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Should have both handlers for same element
      btn_handlers = wireframe.javascript.handlers["btn"]
      assert Map.has_key?(btn_handlers, "click")
      assert Map.has_key?(btn_handlers, "blur")
      assert btn_handlers["click"].body =~ "first click handler"
      assert btn_handlers["blur"].body =~ "blur handler"
    end

    test "merges variables from multiple scripts (last wins)", %{routine_id: routine_id} do
      html = """
      <div>
        <script>
          window.count = 0;
          window.name = "Alice";
        </script>
        <script>
          window.count = 10;
          window.age = 30;
        </script>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Last script wins for 'count'
      assert wireframe.javascript.variables["count"] == 10
      assert wireframe.javascript.variables["name"] == "Alice"
      assert wireframe.javascript.variables["age"] == 30
      assert wireframe.parse_results.scripts_parsed == 2
    end

    test "stores initial DOM in DOMStateCache", %{routine_id: routine_id} do
      html = """
      <div id="root" class="container">
        <h1 id="title">Hello</h1>
      </div>
      """

      {:ok, _wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Check DOM cached
      cached_dom = DOMStateCache.get_dom_state(routine_id)
      assert cached_dom != nil
      assert cached_dom.change_type == "initial_parse"

      # Check DOM structure (DOMStateCache converts to atom keys internally)
      live_dom = cached_dom.live_dom_tree
      assert live_dom.tag == "div"
      assert live_dom.id == "root"
      assert live_dom.classes == ["container"]
      assert length(live_dom.children) == 1

      # Check nested child
      h1 = hd(live_dom.children)
      assert h1.tag == "h1"
      assert h1.id == "title"
    end

    test "stores initial variables in VariableStateCache", %{routine_id: routine_id} do
      html = """
      <div>
        <script>
          window.x = 42;
          window.y = "test";
        </script>
      </div>
      """

      {:ok, _wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Check variables cached
      cached_vars = VariableStateCache.get_variable_state(routine_id)
      assert cached_vars == %{"x" => 42, "y" => "test"}
    end

    test "converts DOM format to JS format for cache storage", %{
      routine_id: routine_id
    } do
      html = """
      <div id="parent" class="wrapper">
        <span id="child">Content</span>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Wireframe has atom keys from HTMLParser
      assert is_binary(wireframe.dom_tree.tag)
      assert wireframe.dom_tree.tag == "div"

      # Cache converts to atom keys internally
      cached_dom = DOMStateCache.get_dom_state(routine_id)
      live_dom = cached_dom.live_dom_tree
      assert is_binary(live_dom.tag)
      assert live_dom.tag == "div"
      assert live_dom.id == "parent"
      assert live_dom.classes == ["wrapper"]

      # Check child converted too
      child = hd(live_dom.children)
      assert child.tag == "span"
      assert child.id == "child"
    end

    test "handles HTML with no inline scripts", %{routine_id: routine_id} do
      html = """
      <div id="static">
        <p>Just HTML, no JavaScript</p>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Should still parse HTML successfully
      assert wireframe.dom_tree.tag == "div"
      assert wireframe.dom_tree.id == "static"

      # JavaScript fields should be empty
      assert wireframe.javascript.variables == %{}
      assert wireframe.javascript.functions == %{}
      assert wireframe.javascript.handlers == %{}
      assert wireframe.parse_results.scripts_parsed == 0
    end

    test "handles external scripts (ignores them)", %{routine_id: routine_id} do
      html = """
      <div>
        <script src="external.js"></script>
        <script>window.inline = true;</script>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Only inline script parsed
      assert wireframe.parse_results.scripts_parsed == 1
      assert wireframe.javascript.variables == %{"inline" => true}
    end

    test "collects errors when JavaScript parsing fails", %{routine_id: routine_id} do
      html = """
      <div>
        <script>
          window.valid = 1;
        </script>
        <script>
          this is invalid javascript!@#$
        </script>
        <script>
          window.alsoValid = 2;
        </script>
      </div>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Should have 2 successful parses, 1 failure
      assert wireframe.parse_results.scripts_parsed == 2
      assert wireframe.parse_results.scripts_failed == 1
      assert length(wireframe.parse_results.errors) == 1

      # Valid scripts should still be processed
      assert wireframe.javascript.variables["valid"] == 1
      assert wireframe.javascript.variables["alsoValid"] == 2
    end

    test "handles malformed HTML gracefully", %{routine_id: routine_id} do
      # HTMLParser uses Floki which is very lenient and handles most malformed HTML
      # It will still parse incomplete tags
      html = "<div><unclosed>"

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Should parse successfully despite malformed HTML (Floki is forgiving)
      assert wireframe.dom_tree != nil
    end

    test "handles empty HTML", %{routine_id: routine_id} do
      html = ""

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Should parse successfully but be empty
      assert wireframe.parse_results.scripts_parsed == 0
      assert wireframe.javascript.variables == %{}
    end
  end

  describe "cache isolation" do
    test "multiple routines store data independently" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      html_1 = """
      <div id="one"><script>window.x = 1;</script></div>
      """

      html_2 = """
      <div id="two"><script>window.x = 2;</script></div>
      """

      {:ok, _wireframe1} = ParsingIntegration.parse_wireframe(html_1, routine_1)
      {:ok, _wireframe2} = ParsingIntegration.parse_wireframe(html_2, routine_2)

      # Check routine 1 cache
      vars_1 = VariableStateCache.get_variable_state(routine_1)
      dom_1 = DOMStateCache.get_dom_state(routine_1)
      assert vars_1["x"] == 1
      assert dom_1.live_dom_tree.id == "one"

      # Check routine 2 cache
      vars_2 = VariableStateCache.get_variable_state(routine_2)
      dom_2 = DOMStateCache.get_dom_state(routine_2)
      assert vars_2["x"] == 2
      assert dom_2.live_dom_tree.id == "two"
    end
  end

  describe "integration - counter app" do
    test "parses complete counter wireframe with all features", %{routine_id: routine_id} do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>Counter App</title>
        <style>
          .container { padding: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Counter Demo</h1>
          <button id="increment-btn">Increment</button>
          <button id="decrement-btn">Decrement</button>
          <div id="display">Count: <span id="count-value">0</span></div>
        </div>

        <script>
          // Initialize counter
          window.count = 0;

          // Update display function
          window.updateDisplay = function() {
            document.getElementById('count-value').textContent = window.count;
          };

          // Increment handler
          document.getElementById('increment-btn').addEventListener('click', function() {
            window.count++;
            window.updateDisplay();
          });
        </script>

        <script>
          // Decrement handler in separate script
          document.getElementById('decrement-btn').addEventListener('click', function() {
            window.count--;
            window.updateDisplay();
          });
        </script>
      </body>
      </html>
      """

      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      # Check DOM structure (HTMLParser extracts body content)
      # So we get the .container div as root, not <html>
      assert wireframe.dom_tree.tag == "div"
      # HTMLParser may extract as direct container or wrap multiple elements
      assert is_list(wireframe.dom_tree.classes)

      # Check metadata
      assert wireframe.metadata.title == "Counter App"

      # Check styles extracted
      assert length(wireframe.styles) == 1
      assert hd(wireframe.styles).type == :inline

      # Check variables
      assert wireframe.javascript.variables["count"] == 0

      # Check functions
      assert Map.has_key?(wireframe.javascript.functions, "updateDisplay")

      # Check handlers (from both scripts)
      assert Map.has_key?(wireframe.javascript.handlers, "increment-btn")
      assert Map.has_key?(wireframe.javascript.handlers, "decrement-btn")

      inc_handler = wireframe.javascript.handlers["increment-btn"]["click"]
      assert inc_handler.body =~ "window.count++"

      dec_handler = wireframe.javascript.handlers["decrement-btn"]["click"]
      assert dec_handler.body =~ "window.count--"

      # Check parse results
      assert wireframe.parse_results.scripts_parsed == 2
      assert wireframe.parse_results.scripts_failed == 0
      assert wireframe.parse_results.errors == []

      # Verify cached in DOMStateCache
      cached_dom = DOMStateCache.get_dom_state(routine_id)
      assert cached_dom != nil
      assert cached_dom.live_dom_tree.tag == "div"

      # Verify cached in VariableStateCache
      cached_vars = VariableStateCache.get_variable_state(routine_id)
      assert cached_vars["count"] == 0
    end
  end
end
