defmodule Koalemos.Parsers.HTMLParserTest do
  use ExUnit.Case, async: true

  alias Koalemos.Parsers.HTMLParser

  describe "parse_html/1" do
    test "parses simple HTML with single element" do
      html = "<div>Hello World</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.tag == "div"
      assert result.dom_tree.content == "Hello World"
      assert result.dom_tree.children == []
    end

    test "parses nested HTML structure" do
      html = """
      <div>
        <h1>Title</h1>
        <p>Paragraph</p>
      </div>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.tag == "div"
      assert length(result.dom_tree.children) == 2

      [h1, p] = result.dom_tree.children
      assert h1.tag == "h1"
      assert h1.content == "Title"
      assert p.tag == "p"
      assert p.content == "Paragraph"
    end

    test "handles deeply nested structures" do
      html = """
      <div>
        <section>
          <article>
            <h1>Nested Title</h1>
          </article>
        </section>
      </div>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      div_node = result.dom_tree
      assert div_node.tag == "div"
      assert length(div_node.children) == 1

      section = hd(div_node.children)
      assert section.tag == "section"

      article = hd(section.children)
      assert article.tag == "article"

      h1 = hd(article.children)
      assert h1.tag == "h1"
      assert h1.content == "Nested Title"
    end

    test "wraps multiple root nodes in container div" do
      html = """
      <h1>First</h1>
      <p>Second</p>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.tag == "div"
      assert result.dom_tree.id == "root"
      assert length(result.dom_tree.children) == 2
    end
  end

  describe "ID generation" do
    test "generates auto IDs for elements without IDs" do
      html = """
      <div>
        <button>Click</button>
        <button>Click Again</button>
      </div>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      # Root div gets auto ID
      assert String.starts_with?(result.dom_tree.id, "auto-div-")

      # Buttons get sequential auto IDs
      [btn1, btn2] = result.dom_tree.children
      assert String.starts_with?(btn1.id, "auto-button-")
      assert String.starts_with?(btn2.id, "auto-button-")
      assert btn1.id != btn2.id
    end

    test "preserves existing IDs" do
      html = """
      <div id="main">
        <button id="submit-btn">Submit</button>
      </div>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.id == "main"
      button = hd(result.dom_tree.children)
      assert button.id == "submit-btn"
    end

    test "handles duplicate IDs by making them unique" do
      html = """
      <div id="duplicate">
        <span id="duplicate">Content</span>
      </div>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      # First gets the ID, second gets -1 suffix
      assert result.dom_tree.id == "duplicate"
      span = hd(result.dom_tree.children)
      assert span.id == "duplicate-1"
    end
  end

  describe "classes and attributes" do
    test "extracts CSS classes" do
      html = "<div class='container main-content active'>Text</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.classes == ["container", "main-content", "active"]
    end

    test "extracts arbitrary attributes" do
      html = "<input type='text' placeholder='Enter name' required data-test='input-field'>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      attrs = result.dom_tree.attributes
      assert attrs["type"] == "text"
      assert attrs["placeholder"] == "Enter name"
      assert attrs["required"] == "required"
      assert attrs["data-test"] == "input-field"
    end

    test "handles elements with no classes or attributes" do
      html = "<div>Plain</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.classes == []
      assert result.dom_tree.attributes == %{}
    end
  end

  describe "inline styles" do
    test "parses inline style attribute" do
      html = "<div style='color: blue; font-size: 16px; margin: 10px 20px;'>Styled</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      styles = result.dom_tree.styles
      assert styles["color"] == "blue"
      assert styles["font-size"] == "16px"
      assert styles["margin"] == "10px 20px"
    end

    test "handles empty style attribute" do
      html = "<div style=''>Content</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.styles == %{}
    end

    test "handles elements without styles" do
      html = "<div>No styles</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.styles == %{}
    end
  end

  describe "text content" do
    test "extracts text content from leaf nodes" do
      html = "<p>This is a paragraph with some text.</p>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.content == "This is a paragraph with some text."
      assert result.dom_tree.children == []
    end

    test "trims whitespace from text content" do
      html = "<div>  \n  Trimmed Text  \n  </div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.content == "Trimmed Text"
    end

    test "nodes with children have nil content" do
      html = "<div><span>Child</span></div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.content == nil
      assert length(result.dom_tree.children) == 1
    end

    test "handles empty elements" do
      html = "<div></div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.dom_tree.content == nil
      assert result.dom_tree.children == []
    end
  end

  describe "style element extraction" do
    test "extracts inline <style> tags" do
      html = """
      <html>
      <head>
        <style>
          .button { color: blue; }
          .container { margin: 20px; }
        </style>
      </head>
      <body>
        <div>Content</div>
      </body>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert length(result.style_elements) == 1
      [style] = result.style_elements

      assert style.type == :inline
      assert String.contains?(style.content, ".button { color: blue; }")
      assert String.contains?(style.content, ".container { margin: 20px; }")
    end

    test "extracts external <link> stylesheets" do
      html = """
      <html>
      <head>
        <link rel="stylesheet" href="/css/main.css">
        <link rel="stylesheet" href="https://cdn.example.com/style.css">
      </head>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      link_styles = Enum.filter(result.style_elements, fn s -> s.type == :external end)
      assert length(link_styles) == 2

      [link1, link2] = link_styles
      assert link1.src == "/css/main.css"
      assert link2.src == "https://cdn.example.com/style.css"
    end

    test "extracts both inline and external styles" do
      html = """
      <html>
      <head>
        <link rel="stylesheet" href="/main.css">
        <style>.button { color: red; }</style>
      </head>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert length(result.style_elements) == 2

      inline = Enum.find(result.style_elements, fn s -> s.type == :inline end)
      external = Enum.find(result.style_elements, fn s -> s.type == :external end)

      assert inline != nil
      assert external != nil
    end

    test "returns empty list when no styles present" do
      html = "<div>No styles</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.style_elements == []
    end
  end

  describe "script element extraction" do
    test "extracts inline <script> tags" do
      html = """
      <html>
      <body>
        <script>
          window.myFunc = () => {
            console.log("Hello");
          };
        </script>
      </body>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert length(result.script_elements) == 1
      [script] = result.script_elements

      assert script.type == :inline
      assert String.contains?(script.content, "window.myFunc")
      assert String.contains?(script.content, "console.log")
    end

    test "extracts external <script> tags" do
      html = """
      <html>
      <head>
        <script src="/js/app.js"></script>
        <script src="https://cdn.example.com/library.js"></script>
      </head>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert length(result.script_elements) == 2

      [script1, script2] = result.script_elements
      assert script1.type == :external
      assert script1.src == "/js/app.js"
      assert script2.type == :external
      assert script2.src == "https://cdn.example.com/library.js"
    end

    test "extracts both inline and external scripts" do
      html = """
      <html>
      <head>
        <script src="/library.js"></script>
      </head>
      <body>
        <script>console.log("inline");</script>
      </body>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert length(result.script_elements) == 2

      inline = Enum.find(result.script_elements, fn s -> s.type == :inline end)
      external = Enum.find(result.script_elements, fn s -> s.type == :external end)

      assert inline != nil
      assert external != nil
    end

    test "returns empty list when no scripts present" do
      html = "<div>No scripts</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.script_elements == []
    end
  end

  describe "metadata extraction" do
    test "extracts page title" do
      html = """
      <html>
      <head>
        <title>My Wireframe Page</title>
      </head>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.metadata.title == "My Wireframe Page"
    end

    test "extracts meta tags" do
      html = """
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="description" content="A test page">
      </head>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      meta_tags = result.metadata.meta_tags
      assert length(meta_tags) == 3

      # Check that we got all the meta tags
      charset = Enum.find(meta_tags, fn m -> Map.get(m, "charset") end)
      viewport = Enum.find(meta_tags, fn m -> Map.get(m, "name") == "viewport" end)
      description = Enum.find(meta_tags, fn m -> Map.get(m, "name") == "description" end)

      assert charset["charset"] == "UTF-8"
      assert viewport["content"] == "width=device-width, initial-scale=1.0"
      assert description["content"] == "A test page"
    end

    test "returns nil title when not present" do
      html = "<div>No title</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.metadata.title == nil
    end

    test "returns empty meta_tags when none present" do
      html = "<div>No meta tags</div>"
      assert {:ok, result} = HTMLParser.parse_html(html)

      assert result.metadata.meta_tags == []
    end
  end

  describe "parse_file/1" do
    setup do
      # Create a temp file for testing
      temp_file = Path.join(System.tmp_dir!(), "test_wireframe_#{:rand.uniform(10000)}.html")

      html_content = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test File</title>
      </head>
      <body>
        <div id="main">
          <h1>Hello from file</h1>
        </div>
      </body>
      </html>
      """

      File.write!(temp_file, html_content)

      on_exit(fn -> File.rm(temp_file) end)

      {:ok, temp_file: temp_file}
    end

    test "parses HTML from file", %{temp_file: temp_file} do
      assert {:ok, result} = HTMLParser.parse_file(temp_file)

      assert result.metadata.title == "Test File"
      # Body content is extracted as dom_tree, so main div should be in there
      main_div =
        Enum.find(result.dom_tree.children, fn node ->
          Map.get(node, :id) == "main"
        end) || result.dom_tree

      # Check if main_div is the root (single child case) or in children
      if result.dom_tree.id == "main" do
        assert result.dom_tree.tag == "div"
      else
        assert main_div != nil
        assert main_div.tag == "div"
      end
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = HTMLParser.parse_file("/non/existent/file.html")
    end
  end

  describe "complex wireframe parsing" do
    test "parses complete wireframe with all features" do
      html = """
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Complete Wireframe</title>
        <link rel="stylesheet" href="/css/main.css">
        <style>
          .container { max-width: 1200px; }
        </style>
        <script src="/js/vendor.js"></script>
      </head>
      <body>
        <div id="app" class="container main">
          <header>
            <h1>My Application</h1>
            <nav>
              <button id="menu-btn" class="btn primary" style="color: blue;">Menu</button>
            </nav>
          </header>
          <main>
            <section id="content">
              <article>
                <h2>Article Title</h2>
                <p>Article content goes here.</p>
              </article>
            </section>
          </main>
          <footer>
            <p>&copy; 2024</p>
          </footer>
        </div>
        <script>
          window.initApp = () => {
            console.log("App initialized");
          };
        </script>
      </body>
      </html>
      """

      assert {:ok, result} = HTMLParser.parse_html(html)

      # Check metadata
      assert result.metadata.title == "Complete Wireframe"
      assert length(result.metadata.meta_tags) == 2

      # Check styles
      assert length(result.style_elements) == 2
      inline_style = Enum.find(result.style_elements, fn s -> s.type == :inline end)
      external_style = Enum.find(result.style_elements, fn s -> s.type == :external end)
      assert inline_style != nil
      assert external_style != nil

      # Check scripts
      assert length(result.script_elements) == 2
      inline_script = Enum.find(result.script_elements, fn s -> s.type == :inline end)
      external_script = Enum.find(result.script_elements, fn s -> s.type == :external end)
      assert inline_script != nil
      assert external_script != nil

      # Check DOM structure - body content is extracted as dom_tree
      # Find the app div (might be root or in children)
      app_div =
        if result.dom_tree.id == "app" do
          result.dom_tree
        else
          Enum.find(result.dom_tree.children, fn node -> node.id == "app" end)
        end

      assert app_div != nil
      assert app_div.id == "app"
      assert app_div.classes == ["container", "main"]

      # Check nested structure
      header = Enum.find(app_div.children, fn node -> node.tag == "header" end)
      assert header != nil

      # Find button with inline style
      nav = Enum.find(header.children, fn node -> node.tag == "nav" end)
      button = hd(nav.children)
      assert button.id == "menu-btn"
      assert button.classes == ["btn", "primary"]
      assert button.styles["color"] == "blue"
    end
  end
end
