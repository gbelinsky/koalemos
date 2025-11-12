defmodule Koalemos.Lenses.WireframeEditor do
  @moduledoc """
  Lens for wireframe editing with DOM tree model.

  Provides tools to manipulate a DOM tree stored in lens_state.
  Agent gets current structure via context and uses tools to modify it.

  ## Philosophy: Context = Information, Tools = Control

  The agent receives ALL information via context (no query tools):
  - Design DOM structure (source of truth being edited)
  - Live DOM state (from preview iframe via DOMStateCache)
  - Available functions, variables, CSS rules, init scripts
  - Console output (errors and logs)

  Tools are for CONTROL ONLY (making changes):
  - modify_classes, modify_elements, manage_attributes
  - manage_handlers, manage_functions, manage_variables
  - manage_css, manage_init_scripts
  - trigger_interaction (testing only - ephemeral)

  ## Usage

      iex> Koalemos.Engine.start_routine(
      ...>   "wireframe-test",
      ...>   Koalemos.Routines.WireframeTestRoutine,
      ...>   %{wireframe_html: "<div>...</div>"}
      ...> )

  ## State Structure

  lens_state: %{
    designed: %{
      dom_tree: %{tag, id, classes, attributes, handlers, content, children},
      custom_css: %{selector => rules},
      custom_functions: %{name => arrow_function_code},
      custom_variables: %{name => initial_value},
      init_scripts: %{name => code},
      metadata: %{title, charset}
    },
    running: %{
      dom_tree: %{...},
      variables: %{name => current_value},
      console_output: [%{level, message, timestamp}],
      captured_at: DateTime
    },
    modifications: [%{type, timestamp, ...}]
  }
  """

  alias Koalemos.Lenses.WireframeEditor.DOMHandler
  alias Koalemos.Caches.DOMStateCache
  alias Koalemos.Caches.ConsoleCache
  alias Koalemos.Caches.ScreenshotCache
  alias Koalemos.Caches.WireframeStateCache
  require Logger

  @doc """
  Capture current state from preview iframe.

  Requests DOM snapshot, screenshot, and console messages via PubSub,
  waits for response with timeout, and returns complete running state.

  ## Options
  - `:timeout` - Max wait time in ms (default: 5000)
  - `:skip_screenshot` - Skip screenshot capture (default: false)

  ## Returns
  - `{:ok, running_state}` - Complete state captured
  - `{:error, :timeout}` - Preview didn't respond in time
  - `{:error, :no_preview}` - Preview not running

  ## Example
      {:ok, state} = capture_current_state("routine-123")
      # => %{
      #   dom_tree: %{tag: "div", ...},
      #   console_output: [%{level: "error", ...}],
      #   screenshot: "base64...",
      #   captured_at: ~U[...]
      # }
  """
  @spec capture_current_state(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def capture_current_state(routine_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    skip_screenshot = Keyword.get(opts, :skip_screenshot, false)

    Logger.debug("[WireframeEditor] Requesting state snapshot for #{routine_id}")

    # Subscribe to response topic temporarily
    response_topic = "snapshot:response:#{routine_id}"
    Phoenix.PubSub.subscribe(Koalemos.PubSub, response_topic)

    try do
      # Broadcast snapshot request to preview
      Phoenix.PubSub.broadcast(
        Koalemos.PubSub,
        "wireframe_updates:#{routine_id}",
        {:snapshot_request, routine_id, skip_screenshot: skip_screenshot}
      )

      # Wait for snapshot_ready notification
      receive do
        {:snapshot_ready, ^routine_id, _timestamp} ->
          Logger.debug("[WireframeEditor] Snapshot ready, fetching from caches")

          # Fetch from caches
          dom_tree =
            case DOMStateCache.get_dom_state(routine_id) do
              nil -> nil
              dom_state when is_map(dom_state) -> Map.get(dom_state, :live_dom_tree)
            end

          # Get all console messages from the session (up to limit)
          # No time window - messages persist for entire session since we removed TTL
          console_output =
            ConsoleCache.get_messages(routine_id,
              limit: 50
            )

          Logger.debug(
            "[WireframeEditor] Fetched #{length(console_output)} console messages from cache"
          )

          screenshot_data =
            unless skip_screenshot do
              case ScreenshotCache.get(routine_id) do
                {:ok, data} -> data
                _ -> nil
              end
            end

          # Get designed DOM tree for comparison
          designed_tree =
            case WireframeStateCache.get_state(routine_id) do
              nil -> nil
              lens_state -> get_in(lens_state, [:designed, :dom_tree])
            end

          # Compare live vs designed (simple equality check for now)
          differs = designed_tree != nil && dom_tree != designed_tree

          running_state = %{
            dom_tree: dom_tree,
            console_output: console_output || [],
            screenshot: screenshot_data,
            captured_at: DateTime.utc_now(),
            differs_from_designed: differs
          }

          {:ok, running_state}
      after
        timeout ->
          Logger.warning(
            "[WireframeEditor] Snapshot timeout after #{timeout}ms for #{routine_id}"
          )

          {:error, :timeout}
      end
    after
      # Always unsubscribe
      Phoenix.PubSub.unsubscribe(Koalemos.PubSub, response_topic)
    end
  end

  @doc """
  Provide context blocks showing current wireframe state.

  Returns comprehensive information so agent never needs to query:
  - Design DOM structure (tree visualization)
  - Live DOM state from DOMStateCache (shows JavaScript changes)
  - Available functions, variables, CSS rules
  - Console output (errors and logs)
  - Tool usage guide (testing vs permanent)
  """
  def provide_context(state, _config \\ %{}) do
    lens_state = get_in(state, [:context, :lens_state]) || %{}
    routine_id = get_in(state, [:context, :routine_id])

    designed = Map.get(lens_state, :designed, %{})

    # Capture current live state before building context (Sprint 7)
    # Include screenshots by default (Phase 5) - provides visual feedback
    running =
      if routine_id do
        case capture_current_state(routine_id, skip_screenshot: false) do
          {:ok, current_state} ->
            has_dom = current_state[:dom_tree] != nil
            Logger.info("[WireframeEditor] Captured live state for context - has DOM: #{has_dom}")
            current_state

          {:error, reason} ->
            Logger.warning("[WireframeEditor] Failed to capture live state: #{inspect(reason)}")
            Map.get(lens_state, :running, %{})
        end
      else
        Logger.debug("[WireframeEditor] No routine_id, skipping state capture")
        Map.get(lens_state, :running, %{})
      end

    context_parts = [
      build_design_dom_section(designed),
      build_live_dom_section(designed, running),
      build_functions_section(designed),
      build_variables_section(designed, running),
      build_css_section(designed),
      build_init_scripts_section(designed),
      build_console_section(running),
      build_tools_guide()
    ]

    context_text = Enum.join(Enum.reject(context_parts, &is_nil/1), "\n\n")

    # Add screenshot if available (Sprint 7 Phase 6)
    screenshot_block = build_screenshot_block(running)

    # Return text block + optional image block
    # Image blocks go in messages array (not system) via LensRendering
    if screenshot_block do
      [%{type: "text", text: context_text}, screenshot_block]
    else
      [%{type: "text", text: context_text}]
    end
  end

  @doc """
  Register the 9 wireframe editing tools (config-aware).

  Returns list of {module, tool_atom} tuples for ToolSchema.

  ## Config Options
  - `readonly: true` - Provide context only, no modification tools (returns empty list)

  ## Examples

      # Normal mode - all tools available
      tools(%{})

      # Readonly mode - no tools, only context
      tools(%{readonly: true})
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

  @doc """
  Provide tool schema for each of the 9 tools.
  """
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
                    "Event handlers as {event: {params: [], body: \"code\"}}. Example: {\"click\": {\"params\": [], \"body\": \"window.handleClick()\"}}"
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
          remove_functions: %{
            type: "array",
            items: %{type: "string"},
            description: "Function names to remove"
          },
          replace_functions: %{
            type: "object",
            description: "Functions to replace as {name: arrow_function_code}"
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

      Example: Add .button style, replace @keyframes animation, remove old rules.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          add: %{
            type: "object",
            description: "CSS rules to add as {selector: rules_string}"
          },
          replace: %{
            type: "object",
            description: "CSS rules to replace as {selector: rules_string}"
          },
          remove: %{
            type: "array",
            items: %{type: "string"},
            description: "Selectors to remove"
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

      Example: Add canvasSetup script, replace initialization, remove old scripts.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          add: %{
            type: "object",
            description: "Scripts to add as {name: code}"
          },
          replace: %{
            type: "object",
            description: "Scripts to replace as {name: code}"
          },
          remove: %{
            type: "array",
            items: %{type: "string"},
            description: "Script names to remove"
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

  @doc """
  Execute wireframe editing tools.

  Delegates to DOMHandler for actual operations.
  Returns {result_text, lens_updates} tuple.
  """
  def execute(tool_name, args, context) do
    lens_state = Map.get(context, :lens_state, %{})
    routine_id = Map.get(context, :routine_id)

    try do
      result =
        case tool_name do
          :modify_classes ->
            DOMHandler.modify_classes(lens_state, args)

          :modify_elements ->
            DOMHandler.modify_elements(lens_state, args)

          :manage_attributes ->
            DOMHandler.manage_attributes(lens_state, args)

          :manage_handlers ->
            DOMHandler.manage_handlers(lens_state, args)

          :manage_functions ->
            DOMHandler.manage_functions(lens_state, args)

          :manage_variables ->
            DOMHandler.manage_variables(lens_state, args)

          :manage_css ->
            DOMHandler.manage_css(lens_state, args)

          :manage_init_scripts ->
            DOMHandler.manage_init_scripts(lens_state, args)

          :trigger_interaction ->
            DOMHandler.trigger_interaction(lens_state, args, context)

          _ ->
            {"Unknown tool: #{inspect(tool_name)}", []}
        end

      # Broadcast DOM tree updates for successful modifications (if routine_id available)
      broadcast_dom_update_if_needed(result, tool_name, routine_id)

      result
    rescue
      error ->
        Logger.error("[WireframeEditor] Tool execution failed: #{Exception.message(error)}")
        {"Tool execution failed: #{Exception.message(error)}", []}
    end
  end

  # Private helper functions for context building

  @current_state_suffix " (CURRENT STATE)"
  @current_state_note """
  NOTE: This shows the wireframe's current state, including all changes from your previous tool executions.
  When you modify elements, add CSS, or update handlers, those changes appear here immediately.
  """

  defp build_design_dom_section(%{dom_tree: dom_tree, handlers: handlers})
       when not is_nil(dom_tree) do
    """
    === DESIGN DOM STRUCTURE#{@current_state_suffix} ===

    #{@current_state_note}
    #{format_dom_tree(dom_tree, 0, handlers)}
    """
  end

  defp build_design_dom_section(%{dom_tree: dom_tree}) when not is_nil(dom_tree) do
    """
    === DESIGN DOM STRUCTURE#{@current_state_suffix} ===

    #{@current_state_note}
    #{format_dom_tree(dom_tree, 0, %{})}
    """
  end

  defp build_design_dom_section(_), do: nil

  defp build_live_dom_section(_designed, %{
         dom_tree: live_tree,
         captured_at: timestamp,
         differs_from_designed: differs
       })
       when not is_nil(live_tree) do
    age = format_timestamp_age(timestamp)

    Logger.debug(
      "[WireframeEditor] Building LIVE DOM section with tree: #{inspect(Map.keys(live_tree))}"
    )

    formatted_tree = format_dom_tree(live_tree, 0, %{})
    Logger.info("[WireframeEditor] Formatted tree length: #{String.length(formatted_tree)} chars")

    # Show status based on comparison with designed state
    status =
      if differs do
        "Status: DIFFERS FROM DESIGN ⚠️  (user or JavaScript modified the page)"
      else
        "Status: MATCHES DESIGN ✓"
      end

    result = """
    === LIVE DOM STATE (captured #{age}) ===

    #{status}

    #{formatted_tree}
    """

    Logger.info("[WireframeEditor] LIVE DOM section length: #{String.length(result)} chars")
    result
  end

  defp build_live_dom_section(_designed, running) do
    Logger.warning(
      "[WireframeEditor] build_live_dom_section skipped - running: #{inspect(Map.keys(running || %{}))}"
    )

    nil
  end

  defp build_functions_section(%{custom_functions: functions}) when map_size(functions) > 0 do
    function_list =
      Enum.map_join(functions, "\n\n", fn {name, code} ->
        # Show full function code - agents need to see the complete implementation
        "#{name}:\n#{code}"
      end)

    """
    === AVAILABLE FUNCTIONS#{@current_state_suffix} ===

    #{function_list}
    """
  end

  defp build_functions_section(_), do: nil

  defp build_variables_section(%{custom_variables: vars}, %{variables: runtime_vars})
       when map_size(vars) > 0 do
    var_list =
      Enum.map_join(vars, "\n", fn {name, initial} ->
        current = Map.get(runtime_vars || %{}, name)
        status = if current == initial, do: "", else: " ⚠️ (current: #{inspect(current)})"
        "- #{name} = #{inspect(initial)}#{status}"
      end)

    """
    === GLOBAL VARIABLES#{@current_state_suffix} ===

    #{var_list}
    """
  end

  defp build_variables_section(%{custom_variables: vars}, _) when map_size(vars) > 0 do
    var_list =
      Enum.map_join(vars, "\n", fn {name, initial} ->
        "- #{name} = #{inspect(initial)}"
      end)

    """
    === GLOBAL VARIABLES#{@current_state_suffix} ===

    #{var_list}
    """
  end

  defp build_variables_section(_, _), do: nil

  defp build_css_section(%{custom_css: css}) when map_size(css) > 0 do
    css_list =
      Enum.map_join(css, "\n", fn {selector, declarations} ->
        # Handle both string format and map format
        decl_str =
          case declarations do
            # String format: "property: value; property: value"
            str when is_binary(str) ->
              str

            # Map format: %{"property" => "value", ...}
            map when is_map(map) ->
              Enum.map_join(map, "; ", fn {prop, val} -> "#{prop}: #{val}" end)

            # List format: [{"property", "value"}, ...]
            list when is_list(list) ->
              Enum.map_join(list, "; ", fn {prop, val} -> "#{prop}: #{val}" end)
          end

        "- #{selector} { #{decl_str} }"
      end)

    """
    === CUSTOM CSS#{@current_state_suffix} ===

    #{css_list}
    """
  end

  defp build_css_section(_), do: nil

  defp build_init_scripts_section(%{init_scripts: scripts}) when map_size(scripts) > 0 do
    script_list =
      Enum.map_join(scripts, "\n\n", fn {name, code} ->
        # Show full init scripts - they're important runtime behavior
        "#{name}:\n#{code}"
      end)

    """
    === INIT SCRIPTS#{@current_state_suffix} ===

    These scripts run once when the page loads (on DOMContentLoaded).

    #{script_list}
    """
  end

  defp build_init_scripts_section(_), do: nil

  defp build_console_section(%{console_output: logs}) when length(logs) > 0 do
    Logger.debug("[WireframeEditor] Building console section with #{length(logs)} messages")

    # Count errors and warnings (Sprint 7 Phase 6)
    error_count = Enum.count(logs, fn log -> Map.get(log, :level) == "error" end)
    warn_count = Enum.count(logs, fn log -> Map.get(log, :level) == "warn" end)

    # Show last 20 messages (user preference)
    recent_logs = Enum.take(logs, 20)

    # Format with visual indicators (Sprint 7 Phase 6)
    log_list =
      Enum.map_join(recent_logs, "\n", fn log ->
        level = Map.get(log, :level, "log")
        level_upper = String.upcase(level)
        message = Map.get(log, :message, "")
        timestamp = format_timestamp_age(Map.get(log, :timestamp))

        # Add visual indicator based on level
        indicator =
          case level do
            "error" -> "❌"
            "warn" -> "⚠️"
            _ -> "ℹ️"
          end

        "#{indicator} [#{level_upper}] (#{timestamp}) #{message}"
      end)

    # Build summary line
    summary_parts = []

    summary_parts =
      if error_count > 0, do: [summary_parts, "#{error_count} error(s)"], else: summary_parts

    summary_parts =
      if warn_count > 0, do: [summary_parts, "#{warn_count} warning(s)"], else: summary_parts

    summary =
      if length(List.flatten(summary_parts)) > 0 do
        "\nSummary: " <> Enum.join(List.flatten(summary_parts), ", ")
      else
        ""
      end

    """
    === CONSOLE OUTPUT (last 20 messages) ===
    #{summary}
    #{log_list}
    """
  end

  defp build_console_section(running) do
    Logger.debug(
      "[WireframeEditor] No console messages to display. Running state: #{inspect(Map.keys(running))}"
    )

    nil
  end

  # Build screenshot image block (Sprint 7 Phase 6)
  # Returns image block in format expected by Anthropic provider
  # Will be added to messages array (not system) by LensRendering
  defp build_screenshot_block(%{screenshot: screenshot_data}) when not is_nil(screenshot_data) do
    %{
      type: "image",
      source: %{
        type: "base64",
        media_type: "image/png",
        data: screenshot_data
      }
    }
  end

  defp build_screenshot_block(_), do: nil

  defp build_tools_guide do
    """
    === AVAILABLE TOOLS ===

    CORE MODIFICATION TOOLS:
    - modify_classes: Add/remove CSS classes from elements (batch)
    - modify_elements: Add new elements, remove, or replace elements (batch)
    - manage_attributes: Set/remove HTML attributes (NOT classes)
    - manage_handlers: Attach/replace/remove event handlers

    BEHAVIOR TOOLS:
    - manage_functions: Add/remove/replace JavaScript functions (arrow functions)
    - manage_variables: Set/remove global variables (window.*)
    - manage_css: Add/remove/replace custom CSS rules
    - manage_init_scripts: Add/remove/replace initialization scripts

    TESTING TOOL:
    - trigger_interaction: Test interactions (EPHEMERAL - won't persist to design)

    TESTING vs PERMANENT CHANGES:
    - Use trigger_interaction to TEST (ephemeral - changes won't persist)
    - Use design tools for PERMANENT changes (will persist)
    - After testing, check LIVE DOM STATE to see what JavaScript did
    - Compare design vs live state to understand actual behavior
    """
  end

  defp format_dom_tree(%{tag: tag, id: id} = element, indent, handlers_map) do
    indent_str = String.duplicate("  ", indent)
    classes = format_classes(Map.get(element, :classes, []))
    attributes = format_attributes(Map.get(element, :attributes, %{}))
    content = Map.get(element, :content)
    children = Map.get(element, :children, [])

    # Look up handlers for this element ID in the handlers map
    element_handlers = Map.get(handlers_map, id, %{})
    handlers_str = format_handlers_inline(element_handlers, indent)

    # Build the base element line with tag and ID
    base = "#{indent_str}- #{id}: <#{tag}>"

    # Add classes prominently if present
    with_classes =
      if classes != "" do
        base <> " .#{String.replace(classes, " ", " .")}"
      else
        base
      end

    # Add other attributes and content (only show content if it's a non-empty string)
    # Note: Filter out "nil" string because Observer.make_serializable converts atom nil to string "nil"
    parts = [
      with_classes,
      if(attributes != "", do: " | #{attributes}", else: ""),
      if(is_binary(content) && content != "" && content != "nil",
        do: " | Content: \"#{content}\"",
        else: ""
      )
    ]

    element_line = Enum.reject(parts, &(&1 == "")) |> Enum.join("")

    # Add handlers on separate lines if present
    element_with_handlers =
      if handlers_str != "" do
        element_line <> "\n" <> handlers_str
      else
        element_line
      end

    if length(children) > 0 do
      children_str = Enum.map_join(children, "\n", &format_dom_tree(&1, indent + 1, handlers_map))
      element_with_handlers <> "\n" <> children_str
    else
      element_with_handlers
    end
  end

  defp format_dom_tree(_, _, _), do: ""

  defp format_classes([]), do: ""
  defp format_classes(classes), do: Enum.join(classes, " ")

  defp format_attributes(attrs) when map_size(attrs) == 0, do: ""

  defp format_attributes(attrs) do
    Enum.map_join(attrs, ", ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp format_handlers_inline(handlers, _indent) when map_size(handlers) == 0, do: ""

  defp format_handlers_inline(handlers, indent) do
    handler_indent = String.duplicate("  ", indent + 1)

    Enum.map_join(handlers, "\n", fn {event_type, handler_info} ->
      params = Map.get(handler_info, :params, []) |> Enum.join(", ")
      body = Map.get(handler_info, :body, "")

      "#{handler_indent}◆ on#{event_type}(#{params}):\n#{handler_indent}  #{body}"
    end)
  end

  defp format_timestamp_age(nil), do: "unknown"

  # Handle JavaScript timestamps (milliseconds since epoch)
  defp format_timestamp_age(timestamp) when is_integer(timestamp) do
    now_ms = System.system_time(:millisecond)
    diff_ms = now_ms - timestamp
    seconds_ago = div(diff_ms, 1000)

    cond do
      seconds_ago < 5 -> "just now"
      seconds_ago < 60 -> "#{seconds_ago}s ago"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m ago"
      true -> "#{div(seconds_ago, 3600)}h ago"
    end
  end

  # Handle DateTime structs
  defp format_timestamp_age(timestamp) when is_struct(timestamp, DateTime) do
    seconds_ago = DateTime.diff(DateTime.utc_now(), timestamp)

    cond do
      seconds_ago < 5 -> "just now"
      seconds_ago < 60 -> "#{seconds_ago}s ago"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m ago"
      true -> "#{div(seconds_ago, 3600)}h ago"
    end
  end

  defp format_timestamp_age(_), do: "unknown"

  # Broadcast DOM tree updates via PubSub for live preview updates
  # IMPORTANT: Also updates cache so PreviewLive gets fresh data (Sprint 6 fix)
  defp broadcast_dom_update_if_needed({_result_text, lens_updates}, tool_name, routine_id)
       when not is_nil(routine_id) and tool_name != :trigger_interaction do
    # Check if there's an updated DOM tree in lens_updates
    case Keyword.get(lens_updates, :designed) do
      %{dom_tree: updated_tree} = updated_designed when not is_nil(updated_tree) ->
        # Update cache BEFORE broadcasting (Sprint 6 fix)
        # This ensures PreviewLive gets fresh data when it loads from cache
        case Koalemos.Caches.WireframeStateCache.get_state(routine_id) do
          nil ->
            Logger.warning(
              "[WireframeEditor] Cannot update cache - no lens_state found for #{routine_id}"
            )

          existing_lens_state ->
            # Merge updated :designed map into existing lens_state
            updated_lens_state =
              Map.update(existing_lens_state, :designed, updated_designed, fn existing_designed ->
                merged = Map.merge(existing_designed, updated_designed)

                Logger.debug(
                  "[Cache Merge] existing handlers: #{map_size(Map.get(existing_designed, :handlers, %{}))}"
                )

                Logger.debug(
                  "[Cache Merge] updated handlers: #{map_size(Map.get(updated_designed, :handlers, %{}))}"
                )

                Logger.debug(
                  "[Cache Merge] merged handlers: #{map_size(Map.get(merged, :handlers, %{}))}"
                )

                merged
              end)

            Koalemos.Caches.WireframeStateCache.put_state(routine_id, updated_lens_state)
            Logger.debug("[WireframeEditor] Updated cache before broadcast for #{tool_name}")
        end

        # Now broadcast the update
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "wireframe_updates:#{routine_id}",
          {:dom_tree_updated, updated_tree, %{source: :tool_execution, tool: tool_name}}
        )

        Logger.debug(
          "[WireframeEditor] Broadcasted DOM update for #{tool_name} to routine #{routine_id}"
        )

      _ ->
        :ok
    end
  end

  defp broadcast_dom_update_if_needed(_result, _tool_name, _routine_id), do: :ok
end
