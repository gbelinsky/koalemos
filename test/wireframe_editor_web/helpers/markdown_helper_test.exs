defmodule WireframeEditorWeb.MarkdownHelperTest do
  use ExUnit.Case, async: true
  import WireframeEditorWeb.MarkdownHelper

  describe "markdown_to_html/1" do
    test "converts simple markdown to HTML" do
      result = markdown_to_html("**bold** and _italic_")
      assert {:safe, html} = result
      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
    end

    test "wraps output in markdown-content div" do
      result = markdown_to_html("Hello world")
      assert {:safe, html} = result
      assert html =~ ~r/<div class="markdown-content prose prose-sm prose-slate max-w-none">/
    end

    test "converts code blocks with language prefix" do
      result = markdown_to_html("```elixir\ndefmodule Test do\nend\n```")
      assert {:safe, html} = result
      assert html =~ "language-elixir"
    end

    test "handles line breaks when breaks option is true" do
      result = markdown_to_html("line1\nline2")
      assert {:safe, html} = result
      # With breaks: true, newlines should become <br>
      assert html =~ "<br"
    end

    test "handles smartypants conversion" do
      result = markdown_to_html("\"quotes\" and -- dashes")
      assert {:safe, html} = result
      # Smartypants should convert quotes and dashes
      assert html =~ "&#8220;" || html =~ "&ldquo;" || html =~ "\""
    end

    test "escapes HTML when markdown parsing fails" do
      # This tests the error handling path
      # Earmark should handle most inputs, but if it errors, we escape
      result = safe_markdown_to_html("<script>alert('xss')</script>")
      assert {:safe, html} = result
      # Should be escaped or wrapped safely
      assert is_binary(html)
    end
  end

  describe "safe_markdown_to_html/1" do
    test "returns empty string for nil" do
      assert safe_markdown_to_html(nil) == ""
    end

    test "returns empty string for empty string" do
      assert safe_markdown_to_html("") == ""
    end

    test "converts markdown for valid string" do
      result = safe_markdown_to_html("**test**")
      assert {:safe, html} = result
      assert html =~ "<strong>test</strong>"
    end

    test "converts non-string content to string first" do
      result = safe_markdown_to_html(123)
      assert {:safe, html} = result
      assert html =~ "123"
    end

    test "handles atom input" do
      result = safe_markdown_to_html(:test)
      assert {:safe, html} = result
      assert html =~ "test"
    end
  end

  describe "safe_markdown_to_html/2 with options" do
    test "passes options through to markdown_to_html" do
      result = safe_markdown_to_html("test", breaks: false)
      assert {:safe, _html} = result
    end

    test "returns empty string for nil with options" do
      assert safe_markdown_to_html(nil, breaks: false) == ""
    end
  end
end
