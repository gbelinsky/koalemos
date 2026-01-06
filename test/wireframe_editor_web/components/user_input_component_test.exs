defmodule WireframeEditorWeb.UserInputComponentTest do
  use ExUnit.Case, async: true

  alias WireframeEditorWeb.UserInputComponent

  # NOTE: Full component rendering and handle_event tests are difficult because
  # they require complex LiveView setup with uploads, sockets, and form state.
  # These tests focus on the component's pure logic functions instead.
  # The component is visually and functionally tested via the samples page at /samples.

  describe "function get_image_media_type/1" do
    test "returns image media type when valid" do
      assert UserInputComponent.get_image_media_type("image/png") == "image/png"
      assert UserInputComponent.get_image_media_type("image/jpeg") == "image/jpeg"
      assert UserInputComponent.get_image_media_type("image/gif") == "image/gif"
      assert UserInputComponent.get_image_media_type("image/webp") == "image/webp"
    end

    test "returns default jpeg type for invalid media type" do
      assert UserInputComponent.get_image_media_type("invalid") == "image/jpeg"
      assert UserInputComponent.get_image_media_type(nil) == "image/jpeg"
      assert UserInputComponent.get_image_media_type("") == "image/jpeg"
      assert UserInputComponent.get_image_media_type("text/plain") == "image/jpeg"
    end
  end
end
