defmodule Koalemos.Lenses.WireframeEditor.HandlerExtractionTest do
  use ExUnit.Case, async: true

  alias Koalemos.Lenses.WireframeEditor
  alias Koalemos.Integrations.ParsingIntegration

  @fixtures_path "test/fixtures"

  describe "handler extraction from added elements" do
    setup do
      # Load simple wireframe
      html_path = Path.join(@fixtures_path, "wireframe_simple.html")
      {:ok, html} = File.read(html_path)

      # Parse to create initial lens_state
      routine_id = "test-handler-extraction-#{:erlang.unique_integer([:positive])}"
      {:ok, wireframe} = ParsingIntegration.parse_wireframe(html, routine_id)

      lens_state = %{
        designed: %{
          dom_tree: wireframe.dom_tree,
          handlers: wireframe.javascript.handlers,
          custom_css: %{},
          custom_functions: wireframe.javascript.functions,
          custom_variables: wireframe.javascript.variables,
          init_scripts: %{}
        },
        modifications: []
      }

      context = %{
        lens_state: lens_state,
        routine_id: routine_id
      }

      {:ok, context: context, initial_handlers: wireframe.javascript.handlers}
    end

    test "handlers from added elements are extracted to designed.handlers", %{
      context: context,
      initial_handlers: initial_handlers
    } do
      # Add a button with a click handler
      args = %{
        "add_elements" => [
          %{
            "parent_id" => "root",
            "tag" => "button",
            "id" => "new-button",
            "content" => "Click Me",
            "handlers" => %{
              "click" => %{
                "params" => [],
                "body" => "window.handleNewClick()"
              }
            }
          }
        ]
      }

      {result_msg, lens_updates} = WireframeEditor.execute(:modify_elements, args, context)

      # Verify success
      assert result_msg =~ "Successfully modified 1 element"

      # Extract updated lens_state
      updated_designed = Keyword.get(lens_updates, :designed)
      refute is_nil(updated_designed)

      # Verify handlers map was updated
      updated_handlers = Map.get(updated_designed, :handlers, %{})

      # Should have initial handlers PLUS new handler
      assert map_size(updated_handlers) >= map_size(initial_handlers)
      assert Map.has_key?(updated_handlers, "new-button")
      assert updated_handlers["new-button"]["click"][:body] == "window.handleNewClick()"
    end

    test "handlers from nested children are also extracted", %{context: context} do
      # Add a div with nested button that has handler
      args = %{
        "add_elements" => [
          %{
            "parent_id" => "root",
            "tag" => "div",
            "id" => "new-container",
            "children" => [
              %{
                "tag" => "button",
                "id" => "nested-button",
                "content" => "Nested Click",
                "handlers" => %{
                  "click" => %{
                    "params" => [],
                    "body" => "console.log('nested');"
                  }
                }
              }
            ]
          }
        ]
      }

      {result_msg, lens_updates} = WireframeEditor.execute(:modify_elements, args, context)

      # Verify success
      assert result_msg =~ "Successfully modified 1 element"

      # Extract updated lens_state
      updated_designed = Keyword.get(lens_updates, :designed)
      updated_handlers = Map.get(updated_designed, :handlers, %{})

      # Nested handler should be extracted
      assert Map.has_key?(updated_handlers, "nested-button")
      assert updated_handlers["nested-button"]["click"][:body] == "console.log('nested');"
    end

    test "multiple elements with handlers are all extracted", %{context: context} do
      # Add multiple elements with handlers
      args = %{
        "add_elements" => [
          %{
            "parent_id" => "root",
            "tag" => "button",
            "id" => "btn-1",
            "handlers" => %{"click" => %{"params" => [], "body" => "alert('1');"}}
          },
          %{
            "parent_id" => "root",
            "tag" => "button",
            "id" => "btn-2",
            "handlers" => %{"click" => %{"params" => [], "body" => "alert('2');"}}
          }
        ]
      }

      {result_msg, lens_updates} = WireframeEditor.execute(:modify_elements, args, context)

      # Verify success
      assert result_msg =~ "Successfully modified 2 element"

      # Extract updated lens_state
      updated_designed = Keyword.get(lens_updates, :designed)
      updated_handlers = Map.get(updated_designed, :handlers, %{})

      # Both handlers should be present
      assert Map.has_key?(updated_handlers, "btn-1")
      assert Map.has_key?(updated_handlers, "btn-2")
      assert updated_handlers["btn-1"]["click"][:body] == "alert('1');"
      assert updated_handlers["btn-2"]["click"][:body] == "alert('2');"
    end

    test "replaced elements with handlers update the handlers map", %{context: context} do
      # First, add an element
      add_args = %{
        "add_elements" => [
          %{
            "parent_id" => "root",
            "tag" => "button",
            "id" => "replace-me",
            "handlers" => %{"click" => %{"params" => [], "body" => "alert('old');"}}
          }
        ]
      }

      {_, lens_updates} = WireframeEditor.execute(:modify_elements, add_args, context)

      updated_context = %{
        context
        | lens_state: %{context.lens_state | designed: Keyword.get(lens_updates, :designed)}
      }

      # Now replace it with new handler
      replace_args = %{
        "replace_elements" => [
          %{
            "element_id" => "replace-me",
            "new_element" => %{
              "tag" => "button",
              "id" => "replace-me",
              "handlers" => %{"click" => %{"params" => [], "body" => "alert('new');"}}
            }
          }
        ]
      }

      {result_msg, lens_updates2} =
        WireframeEditor.execute(:modify_elements, replace_args, updated_context)

      # Verify success
      assert result_msg =~ "Successfully modified 1 element"

      # Extract final lens_state
      final_designed = Keyword.get(lens_updates2, :designed)
      final_handlers = Map.get(final_designed, :handlers, %{})

      # Handler should be updated to new version
      assert final_handlers["replace-me"]["click"][:body] == "alert('new');"
    end

    test "handlers are normalized to atom keys for consistent formatting", %{context: context} do
      # Add element with string-keyed handlers (as agent sends them)
      args = %{
        "add_elements" => [
          %{
            "parent_id" => "root",
            "tag" => "button",
            "id" => "test-btn",
            "handlers" => %{
              "click" => %{
                "params" => [],
                "body" => "alert('test');"
              }
            }
          }
        ]
      }

      {_result_msg, lens_updates} = WireframeEditor.execute(:modify_elements, args, context)

      # Extract updated lens_state
      updated_designed = Keyword.get(lens_updates, :designed)
      updated_handlers = Map.get(updated_designed, :handlers, %{})

      # Handler should have atom keys (:params, :body) not string keys
      handler_info = updated_handlers["test-btn"]["click"]
      assert is_map(handler_info)
      assert Map.has_key?(handler_info, :params)
      assert Map.has_key?(handler_info, :body)
      refute Map.has_key?(handler_info, "params")
      refute Map.has_key?(handler_info, "body")
      assert handler_info[:body] == "alert('test');"
    end
  end
end
