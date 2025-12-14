defmodule WireframeEditorWeb.Parsers.CSSParserTest do
  use ExUnit.Case, async: true
  alias WireframeEditorWeb.Parsers.CSSParser

  describe "parse/1" do
    test "parses simple CSS rule" do
      css = ".button { padding: 20px; }"

      assert {:ok, result} = CSSParser.parse(css)
      assert map_size(result.rules) == 1
      assert result.rules[".button"]["padding"] == "20px"
    end

    test "parses multiple declarations" do
      css = """
      .card {
        padding: 20px;
        margin: 10px;
        background-color: white;
      }
      """

      assert {:ok, result} = CSSParser.parse(css)
      assert map_size(result.rules) == 1

      declarations = result.rules[".card"]
      assert declarations["padding"] == "20px"
      assert declarations["margin"] == "10px"
      assert declarations["background-color"] == "white"
    end

    test "parses multiple rules" do
      css = """
      .button { padding: 20px; }
      .card { margin: 10px; }
      """

      assert {:ok, result} = CSSParser.parse(css)
      assert map_size(result.rules) == 2

      assert result.rules[".button"]["padding"] == "20px"
      assert result.rules[".card"]["margin"] == "10px"
    end

    test "parses multiple selectors" do
      css = "h1, h2, h3 { color: blue; }"

      assert {:ok, result} = CSSParser.parse(css)
      assert map_size(result.rules) == 1
      assert result.rules["h1, h2, h3"]["color"] == "blue"
    end

    test "parses ID selectors" do
      css = "#header { height: 60px; }"

      assert {:ok, result} = CSSParser.parse(css)
      assert result.rules["#header"]["height"] == "60px"
    end

    test "parses element selectors" do
      css = "body { font-family: Arial; }"

      assert {:ok, result} = CSSParser.parse(css)
      assert result.rules["body"]["font-family"] == "Arial"
    end

    test "parses descendant selectors" do
      css = "div p { line-height: 1.5; }"

      assert {:ok, result} = CSSParser.parse(css)
      assert result.rules["div p"]["line-height"] == "1.5"
    end

    test "parses child selectors" do
      css = "ul > li { list-style: none; }"

      assert {:ok, result} = CSSParser.parse(css)
      assert result.rules["ul > li"]["list-style"] == "none"
    end

    test "parses pseudo-classes" do
      css = "a:hover { color: red; }"

      assert {:ok, result} = CSSParser.parse(css)
      assert result.rules["a:hover"]["color"] == "red"
    end

    test "parses attribute selectors" do
      css = "input[type=\"text\"] { border: 1px solid gray; }"

      assert {:ok, result} = CSSParser.parse(css)
      # Find the selector that contains "input"
      {selector, declarations} = Enum.find(result.rules, fn {k, _v} -> k =~ "input" end)
      assert selector =~ "input"
      assert declarations["border"] =~ "1px solid gray"
    end

    test "parses complex values" do
      css = """
      .box {
        border: 1px solid rgba(0, 0, 0, 0.1);
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
      }
      """

      assert {:ok, result} = CSSParser.parse(css)
      declarations = result.rules[".box"]
      assert declarations["border"] =~ "1px solid rgba"
      assert declarations["box-shadow"] =~ "0 2px 4px rgba"
    end

    test "parses empty CSS" do
      css = ""

      assert {:ok, result} = CSSParser.parse(css)
      assert result.rules == %{}
    end

    test "parses CSS with comments" do
      css = """
      /* This is a comment */
      .button {
        /* Another comment */
        padding: 20px;
      }
      """

      assert {:ok, result} = CSSParser.parse(css)
      assert map_size(result.rules) == 1
      assert result.rules[".button"]["padding"] == "20px"
    end

    test "handles invalid CSS" do
      css = "invalid {{{ css"

      assert {:error, reason} = CSSParser.parse(css)
      assert reason =~ "CSS parsing failed"
    end

    test "parses complete wireframe CSS" do
      css = """
      .counter-app {
        padding: 20px;
        background: #f5f5f5;
      }

      button {
        margin: 5px;
        padding: 10px 20px;
        background-color: blue;
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
      }

      button:hover {
        background-color: darkblue;
      }

      #display {
        font-size: 24px;
        font-weight: bold;
      }
      """

      assert {:ok, result} = CSSParser.parse(css)
      assert map_size(result.rules) == 4

      assert result.rules[".counter-app"]["padding"] == "20px"
      assert result.rules["button"]["margin"] == "5px"
      assert result.rules["button:hover"]["background-color"] == "darkblue"
      assert result.rules["#display"]["font-size"] == "24px"
    end

    test "ignores at-rules for MVP" do
      css = """
      @media (max-width: 600px) {
        .button { padding: 10px; }
      }

      .button { padding: 20px; }
      """

      # Should only parse the regular rule, not the @media
      assert {:ok, result} = CSSParser.parse(css)

      # The .button rule outside @media should be present
      assert result.rules[".button"]["padding"] == "20px"
    end
  end
end
