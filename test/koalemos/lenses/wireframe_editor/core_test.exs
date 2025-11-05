defmodule Koalemos.Lenses.WireframeEditorTest do
  use ExUnit.Case, async: true

  alias Koalemos.Lenses.WireframeEditor

  describe "tools/0" do
    test "returns 9 wireframe editing tools" do
      tools = WireframeEditor.tools()

      assert length(tools) == 9

      # Verify all tools are registered
      tool_atoms = Enum.map(tools, fn {_module, tool_atom} -> tool_atom end)

      assert :modify_classes in tool_atoms
      assert :modify_elements in tool_atoms
      assert :manage_attributes in tool_atoms
      assert :manage_handlers in tool_atoms
      assert :manage_functions in tool_atoms
      assert :manage_variables in tool_atoms
      assert :manage_css in tool_atoms
      assert :manage_init_scripts in tool_atoms
      assert :trigger_interaction in tool_atoms
    end
  end

  describe "info/1" do
    test "provides tool schema for modify_classes" do
      info = WireframeEditor.info(:modify_classes)

      assert info.name == "modify_classes"
      assert info.description =~ "Add or remove CSS classes"
      assert info.input_schema.type == "object"
      assert info.input_schema.required == ["elements"]
    end

    test "provides tool schema for modify_elements" do
      info = WireframeEditor.info(:modify_elements)

      assert info.name == "modify_elements"
      assert info.description =~ "Add new elements"
      assert info.input_schema.type == "object"
    end

    test "provides tool schema for manage_attributes" do
      info = WireframeEditor.info(:manage_attributes)

      assert info.name == "manage_attributes"
      assert info.description =~ "Set or remove HTML attributes"
      assert info.description =~ "REJECTS 'class'"
    end

    test "provides tool schema for trigger_interaction" do
      info = WireframeEditor.info(:trigger_interaction)

      assert info.name == "trigger_interaction"
      assert info.description =~ "EPHEMERAL"
      assert info.description =~ "NOT persisted"
    end
  end

  describe "provide_context/2" do
    test "returns empty context when no lens_state" do
      state = %{context: %{}}

      context = WireframeEditor.provide_context(state)

      assert is_list(context)
      assert length(context) == 1
      assert %{type: "text"} = hd(context)
    end

    test "shows design DOM structure when available" do
      state = %{
        context: %{
          lens_state: %{
            designed: %{
              dom_tree: %{
                tag: "div",
                id: "root",
                classes: ["container"],
                attributes: %{},
                handlers: %{},
                content: nil,
                children: []
              },
              custom_css: %{},
              custom_functions: %{},
              custom_variables: %{},
              init_scripts: %{}
            },
            running: %{},
            modifications: []
          }
        }
      }

      context = WireframeEditor.provide_context(state)

      assert [%{type: "text", text: text}] = context
      assert text =~ "DESIGN DOM STRUCTURE"
      assert text =~ "root"
      assert text =~ "container"
    end

    test "shows available functions when defined" do
      state = %{
        context: %{
          lens_state: %{
            designed: %{
              dom_tree: %{tag: "div", id: "root", children: []},
              custom_functions: %{
                "handleClick" => "(event) => { console.log('clicked'); }"
              },
              custom_css: %{},
              custom_variables: %{},
              init_scripts: %{}
            }
          }
        }
      }

      context = WireframeEditor.provide_context(state)

      assert [%{type: "text", text: text}] = context
      assert text =~ "AVAILABLE FUNCTIONS"
      assert text =~ "handleClick"
    end

    test "shows tool usage guide" do
      state = %{context: %{lens_state: %{designed: %{}, running: %{}}}}

      context = WireframeEditor.provide_context(state)

      assert [%{type: "text", text: text}] = context
      assert text =~ "AVAILABLE TOOLS"
      assert text =~ "modify_classes"
      assert text =~ "TESTING vs PERMANENT"
    end
  end

  describe "execute/3" do
    test "returns error when tool is unknown" do
      result = WireframeEditor.execute(:unknown_tool, %{}, %{})

      assert {message, []} = result
      assert message =~ "Unknown tool"
    end

    test "delegates to DOMHandler for tool execution" do
      # Note: Full integration testing in separate file
      # This just verifies the dispatcher works
      lens_state = %{
        designed: %{
          dom_tree: nil,
          custom_functions: %{}
        }
      }

      result = WireframeEditor.execute(:manage_functions, %{
        "add_functions" => %{"test" => "() => {}"}
      }, %{lens_state: lens_state})

      assert {message, updates} = result
      assert message =~ "Successfully managed"
      assert Keyword.has_key?(updates, :designed)
    end
  end
end
