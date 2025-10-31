defmodule Koalemos.Parsers.JavaScriptParserTest do
  use ExUnit.Case, async: true

  alias Koalemos.Parsers.JavaScriptParser

  describe "parse/1 - variables" do
    test "extracts simple number variable" do
      code = "window.myNumber = 42;"
      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.variables == %{"myNumber" => 42}
      assert result.functions == %{}
      assert result.handlers == %{}
      assert result.init_script == ""
    end

    test "extracts string variable" do
      code = ~s(window.myString = "hello world";)
      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.variables == %{"myString" => "hello world"}
    end

    test "extracts boolean variables" do
      code = """
      window.isTrue = true;
      window.isFalse = false;
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.variables == %{"isTrue" => true, "isFalse" => false}
    end

    test "extracts object variable" do
      code = ~s(window.myObj = {"key": "value", "num": 123};)
      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.variables == %{"myObj" => %{"key" => "value", "num" => 123}}
    end

    test "extracts array variable" do
      code = "window.myArray = [1, 2, 3];"
      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.variables == %{"myArray" => [1, 2, 3]}
    end

    test "extracts null variable" do
      code = "window.myNull = null;"
      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.variables == %{"myNull" => nil}
    end

    test "extracts multiple variables" do
      code = """
      window.a = 10;
      window.b = "test";
      window.c = {"x": 1};
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.variables == %{
               "a" => 10,
               "b" => "test",
               "c" => %{"x" => 1}
             }
    end

    test "ignores non-JSON variable values" do
      code = """
      window.valid = 42;
      window.invalid = new Date();
      window.alsoValid = "string";
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      # Only JSON-parseable values are extracted
      assert result.variables == %{"valid" => 42, "alsoValid" => "string"}
    end
  end

  describe "parse/1 - functions" do
    test "extracts arrow function" do
      code = "window.myFunc = () => console.log('hello');"
      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.functions == %{"myFunc" => "() => console.log('hello')"}
      assert result.variables == %{}
    end

    test "extracts arrow function with parameters" do
      code = "window.add = (a, b) => a + b;"
      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.functions == %{"add" => "(a, b) => a + b"}
    end

    test "extracts arrow function with block body" do
      code = """
      window.calculate = (x) => {
        const result = x * 2;
        return result;
      };
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert Map.has_key?(result.functions, "calculate")
      assert String.contains?(result.functions["calculate"], "x * 2")
    end

    test "extracts function expression" do
      code = """
      window.greet = function(name) {
        return "Hello, " + name;
      };
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert Map.has_key?(result.functions, "greet")
      assert String.contains?(result.functions["greet"], "Hello")
    end

    test "extracts multiple functions" do
      code = """
      window.func1 = () => 1;
      window.func2 = () => 2;
      window.func3 = function() { return 3; };
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert Map.has_key?(result.functions, "func1")
      assert Map.has_key?(result.functions, "func2")
      assert Map.has_key?(result.functions, "func3")
    end
  end

  describe "parse/1 - handlers" do
    test "extracts simple click handler" do
      code = """
      document.getElementById('my-button').addEventListener('click', function(event) {
        console.log('clicked');
      });
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.handlers == %{
               "my-button" => %{
                 "click" => %{
                   params: ["event"],
                   body: "console.log('clicked');"
                 }
               }
             }
    end

    test "extracts handler with arrow function" do
      code = """
      document.getElementById('submit-btn').addEventListener('click', (e) => {
        e.preventDefault();
        submitForm();
      });
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.handlers["submit-btn"]["click"].params == ["e"]
      assert String.contains?(result.handlers["submit-btn"]["click"].body, "preventDefault")
    end

    test "extracts multiple handlers for same element" do
      code = """
      document.getElementById('input').addEventListener('focus', function() {
        console.log('focused');
      });
      document.getElementById('input').addEventListener('blur', function() {
        console.log('blurred');
      });
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.handlers == %{
               "input" => %{
                 "focus" => %{params: [], body: "console.log('focused');"},
                 "blur" => %{params: [], body: "console.log('blurred');"}
               }
             }
    end

    test "extracts handlers for multiple elements" do
      code = """
      document.getElementById('btn1').addEventListener('click', () => {
        action1();
      });
      document.getElementById('btn2').addEventListener('click', () => {
        action2();
      });
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert Map.has_key?(result.handlers, "btn1")
      assert Map.has_key?(result.handlers, "btn2")
    end

    test "handler with expression body gets return added" do
      code = """
      document.getElementById('calc').addEventListener('change', (e) => e.target.value * 2);
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      body = result.handlers["calc"]["change"].body
      assert String.starts_with?(body, "return ")
      assert String.contains?(body, "e.target.value * 2")
    end
  end

  describe "parse/1 - DOMContentLoaded unwrapping" do
    test "unwraps single DOMContentLoaded wrapper" do
      code = """
      document.addEventListener('DOMContentLoaded', function() {
        console.log('Ready!');
        initApp();
      });
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      # Content should be unwrapped into init_script
      assert String.contains?(result.init_script, "console.log")
      assert String.contains?(result.init_script, "initApp")
      refute String.contains?(result.init_script, "DOMContentLoaded")
    end

    test "unwraps nested DOMContentLoaded wrappers" do
      code = """
      document.addEventListener('DOMContentLoaded', function() {
        document.addEventListener('DOMContentLoaded', function() {
          console.log('Double wrapped!');
        });
      });
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      # All wrappers should be removed
      assert String.contains?(result.init_script, "console.log")
      refute String.contains?(result.init_script, "DOMContentLoaded")
    end

    test "unwraps DOMContentLoaded with arrow function" do
      code = """
      document.addEventListener('DOMContentLoaded', () => {
        setupHandlers();
      });
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert String.contains?(result.init_script, "setupHandlers")
      refute String.contains?(result.init_script, "DOMContentLoaded")
    end
  end

  describe "parse/1 - init script" do
    test "generates init script from remaining code" do
      code = """
      window.myVar = 10;
      console.log('Init code');
      setupApp();
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      # myVar is extracted, but other code remains
      assert result.variables == %{"myVar" => 10}
      assert String.contains?(result.init_script, "console.log")
      assert String.contains?(result.init_script, "setupApp")
      refute String.contains?(result.init_script, "window.myVar")
    end

    test "init script excludes extracted handlers" do
      code = """
      console.log('Before handler');
      document.getElementById('btn').addEventListener('click', () => {
        alert('clicked');
      });
      console.log('After handler');
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      # Handlers extracted separately
      assert Map.has_key?(result.handlers, "btn")

      # Init script has other code but not the handler
      assert String.contains?(result.init_script, "Before handler")
      assert String.contains?(result.init_script, "After handler")
      refute String.contains?(result.init_script, "addEventListener")
    end

    test "empty init script when all code is extracted" do
      code = """
      window.x = 1;
      window.y = 2;
      window.f = () => {};
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      assert result.init_script == ""
    end
  end

  describe "parse/1 - complex integration" do
    test "parses complete wireframe script" do
      code = """
      window.appState = {"count": 0, "user": null};
      window.presets = [
        {"id": 1, "name": "Default"},
        {"id": 2, "name": "Dark"}
      ];

      window.increment = () => {
        appState.count++;
        updateDisplay();
      };

      window.updateDisplay = function() {
        const display = document.getElementById('counter');
        display.textContent = appState.count;
      };

      document.addEventListener('DOMContentLoaded', function() {
        console.log('App initialized');
        loadPresets();
      });

      document.getElementById('inc-btn').addEventListener('click', function() {
        window.increment();
      });

      document.getElementById('preset-dropdown').addEventListener('change', (e) => {
        applyPreset(e.target.value);
      });

      function loadPresets() {
        const dropdown = document.getElementById('preset-dropdown');
        window.presets.forEach(p => {
          const opt = document.createElement('option');
          opt.value = p.id;
          opt.textContent = p.name;
          dropdown.appendChild(opt);
        });
      }
      """

      assert {:ok, result} = JavaScriptParser.parse(code)

      # Variables extracted
      assert result.variables["appState"] == %{"count" => 0, "user" => nil}
      assert length(result.variables["presets"]) == 2

      # Functions extracted
      assert Map.has_key?(result.functions, "increment")
      assert Map.has_key?(result.functions, "updateDisplay")

      # Handlers extracted
      assert Map.has_key?(result.handlers, "inc-btn")
      assert Map.has_key?(result.handlers, "preset-dropdown")
      assert result.handlers["inc-btn"]["click"].body =~ "window.increment()"

      # Init script has remaining code
      assert String.contains?(result.init_script, "loadPresets")
      assert String.contains?(result.init_script, "console.log('App initialized')")
      # DOMContentLoaded unwrapped
      refute String.contains?(result.init_script, "DOMContentLoaded")
    end
  end

  describe "parse/1 - error handling" do
    test "returns error for invalid JavaScript" do
      code = "this is not valid javascript {{"

      assert {:error, reason} = JavaScriptParser.parse(code)
      assert is_binary(reason)
    end

    test "returns error for empty string" do
      # Empty code should parse successfully but return empty results
      assert {:ok, result} = JavaScriptParser.parse("")

      assert result.variables == %{}
      assert result.functions == %{}
      assert result.handlers == %{}
      assert result.init_script == ""
    end

    test "handles code with syntax errors gracefully" do
      code = "window.x = ;"

      assert {:error, _reason} = JavaScriptParser.parse(code)
    end
  end
end
