defmodule KoalemosWeb.MessageCards.UserCardTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias KoalemosWeb.MessageCards.UserCard

  describe "render/1" do
    test "renders user message with text only" do
      assigns = %{
        message: %{
          content: "Hello world",
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: MapSet.new()
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "you"
      assert html =~ "Hello world"
      assert html =~ "border-blue-400"
    end

    test "renders user message with markdown formatting" do
      assigns = %{
        message: %{
          content: "**Bold** and _italic_",
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: MapSet.new()
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "<strong>Bold</strong>"
      assert html =~ "<em>italic</em>"
    end

    test "renders user message with images collapsed" do
      assigns = %{
        message: %{
          content: [
            %{type: "text", text: "Check this out"},
            %{type: "image", source: %{data: "abc123", media_type: "image/png"}}
          ],
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: MapSet.new()
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "Check this out"
      assert html =~ "data:image/png;base64,abc123"
      # Thumbnail size
      assert html =~ "h-12"
    end

    test "renders user message with images expanded" do
      card_id = "card_1234567890"
      expanded_set = MapSet.new([card_id])

      assigns = %{
        message: %{
          content: [
            %{type: "text", text: "Check this out"},
            %{type: "image", source: %{data: "abc123", media_type: "image/png"}}
          ],
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: expanded_set,
        card_id: card_id
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "Check this out"
      assert html =~ "data:image/png;base64,abc123"
      # Full width for expanded
      assert html =~ "w-full"
      assert html =~ "collapse_image"
      # Collapse button
      assert html =~ "▲"
    end

    test "generates card_id if not provided" do
      assigns = %{
        message: %{
          content: "Test",
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: MapSet.new()
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "id=\"card_"
    end

    test "uses provided card_id" do
      assigns = %{
        message: %{
          content: "Test",
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: MapSet.new(),
        card_id: "custom_id"
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "id=\"custom_id\""
    end

    test "handles empty text content" do
      assigns = %{
        message: %{
          content: [
            %{type: "image", source: %{data: "abc123", media_type: "image/png"}}
          ],
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: MapSet.new()
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "you"
      assert html =~ "data:image/png;base64,abc123"
      refute html =~ ~r/<div class="text-gray-700.*?>.*?<\/div>/
    end

    test "renders expand button when images present and not expanded" do
      assigns = %{
        message: %{
          content: [
            %{type: "text", text: "Text"},
            %{type: "image", source: %{data: "abc", media_type: "image/png"}}
          ],
          metadata: %{timestamp: 1_234_567_890}
        },
        expanded_images: MapSet.new()
      }

      html = render_component(&UserCard.render/1, assigns)

      assert html =~ "phx-click=\"expand_image\""
    end
  end
end
