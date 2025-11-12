defmodule KoalemosWeb.MessageCards.AssistantCardTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias KoalemosWeb.MessageCards.AssistantCard

  describe "render/1" do
    test "renders assistant message with text" do
      assigns = %{
        message: %{
          content: "I can help you with that.",
          metadata: %{timestamp: 1_234_567_890}
        }
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "koalemos"
      assert html =~ "I can help you with that."
      assert html =~ "border-indigo-400"
    end

    test "renders assistant message with markdown formatting" do
      assigns = %{
        message: %{
          content: "Here's a **bold** statement and some _italic_ text.",
          metadata: %{timestamp: 1_234_567_890}
        }
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
    end

    test "renders assistant message with markdown lists" do
      assigns = %{
        message: %{
          content: "Here are the steps:\n\n1. First step\n2. Second step\n3. Third step",
          metadata: %{timestamp: 1_234_567_890}
        }
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "<ol>"
      assert html =~ "<li>"
      assert html =~ "First step"
    end

    test "renders assistant message with code blocks" do
      assigns = %{
        message: %{
          content: "Here's some code:\n\n```elixir\ndefmodule Test do\nend\n```",
          metadata: %{timestamp: 1_234_567_890}
        }
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "<code"
      assert html =~ "defmodule Test"
    end

    test "generates card_id if not provided" do
      assigns = %{
        message: %{
          content: "Test message",
          metadata: %{timestamp: 1_234_567_890}
        }
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "id=\"card_"
    end

    test "uses provided card_id" do
      assigns = %{
        message: %{
          content: "Test message",
          metadata: %{timestamp: 1_234_567_890}
        },
        card_id: "custom_assistant_id"
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "id=\"custom_assistant_id\""
    end

    test "handles structured content array" do
      assigns = %{
        message: %{
          content: [
            %{type: "text", text: "First part"},
            %{type: "text", text: "Second part"}
          ],
          metadata: %{timestamp: 1_234_567_890}
        }
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "First part"
      assert html =~ "Second part"
    end

    test "handles empty content gracefully" do
      assigns = %{
        message: %{
          content: "",
          metadata: %{timestamp: 1_234_567_890}
        }
      }

      html = render_component(&AssistantCard.render/1, assigns)

      assert html =~ "koalemos"
      # Should still render the card structure
      assert html =~ "border-indigo-400"
    end
  end
end
