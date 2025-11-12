defmodule KoalemosWeb.MessageCards.ImageGalleryTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias KoalemosWeb.MessageCards.ImageGallery

  describe "render/1" do
    test "renders collapsed state with thumbnails" do
      assigns = %{
        images: [
          %{type: "image", source: %{data: "abc123", media_type: "image/png"}},
          %{type: "image", source: %{data: "def456", media_type: "image/jpeg"}}
        ],
        card_id: "test_card",
        expanded: false,
        on_expand: "expand_image",
        on_collapse: "collapse_image"
      }

      html = render_component(&ImageGallery.render/1, assigns)

      assert html =~ "data:image/png;base64,abc123"
      assert html =~ "data:image/jpeg;base64,def456"
      assert html =~ "phx-click=\"expand_image\""
      assert html =~ "phx-value-card=\"test_card\""
    end

    test "renders expanded state with full-size images" do
      assigns = %{
        images: [
          %{type: "image", source: %{data: "abc123", media_type: "image/png"}}
        ],
        card_id: "test_card",
        expanded: true,
        on_expand: "expand_image",
        on_collapse: "collapse_image"
      }

      html = render_component(&ImageGallery.render/1, assigns)

      assert html =~ "data:image/png;base64,abc123"
      assert html =~ "w-full"
      refute html =~ "phx-click=\"expand_image\""
    end

    test "shows +N more indicator for many images in collapsed state" do
      images =
        for i <- 1..5 do
          %{type: "image", source: %{data: "data#{i}", media_type: "image/png"}}
        end

      assigns = %{
        images: images,
        card_id: "test_card",
        expanded: false,
        on_expand: "expand_image",
        on_collapse: "collapse_image"
      }

      html = render_component(&ImageGallery.render/1, assigns)

      assert html =~ "+2 more"
    end

    test "handles string keys in image data" do
      assigns = %{
        images: [
          %{"type" => "image", "source" => %{"data" => "abc123", "media_type" => "image/png"}}
        ],
        card_id: "test_card",
        expanded: false,
        on_expand: "expand_image",
        on_collapse: "collapse_image"
      }

      html = render_component(&ImageGallery.render/1, assigns)

      assert html =~ "data:image/png;base64,abc123"
    end

    test "defaults to image/png when media_type missing" do
      assigns = %{
        images: [
          %{type: "image", source: %{data: "abc123"}}
        ],
        card_id: "test_card",
        expanded: false,
        on_expand: "expand_image",
        on_collapse: "collapse_image"
      }

      html = render_component(&ImageGallery.render/1, assigns)

      assert html =~ "data:image/png;base64,abc123"
    end

    test "handles empty images list" do
      assigns = %{
        images: [],
        card_id: "test_card",
        expanded: false,
        on_expand: "expand_image",
        on_collapse: "collapse_image"
      }

      html = render_component(&ImageGallery.render/1, assigns)

      refute html =~ "data:image"
    end
  end
end
