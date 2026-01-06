defmodule WireframeEditorWeb.MessageCards.ErrorCardTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias WireframeEditorWeb.MessageCards.ErrorCard

  describe "render/1" do
    test "renders error message" do
      assigns = %{
        error_message: "Something went wrong"
      }

      html = render_component(&ErrorCard.render/1, assigns)

      assert html =~ "unfortunate"
      assert html =~ "Something went wrong"
      assert html =~ "border-red-400"
      assert html =~ "bg-gradient-to-br"
    end

    test "displays error icon" do
      assigns = %{
        error_message: "Test error"
      }

      html = render_component(&ErrorCard.render/1, assigns)

      assert html =~ "⚠"
    end

    test "has role=alert for accessibility" do
      assigns = %{
        error_message: "Test error"
      }

      html = render_component(&ErrorCard.render/1, assigns)

      assert html =~ "role=\"alert\""
    end

    test "generates card_id from error message if not provided" do
      assigns = %{
        error_message: "Unique error"
      }

      html = render_component(&ErrorCard.render/1, assigns)

      assert html =~ "id=\"error_"
    end

    test "uses provided card_id" do
      assigns = %{
        error_message: "Test error",
        card_id: "custom_error_id"
      }

      html = render_component(&ErrorCard.render/1, assigns)

      assert html =~ "id=\"custom_error_id\""
    end

    test "handles multi-line error messages" do
      assigns = %{
        error_message: "Error on line 1\nError on line 2"
      }

      html = render_component(&ErrorCard.render/1, assigns)

      assert html =~ "Error on line 1"
      assert html =~ "Error on line 2"
    end

    test "handles long error messages" do
      long_message = String.duplicate("Error ", 100)

      assigns = %{
        error_message: long_message
      }

      html = render_component(&ErrorCard.render/1, assigns)

      assert html =~ long_message
    end

    test "handles empty error message" do
      assigns = %{
        error_message: ""
      }

      html = render_component(&ErrorCard.render/1, assigns)

      # Should still render the card structure
      assert html =~ "unfortunate"
      assert html =~ "border-red-400"
    end
  end
end
