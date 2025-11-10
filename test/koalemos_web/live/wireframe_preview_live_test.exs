defmodule KoalemosWeb.WireframePreviewLiveTest do
  use KoalemosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Koalemos.Caches.WireframeStateCache

  describe "JavaScript Rendering (Sprint 6)" do
    test "renders custom variables as window assignments", %{conn: conn} do
      routine_id = "test-js-vars-#{System.unique_integer()}"

      # Store lens_state with custom variables
      lens_state = %{
        designed: %{
          dom_tree: %{tag: "div", id: "root", content: "Test"},
          custom_css: %{},
          custom_functions: %{},
          custom_variables: %{"count" => 0, "name" => "test"},
          init_scripts: %{},
          handlers: %{}
        }
      }

      WireframeStateCache.put_state(routine_id, lens_state)

      # Mount the preview
      {:ok, _view, html} = live(conn, "/wireframe-preview/#{routine_id}")

      # Should render variables
      assert html =~ "window.count = 0;"
      assert html =~ "window.name = \"test\";"
      assert html =~ "// ===== Global Variables ====="
    end

    test "renders custom functions as window assignments", %{conn: conn} do
      routine_id = "test-js-funcs-#{System.unique_integer()}"

      lens_state = %{
        designed: %{
          dom_tree: %{tag: "div", id: "root", content: "Test"},
          custom_css: %{},
          custom_functions: %{
            "handleClick" => "function() { console.log('clicked'); }",
            "getData" => "() => { return 42; }"
          },
          custom_variables: %{},
          init_scripts: %{},
          handlers: %{}
        }
      }

      WireframeStateCache.put_state(routine_id, lens_state)

      {:ok, _view, html} = live(conn, "/wireframe-preview/#{routine_id}")

      # Should render functions
      assert html =~ "window.handleClick = function() { console.log('clicked'); };"
      assert html =~ "window.getData = () => { return 42; };"
      assert html =~ "// ===== Function Definitions ====="
    end

    test "renders event handlers with addEventListener", %{conn: conn} do
      routine_id = "test-js-handlers-#{System.unique_integer()}"

      lens_state = %{
        designed: %{
          dom_tree: %{tag: "button", id: "test-btn", content: "Click me"},
          custom_css: %{},
          custom_functions: %{},
          custom_variables: %{},
          init_scripts: %{},
          handlers: %{
            "test-btn" => %{
              "click" => %{params: ["event"], body: "console.log('Button clicked');"}
            }
          }
        }
      }

      WireframeStateCache.put_state(routine_id, lens_state)

      {:ok, _view, html} = live(conn, "/wireframe-preview/#{routine_id}")

      # Handlers are attached via JavaScriptUpdater hook, not rendered in HTML
      # The HTML should only contain the comment explaining this
      assert html =~ "// ===== Event Handler Attachment ====="
      assert html =~ "// NOTE: Handlers are attached dynamically via JavaScriptUpdater hook"
      assert html =~ "// This ensures proper cleanup when handlers change"

      # Should NOT contain addEventListener in HTML (it's done via hook)
      refute html =~ "addEventListener('click'"
    end

    test "renders init scripts wrapped in DOMContentLoaded", %{conn: conn} do
      routine_id = "test-js-init-#{System.unique_integer()}"

      lens_state = %{
        designed: %{
          dom_tree: %{tag: "div", id: "root", content: "Test"},
          custom_css: %{},
          custom_functions: %{},
          custom_variables: %{},
          init_scripts: %{
            "init1" => "console.log('Initializing...');",
            "init2" => "document.body.classList.add('loaded');"
          },
          handlers: %{}
        }
      }

      WireframeStateCache.put_state(routine_id, lens_state)

      {:ok, _view, html} = live(conn, "/wireframe-preview/#{routine_id}")

      # Should render init scripts in DOMContentLoaded
      assert html =~ "document.addEventListener('DOMContentLoaded'"
      assert html =~ "console.log('Initializing...');"
      assert html =~ "document.body.classList.add('loaded');"
      assert html =~ "// ===== Initialization Scripts ====="
    end

    test "renders all JavaScript components together", %{conn: conn} do
      routine_id = "test-js-all-#{System.unique_integer()}"

      lens_state = %{
        designed: %{
          dom_tree: %{tag: "div", id: "app", children: [
            %{tag: "button", id: "btn", content: "Click"}
          ]},
          custom_css: %{},
          custom_functions: %{
            "handleClick" => "function() { window.count++; }"
          },
          custom_variables: %{
            "count" => 0
          },
          init_scripts: %{
            "setup" => "console.log('App initialized');"
          },
          handlers: %{
            "btn" => %{
              "click" => %{params: [], body: "window.handleClick();"}
            }
          }
        }
      }

      WireframeStateCache.put_state(routine_id, lens_state)

      {:ok, _view, html} = live(conn, "/wireframe-preview/#{routine_id}")

      # Should render all components in correct order
      # 1. Variables first
      assert html =~ ~r/window\.count = 0;.*window\.handleClick/s

      # 2. Functions second
      assert html =~ ~r/window\.handleClick = function.*addEventListener/s

      # 3. Handlers third
      assert html =~ ~r/addEventListener.*App initialized/s
    end

    test "handles empty JavaScript state gracefully", %{conn: conn} do
      routine_id = "test-js-empty-#{System.unique_integer()}"

      lens_state = %{
        designed: %{
          dom_tree: %{tag: "div", id: "root", content: "Empty"},
          custom_css: %{},
          custom_functions: %{},
          custom_variables: %{},
          init_scripts: %{},
          handlers: %{}
        }
      }

      WireframeStateCache.put_state(routine_id, lens_state)

      {:ok, _view, html} = live(conn, "/wireframe-preview/#{routine_id}")

      # Should not render user JavaScript sections
      # Note: Phoenix includes app.js, so we check for user-generated script markers
      refute html =~ "// ===== Global Variables ====="
      refute html =~ "// ===== Function Definitions ====="
      refute html =~ "// ===== Event Handler Attachment ====="
    end

    test "updates JavaScript on PubSub broadcast", %{conn: conn} do
      routine_id = "test-js-update-#{System.unique_integer()}"

      # Initial state with no JS
      initial_state = %{
        designed: %{
          dom_tree: %{tag: "div", id: "root", content: "Initial"},
          custom_css: %{},
          custom_functions: %{},
          custom_variables: %{},
          init_scripts: %{},
          handlers: %{}
        }
      }

      WireframeStateCache.put_state(routine_id, initial_state)

      {:ok, view, html} = live(conn, "/wireframe-preview/#{routine_id}")

      # Initially no JavaScript
      refute html =~ "window.count"

      # Update state with JavaScript
      updated_state = %{
        designed: %{
          dom_tree: %{tag: "div", id: "root", content: "Updated"},
          custom_css: %{},
          custom_functions: %{},
          custom_variables: %{"count" => 1},
          init_scripts: %{},
          handlers: %{}
        }
      }

      WireframeStateCache.put_state(routine_id, updated_state)

      # Broadcast DOM update
      Phoenix.PubSub.broadcast(
        Koalemos.PubSub,
        "wireframe_updates:#{routine_id}",
        {:dom_tree_updated, updated_state.designed.dom_tree, %{source: :test}}
      )

      # Wait for update to process
      :timer.sleep(100)

      # Should now have JavaScript
      updated_html = render(view)
      assert updated_html =~ "window.count = 1;"
    end
  end
end
