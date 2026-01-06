defmodule WireframeEditorWeb.Lenses.WireframeEditor do
  @moduledoc """
  Wireframe editor lens - V4 architecture.

  Simplified from V3:
  - No adapters: Direct calls to StateServer
  - No PubSub: StateServer handles preview coordination
  - Blocking operations: capture_state/execute_interaction wait for completion

  Reuses EditorCore for pure business logic.
  """

  alias WireframeEditorWeb.Lenses.Wireframe.EditorCore
  alias WireframeEditorWeb.Servers.WireframeStateServer
  alias WireframeEditorWeb.Services.ScreenshotRenderer

  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  @default_timeout 10_000

  # ============================================================================
  # Lens Callbacks
  # ============================================================================

  @doc """
  Execute a tool call.

  Returns {message, lens_updates} where lens_updates will be merged into lens state.
  """
  def execute(tool_name, params, context, config \\ %{}) do
    routine_id = context[:routine_id]
    is_last_tool? = match?([_], context[:to_execute])
    timeout = config[:timeout] || @default_timeout

    # Log tool execution for debugging
    Log.debug(:wireframe, "[WireframeEditor] Tool: #{tool_name}, params: #{inspect(params, limit: 200)}")

    designed = WireframeStateServer.get_designed(routine_id)

    case EditorCore.execute_tool(tool_name, params, designed) do
      {:ok, message, updates} ->
        Log.debug(:wireframe, "[WireframeEditor] Tool #{tool_name} success: #{String.slice(message, 0, 100)}")
        if tool_name == :trigger_interaction do
          # Trigger interaction doesn't persist - execute via StateServer
          interaction_args = Map.get(updates, :_interaction_request, params)
          execute_interaction(routine_id, interaction_args, timeout)
        else
          # Persist updates
          WireframeStateServer.update_designed(routine_id, updates)

          # Reload preview - always for now, optimize later if needed
          if is_last_tool? do
            # Full reload
            WireframeStateServer.reload_preview(routine_id)
          else
            # Just trigger reload for intermediate tools
            WireframeStateServer.reload_preview(routine_id)
          end
        end

        # Mark that we need a new screenshot after tool execution
        WireframeStateServer.set_screenshot_needed(routine_id, true)

        {message, %{}}

      {:error, reason} ->
        {reason, %{}}
    end
  end

  defp execute_interaction(routine_id, args, timeout) do
    Log.debug(:wireframe, "[WireframeEditor] Executing interaction: #{inspect(args)}")

    case WireframeStateServer.execute_interaction(routine_id, args, timeout) do
      {:ok, result} ->
        Log.debug(:wireframe, "[WireframeEditor] Interaction complete: #{inspect(result)}")
        result

      {:error, reason} ->
        Log.warning(:wireframe, "[WireframeEditor] Interaction failed: #{inspect(reason)}")
        %{"success" => false, "error" => inspect(reason)}
    end
  end

  @doc """
  Provide context for the LLM.

  Captures running state and screenshot, then builds context blocks.
  Screenshot is always captured fresh since user may have interacted with preview.
  """
  def provide_context(state, config \\ %{}) do
    routine_id = get_in(state, [:context, :routine_id])
    timeout = config[:timeout] || @default_timeout

    designed = WireframeStateServer.get_designed(routine_id)

    # Capture running state from preview
    case WireframeStateServer.capture_state(routine_id, timeout) do
      {:ok, running} ->
        # Always capture fresh screenshot - user may have interacted with preview
        screenshot = capture_screenshot(routine_id, designed, running)
        WireframeStateServer.update_screenshot(routine_id, screenshot)

        # Build context blocks (logged centrally by LensRendering step)
        EditorCore.build_context(designed, running, screenshot)

      {:error, _reason} ->
        # Graceful degradation - provide context without running state
        Log.warning(:context, "[Context] Capture failed, building context without running state")
        EditorCore.build_context(designed, nil, nil)
    end
  end

  defp capture_screenshot(routine_id, designed, running) do
    lens_state = %{designed: designed, running: running}

    case ScreenshotRenderer.capture_from_lens_state(lens_state, use_live_dom: true, routine_id: routine_id) do
      {:ok, base64} ->
        Log.debug(:wireframe, "[WireframeEditor] Screenshot captured")
        base64

      {:error, reason} ->
        Log.warning(:wireframe, "[WireframeEditor] Screenshot failed: #{inspect(reason)}")
        nil
    end
  end

  @doc """
  Get available tools for this lens.

  ## Config Options
  - `readonly: true` - Provide context only, no modification tools (returns empty list)
  """
  def tools(config \\ %{}) do
    if Map.get(config, :readonly, false) do
      # Readonly mode: no tools, only context via provide_context
      []
    else
      # Normal mode: all 9 modification tools
      [
        {__MODULE__, :modify_classes},
        {__MODULE__, :modify_elements},
        {__MODULE__, :manage_attributes},
        {__MODULE__, :manage_handlers},
        {__MODULE__, :manage_functions},
        {__MODULE__, :manage_variables},
        {__MODULE__, :manage_css},
        {__MODULE__, :manage_init_scripts},
        {__MODULE__, :trigger_interaction}
      ]
    end
  end

  # ============================================================================
  # Tool Info Schemas (same as V3)
  # ============================================================================

  def info(:modify_classes) do
    %{
      name: "modify_classes",
      description: """
      Add or remove CSS classes from one or more elements.

      This tool modifies the class attribute only. For other attributes, use manage_attributes.
      Changes are PERMANENT (persisted to design).

      Example: Add 'active' class to button, remove 'hidden' from sidebar.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          elements: %{
            type: "array",
            description: "List of elements to modify",
            items: %{
              type: "object",
              properties: %{
                element_id: %{type: "string", description: "ID of element to modify"},
                add_classes: %{
                  type: "array",
                  items: %{type: "string"},
                  description: "Classes to add"
                },
                remove_classes: %{
                  type: "array",
                  items: %{type: "string"},
                  description: "Classes to remove"
                }
              },
              required: ["element_id"]
            }
          }
        },
        required: ["elements"]
      }
    }
  end

  def info(:modify_elements) do
    %{
      name: "modify_elements",
      description: """
      Add new elements, remove existing elements, or replace elements.

      Batch operations for efficient DOM manipulation.
      Changes are PERMANENT (persisted to design).

      Example: Add a button to sidebar, remove old menu item, replace header with new structure.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          add_elements: %{
            type: "array",
            description: "Elements to add",
            items: %{
              type: "object",
              properties: %{
                parent_id: %{type: "string", description: "ID of parent element"},
                tag: %{type: "string", description: "HTML tag (div, button, etc.)"},
                id: %{type: "string", description: "Unique ID for new element"},
                content: %{
                  type: "string",
                  description: "Text content (plain text only, NOT innerHTML)"
                },
                classes: %{
                  type: "array",
                  items: %{type: "string"},
                  description: "CSS classes"
                },
                attributes: %{
                  type: "object",
                  description:
                    "HTML attributes (type, placeholder, href, value, etc.) Note: Use manage_css for styling, not inline 'style' attribute"
                },
                handlers: %{
                  type: "object",
                  description:
                    "Event handlers as {event: {params: [], body: \"code\"}}. Example: {\"click\": {\"params\": [], \"body\": \"console.log('clicked')\"}}"
                },
                children: %{
                  type: "array",
                  description:
                    "Nested child elements (recursive - each child has same structure)",
                  items: %{type: "object"}
                },
                position: %{
                  type: "string",
                  enum: ["first", "last", "before", "after"],
                  description: "Where to insert (default: last)"
                },
                reference_id: %{
                  type: "string",
                  description: "Reference element ID (for before/after position)"
                }
              },
              required: ["parent_id", "tag", "id"]
            }
          },
          remove_elements: %{
            type: "array",
            items: %{type: "string"},
            description: "Element IDs to remove"
          },
          replace_elements: %{
            type: "array",
            description:
              "Elements to replace. WARNING: If new_element doesn't specify 'children', the old element's children will be LOST. To keep children, include them in new_element.children or use modify_classes/manage_attributes instead.",
            items: %{
              type: "object",
              properties: %{
                element_id: %{type: "string", description: "ID of element to replace"},
                new_element: %{
                  type: "object",
                  description:
                    "New element structure with properties: tag, id, content, classes, attributes, handlers, children",
                  properties: %{
                    tag: %{type: "string", description: "HTML tag"},
                    id: %{type: "string", description: "Element ID (can be same or different)"},
                    content: %{
                      type: "string",
                      description: "Text content (plain text only, NOT innerHTML)"
                    },
                    classes: %{
                      type: "array",
                      items: %{type: "string"},
                      description: "CSS classes"
                    },
                    attributes: %{
                      type: "object",
                      description:
                        "HTML attributes (value, type, etc.) Note: Use manage_css for styling"
                    },
                    handlers: %{
                      type: "object",
                      description: "Event handlers as {event: {params: [], body: \"code\"}}"
                    },
                    children: %{
                      type: "array",
                      description: "Child elements (preserves old children if omitted)",
                      items: %{type: "object"}
                    }
                  },
                  required: ["tag", "id"]
                }
              },
              required: ["element_id", "new_element"]
            }
          }
        }
      }
    }
  end

  def info(:manage_attributes) do
    %{
      name: "manage_attributes",
      description: """
      Set or remove HTML attributes on elements.

      This tool explicitly REJECTS 'class' attribute - use modify_classes instead.
      Use for: type, placeholder, href, disabled, aria-*, data-*, etc.
      Changes are PERMANENT (persisted to design).

      BOOLEAN-VALUED ATTRIBUTES:
      - Use boolean true/false values for attributes like disabled, checked, readonly, required
      - true renders the attribute: {"disabled": true} → <button disabled>
      - false omits the attribute: {"disabled": false} → attribute is removed
      - Works for ANY attribute, not just standard boolean attributes

      IMPORTANT: Only form elements (button, input, select, textarea) and fieldset
      can have the 'disabled' attribute. List items (<li>) cannot be disabled.

      Example: Set placeholder on input, disable a button, add href to link.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          elements: %{
            type: "array",
            description: "Elements to modify",
            items: %{
              type: "object",
              properties: %{
                element_id: %{type: "string", description: "ID of element"},
                set: %{
                  type: "object",
                  description: "Attributes to set as {name: value}"
                },
                remove: %{
                  type: "array",
                  items: %{type: "string"},
                  description: "Attribute names to remove"
                }
              },
              required: ["element_id"]
            }
          }
        },
        required: ["elements"]
      }
    }
  end

  def info(:manage_handlers) do
    %{
      name: "manage_handlers",
      description: """
      Manage event handlers across multiple elements.

      Add, replace, or remove event listeners with inline JavaScript code.
      Changes are PERMANENT (persisted to design).

      Handler format: {event: {params: ["event"], body: "console.log('clicked')"}}
      - params: Array of parameter names (usually ["event"] or [])
      - body: Inline JavaScript code to execute

      You can also reference functions: body can call window.funcName()

      Example: Add click handler that logs to console, replace form submit, remove old handlers.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          elements: %{
            type: "array",
            description: "Elements to modify",
            items: %{
              type: "object",
              properties: %{
                element_id: %{type: "string", description: "ID of element"},
                add: %{
                  type: "object",
                  description:
                    "Handlers to add as {event: {params: [...], body: \"...\"}} (fails if exists)"
                },
                replace: %{
                  type: "object",
                  description:
                    "Handlers to replace as {event: {params: [...], body: \"...\"}} (fails if doesn't exist)"
                },
                remove: %{
                  type: "array",
                  items: %{type: "string"},
                  description: "Event types to remove (click, submit, etc.)"
                }
              },
              required: ["element_id"]
            }
          }
        },
        required: ["elements"]
      }
    }
  end

  def info(:manage_functions) do
    %{
      name: "manage_functions",
      description: """
      Add, remove, or replace JavaScript functions (arrow functions only).

      Functions are globally available and can be referenced by event handlers.
      Changes are PERMANENT (persisted to design).

      Example: Add handleClick function, replace validateForm, remove old functions.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          add_functions: %{
            type: "object",
            description: "Functions to add as {name: arrow_function_code}"
          },
          replace_functions: %{
            type: "object",
            description: "Functions to replace as {name: arrow_function_code}"
          },
          remove_functions: %{
            type: "array",
            items: %{type: "string"},
            description: "Function names to remove"
          }
        }
      }
    }
  end

  def info(:manage_variables) do
    %{
      name: "manage_variables",
      description: """
      Set or remove global JavaScript variables (window.*).

      Variables must have JSON-serializable initial values.
      Context shows both initial and current (runtime) values.
      Changes are PERMANENT (persisted to design).

      Example: Set state = {count: 0}, remove old config variable.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          set_variables: %{
            type: "object",
            description: "Variables with initial values (must be JSON-serializable)"
          },
          remove_variables: %{
            type: "array",
            items: %{type: "string"},
            description: "Variable names to remove"
          }
        }
      }
    }
  end

  def info(:manage_css) do
    %{
      name: "manage_css",
      description: """
      Manage custom CSS rules.

      Add, replace, or remove CSS rules for classes, IDs, pseudo-classes, @keyframes, @media.
      Changes are PERMANENT (persisted to design).
      """,
      input_schema: %{
        type: "object",
        properties: %{
          add: %{
            type: "object",
            description:
              "CSS rules to add. Example: {\"#app\": {\"padding\": \"20px\", \"background\": \"#fff\"}}",
            additionalProperties: %{
              type: "object",
              description: "CSS declarations as property-value pairs",
              additionalProperties: %{type: "string"}
            }
          },
          replace: %{
            type: "object",
            description:
              "CSS rules to replace. Example: {\".button\": {\"color\": \"blue\", \"border\": \"none\"}}",
            additionalProperties: %{
              type: "object",
              description: "CSS declarations as property-value pairs",
              additionalProperties: %{type: "string"}
            }
          },
          remove: %{
            type: "array",
            items: %{type: "string"},
            description: "CSS selectors to remove. Example: [\"#old-style\", \".deprecated\"]"
          }
        }
      }
    }
  end

  def info(:manage_init_scripts) do
    %{
      name: "manage_init_scripts",
      description: """
      Manage one-time initialization scripts.

      Scripts run once on DOMContentLoaded.
      Use for: canvas setup, library initialization, etc.
      Changes are PERMANENT (persisted to design).
      """,
      input_schema: %{
        type: "object",
        properties: %{
          add: %{
            type: "object",
            description:
              "Scripts to add. Example: {\"setup_counter\": \"window.count = 0;\"}",
            additionalProperties: %{type: "string", description: "JavaScript code"}
          },
          replace: %{
            type: "object",
            description:
              "Scripts to replace. Example: {\"init_0\": \"console.log('new code');\"}",
            additionalProperties: %{type: "string", description: "JavaScript code"}
          },
          remove: %{
            type: "array",
            items: %{type: "string"},
            description: "Script names to remove. Example: [\"old_script\", \"init_0\"]"
          }
        }
      }
    }
  end

  def info(:trigger_interaction) do
    %{
      name: "trigger_interaction",
      description: """
      Test interactions with elements (EPHEMERAL ONLY - changes NOT persisted).

      Use this tool to TEST your design. Changes are temporary and won't persist to the design.
      After testing, check LIVE DOM STATE in context to see what happened.
      For PERMANENT changes, use the design tools (modify_elements, manage_handlers, etc.).

      Example: Click button to test, fill input and submit form, execute JavaScript to verify behavior.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          action: %{
            type: "string",
            enum: ["click", "fill_input", "submit_form", "execute_js"],
            description: "Type of interaction"
          },
          element_id: %{
            type: "string",
            description: "ID of target element"
          },
          value: %{
            type: "string",
            description: "Input value (for fill_input action)"
          },
          javascript: %{
            type: "string",
            description: "JavaScript code to execute (for execute_js action)"
          }
        },
        required: ["action"]
      }
    }
  end
end
