defmodule WireframeEditorWeb.Lenses.Wireframe.EditorCore do
  @moduledoc """
  Pure business logic for wireframe editing.

  All functions are pure - no side effects, no I/O.
  State access and preview communication are handled by adapters.

  ## Tool Functions

  Each tool function takes:
  - params: The tool parameters from the LLM
  - designed: The current designed state

  And returns:
  - {:ok, message, updates} on success
  - {:error, message} on failure

  ## Context Building

  `build_context/3` creates the context blocks for the LLM from:
  - designed: The authored state
  - running: The executed state (after init scripts)
  - screenshot: Base64 encoded image
  """

  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  # ============================================================================
  # Tool: modify_classes
  # ============================================================================

  @doc """
  Modify CSS classes on one or more elements.

  Params:
  - elements: List of %{"element_id" => id, "add_classes" => [...], "remove_classes" => [...]}

  Returns {:ok, message, %{dom_tree: updated_tree}} or {:error, message}
  """
  def execute_tool(:modify_classes, %{"elements" => elements}, designed) when is_list(elements) do
    dom_tree = Map.get(designed, :dom_tree)

    if is_nil(dom_tree) do
      {:error, "No wireframe loaded. Load a wireframe first."}
    else
      {final_tree, results} =
        Enum.reduce(elements, {dom_tree, []}, fn elem, {current_tree, acc_results} ->
          element_id = Map.get(elem, "element_id")
          add_classes = ensure_list(Map.get(elem, "add_classes", []))
          remove_classes = ensure_list(Map.get(elem, "remove_classes", []))

          case modify_element_classes(current_tree, element_id, add_classes, remove_classes) do
            {:ok, updated_tree} ->
              {updated_tree, [{:ok, element_id} | acc_results]}

            {:error, msg} ->
              {current_tree, [{:error, msg} | acc_results]}
          end
        end)

      errors = Enum.filter(results, &match?({:error, _}, &1))

      if length(errors) > 0 do
        error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
        {:error, "Errors modifying classes:\n#{error_messages}"}
      else
        count = length(elements)
        {:ok, "Successfully modified classes on #{count} element(s)", %{dom_tree: final_tree}}
      end
    end
  end

  def execute_tool(:modify_classes, _invalid_params, _designed) do
    {:error, "Invalid params: expected 'elements' array"}
  end

  # ============================================================================
  # Tool: modify_elements
  # Add, remove, or replace DOM elements.
  # ============================================================================

  def execute_tool(:modify_elements, args, designed) when is_map(args) do
    dom_tree = Map.get(designed, :dom_tree)

    if is_nil(dom_tree) do
      {:error, "No wireframe loaded. Load a wireframe first."}
    else
      # Process in order: remove, replace, add
      remove_ids = ensure_list(Map.get(args, "remove_elements", []))
      {tree_after_remove, remove_results} = process_removals(dom_tree, remove_ids)

      replacements = ensure_list(Map.get(args, "replace_elements", []))
      {tree_after_replace, replace_results} = process_replacements(tree_after_remove, replacements)

      additions = ensure_list(Map.get(args, "add_elements", []))
      {final_tree, add_results} = process_additions(tree_after_replace, additions)

      all_results = remove_results ++ replace_results ++ add_results
      errors = Enum.filter(all_results, &match?({:error, _}, &1))
      successes = Enum.filter(all_results, &match?({:ok, _}, &1))

      if length(successes) == 0 && length(errors) > 0 do
        error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
        {:error, "All operations failed:\n#{error_messages}"}
      else
        # Extract handlers from tree and merge
        tree_handlers = extract_handlers_from_tree(final_tree)
        existing_handlers = Map.get(designed, :handlers, %{})
        merged_handlers = Map.merge(existing_handlers, tree_handlers)

        total_success = length(successes)

        result_message =
          if length(errors) > 0 do
            error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "  - #{msg}" end)
            "Partially succeeded: #{total_success} operation(s) completed, #{length(errors)} failed:\n#{error_messages}"
          else
            "Successfully modified #{total_success} element(s)"
          end

        {:ok, result_message, %{dom_tree: final_tree, handlers: merged_handlers}}
      end
    end
  end

  def execute_tool(:modify_elements, _invalid_params, _designed) do
    {:error, "Invalid params: expected a map with add_elements, remove_elements, or replace_elements"}
  end

  # ============================================================================
  # Tool: manage_attributes
  # Manage HTML attributes on elements (rejects 'class' - use modify_classes instead).
  # ============================================================================

  def execute_tool(:manage_attributes, %{"elements" => elements}, designed) when is_list(elements) do
    dom_tree = Map.get(designed, :dom_tree)

    if is_nil(dom_tree) do
      {:error, "No wireframe loaded. Load a wireframe first."}
    else
      # Validate no 'class' attribute
      has_class_attr = Enum.any?(elements, fn elem ->
        set_attrs = ensure_map(Map.get(elem, "set", %{}))
        Map.has_key?(set_attrs, "class")
      end)

      if has_class_attr do
        {:error, "Cannot set 'class' attribute. Use modify_classes tool instead."}
      else
        {final_tree, results} =
          Enum.reduce(elements, {dom_tree, []}, fn elem, {current_tree, acc_results} ->
            element_id = Map.get(elem, "element_id")
            set_attrs = ensure_map(Map.get(elem, "set", %{}))
            remove_attrs = ensure_list(Map.get(elem, "remove", []))

            case modify_element_attributes(current_tree, element_id, set_attrs, remove_attrs) do
              {:ok, updated_tree} ->
                {updated_tree, [{:ok, element_id} | acc_results]}
              {:error, msg} ->
                {current_tree, [{:error, msg} | acc_results]}
            end
          end)

        errors = Enum.filter(results, &match?({:error, _}, &1))

        if length(errors) > 0 do
          error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
          {:error, "Errors managing attributes:\n#{error_messages}"}
        else
          count = length(elements)
          {:ok, "Successfully managed attributes on #{count} element(s)", %{dom_tree: final_tree}}
        end
      end
    end
  end

  def execute_tool(:manage_attributes, _invalid_params, _designed) do
    {:error, "Invalid params: expected 'elements' array"}
  end

  # ============================================================================
  # Tool: manage_handlers
  # Manage event handlers on elements.
  # ============================================================================

  def execute_tool(:manage_handlers, %{"elements" => elements}, designed) when is_list(elements) do
    dom_tree = Map.get(designed, :dom_tree)
    current_handlers = Map.get(designed, :handlers, %{})

    if is_nil(dom_tree) do
      {:error, "No wireframe loaded. Load a wireframe first."}
    else
      {final_handlers, results} =
        Enum.reduce(elements, {current_handlers, []}, fn elem, {handlers_map, acc_results} ->
          element_id = Map.get(elem, "element_id")
          add_handlers = ensure_map(Map.get(elem, "add", %{}))
          replace_handlers = ensure_map(Map.get(elem, "replace", %{}))
          remove_events = ensure_list(Map.get(elem, "remove", []))

          # First validate element exists
          case validate_element_exists(dom_tree, element_id) do
            {:error, msg} ->
              {handlers_map, [{:error, msg} | acc_results]}
            :ok ->
              case update_handlers_in_map(handlers_map, element_id, add_handlers, replace_handlers, remove_events) do
                {:ok, updated_map} ->
                  {updated_map, [{:ok, element_id} | acc_results]}
                {:error, msg} ->
                  {handlers_map, [{:error, msg} | acc_results]}
              end
          end
        end)

      errors = Enum.filter(results, &match?({:error, _}, &1))

      if length(errors) > 0 do
        error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
        {:error, "Errors managing handlers:\n#{error_messages}"}
      else
        count = length(elements)
        {:ok, "Successfully managed handlers on #{count} element(s)", %{handlers: final_handlers}}
      end
    end
  end

  def execute_tool(:manage_handlers, _invalid_params, _designed) do
    {:error, "Invalid params: expected 'elements' array"}
  end

  # ============================================================================
  # Tool: manage_functions
  # Add, remove, or replace JavaScript functions.
  # ============================================================================

  def execute_tool(:manage_functions, args, designed) when is_map(args) do
    current_functions = Map.get(designed, :custom_functions, %{})

    add_functions = ensure_map(Map.get(args, "add_functions", %{}))
    replace_functions = ensure_map(Map.get(args, "replace_functions", %{}))
    remove_functions = ensure_list(Map.get(args, "remove_functions", []))

    updated_functions =
      current_functions
      |> Map.merge(add_functions)
      |> Map.merge(replace_functions)
      |> Map.drop(remove_functions)

    total = map_size(add_functions) + map_size(replace_functions) + length(remove_functions)
    {:ok, "Successfully managed #{total} function(s)", %{custom_functions: updated_functions}}
  end

  def execute_tool(:manage_functions, _invalid_params, _designed) do
    {:error, "Invalid params: expected a map with add_functions, replace_functions, or remove_functions"}
  end

  # ============================================================================
  # Tool: manage_variables
  # Set or remove global JavaScript variables.
  # ============================================================================

  def execute_tool(:manage_variables, args, designed) when is_map(args) do
    current_variables = Map.get(designed, :custom_variables, %{})

    set_variables = ensure_map(Map.get(args, "set_variables", %{}))
    remove_variables = ensure_list(Map.get(args, "remove_variables", []))

    updated_variables =
      current_variables
      |> Map.merge(set_variables)
      |> Map.drop(remove_variables)

    total = map_size(set_variables) + length(remove_variables)
    {:ok, "Successfully managed #{total} variable(s)", %{custom_variables: updated_variables}}
  end

  def execute_tool(:manage_variables, _invalid_params, _designed) do
    {:error, "Invalid params: expected a map with set_variables or remove_variables"}
  end

  # ============================================================================
  # Tool: manage_css
  # Add, remove, or replace CSS rules.
  # All declarations normalized to map format: %{"property" => "value"}
  # ============================================================================

  def execute_tool(:manage_css, args, designed) when is_map(args) do
    current_css = Map.get(designed, :custom_css, %{})

    add_css = Map.get(args, "add", %{}) |> normalize_css_rules()
    replace_css = Map.get(args, "replace", %{}) |> normalize_css_rules()
    remove_selectors = ensure_list(Map.get(args, "remove", []))

    updated_css =
      current_css
      |> Map.merge(add_css)
      |> Map.merge(replace_css)
      |> Map.drop(remove_selectors)

    total = map_size(add_css) + map_size(replace_css) + length(remove_selectors)
    {:ok, "Successfully managed #{total} CSS rule(s)", %{custom_css: updated_css}}
  end

  def execute_tool(:manage_css, _invalid_params, _designed) do
    {:error, "Invalid params: expected a map with add, replace, or remove"}
  end

  # ============================================================================
  # Tool: manage_init_scripts
  # Add, remove, or replace initialization scripts.
  # ============================================================================

  def execute_tool(:manage_init_scripts, args, designed) when is_map(args) do
    current_scripts = Map.get(designed, :init_scripts, %{})

    add_scripts = ensure_map(Map.get(args, "add", %{}))
    replace_scripts = ensure_map(Map.get(args, "replace", %{}))
    remove_scripts = ensure_list(Map.get(args, "remove", []))

    updated_scripts =
      current_scripts
      |> Map.merge(add_scripts)
      |> Map.merge(replace_scripts)
      |> Map.drop(remove_scripts)

    total = map_size(add_scripts) + map_size(replace_scripts) + length(remove_scripts)
    {:ok, "Successfully managed #{total} init script(s)", %{init_scripts: updated_scripts}}
  end

  def execute_tool(:manage_init_scripts, _invalid_params, _designed) do
    {:error, "Invalid params: expected a map with add, replace, or remove"}
  end

  # ============================================================================
  # Tool: trigger_interaction (ephemeral - testing only)
  # Trigger an interaction for testing. Doesn't persist changes.
  # Returns instructions for the adapter to handle via PubSub.
  # ============================================================================

  def execute_tool(:trigger_interaction, args, _designed) do
    action = Map.get(args, "action")
    element_id = Map.get(args, "element_id")

    # Return the interaction request - the adapter will handle the PubSub communication
    {:ok, "Interaction request: #{action} on #{element_id || "page"}", %{_interaction_request: args}}
  end

  # Catch-all for unknown tools
  def execute_tool(tool_name, _params, _designed) do
    {:error, "Unknown tool: #{tool_name}"}
  end

  # ============================================================================
  # CSS Normalization Helpers
  # ============================================================================

  # Normalize CSS rules to map format
  # Accepts both string format ("padding: 20px; margin: 10px") and map format
  # Also handles JSON-encoded strings from LLM responses
  defp normalize_css_rules(rules) when is_map(rules) do
    Map.new(rules, fn {selector, declarations} ->
      {selector, normalize_declarations(declarations)}
    end)
  end

  defp normalize_css_rules(rules) when is_binary(rules) do
    # Try to decode as JSON in case LLM passed a JSON string instead of a map
    case Jason.decode(rules) do
      {:ok, map} when is_map(map) -> normalize_css_rules(map)
      _ -> %{}
    end
  end

  defp normalize_css_rules(_), do: %{}

  defp normalize_declarations(declarations) when is_map(declarations) do
    # Flatten any nested maps (LLM sometimes sends wrong structure)
    Map.new(declarations, fn {prop, value} ->
      case value do
        v when is_binary(v) -> {prop, v}
        v when is_number(v) -> {prop, to_string(v)}
        v when is_map(v) ->
          # Nested map - flatten it by taking first value or converting to string
          flattened = Enum.map_join(v, "; ", fn {p, val} -> "#{p}: #{val}" end)
          {prop, flattened}
        _ -> {prop, inspect(value)}
      end
    end)
  end

  defp normalize_declarations(declarations) when is_binary(declarations) do
    # Parse "padding: 20px; margin: 10px" into %{"padding" => "20px", "margin" => "10px"}
    declarations
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(%{}, fn declaration, acc ->
      case String.split(declaration, ":", parts: 2) do
        [property, value] ->
          Map.put(acc, String.trim(property), String.trim(value))

        _ ->
          acc
      end
    end)
  end

  defp normalize_declarations(_), do: %{}

  # ============================================================================
  # LLM Input Normalization Helpers
  # ============================================================================

  # LLM sometimes sends JSON-encoded strings instead of actual lists/maps.
  # These helpers safely decode them.

  defp ensure_list(value) when is_list(value), do: value

  defp ensure_list(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  defp ensure_list(_), do: []

  defp ensure_map(value) when is_map(value), do: value

  defp ensure_map(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp ensure_map(_), do: %{}

  # ============================================================================
  # Context Building
  # ============================================================================

  @doc """
  Build context blocks for the LLM.

  Returns a list of content blocks:
  - Text block with formatted state information
  - Optional image block with screenshot
  """
  def build_context(designed, running, screenshot) do
    designed_section = build_designed_section(designed)
    running_section = build_running_section(running)

    Log.debug(:context, fn ->
      designed_size = byte_size(designed_section || "")
      running_size = byte_size(running_section || "")
      has_screenshot = screenshot && byte_size(screenshot) > 0
      "[Context] EditorCore - designed: #{designed_size} bytes, running: #{running_size} bytes, screenshot: #{has_screenshot}"
    end)

    context_parts = [
      designed_section,
      running_section,
      # build_tools_guide()
    ]

    text_content = Enum.reject(context_parts, &is_nil/1) |> Enum.join("\n\n")

    blocks = [%{type: "text", text: text_content}]

    # Add screenshot if available
    if screenshot && byte_size(screenshot) > 0 do
      Log.debug(:context, fn ->
        "[Context] EditorCore - screenshot size: #{byte_size(screenshot)} bytes"
      end)
      blocks ++ [build_screenshot_block(screenshot)]
    else
      blocks
    end
  end

  # ============================================================================
  # Private: DOM Tree Manipulation
  # ============================================================================

  defp modify_element_classes(tree, element_id, add_classes, remove_classes) do
    case find_and_update_element(tree, element_id, fn element ->
           current_classes = Map.get(element, :classes, [])

           updated_classes =
             current_classes
             |> Kernel.++(add_classes)
             |> Kernel.--(remove_classes)
             |> Enum.uniq()

           Map.put(element, :classes, updated_classes)
         end) do
      {:ok, updated_tree} -> {:ok, updated_tree}
      {:error, :not_found} -> {:error, "Element '#{element_id}' not found"}
    end
  end

  defp find_and_update_element(%{id: id} = element, target_id, update_fn) when id == target_id do
    {:ok, update_fn.(element)}
  end

  defp find_and_update_element(%{children: children} = element, target_id, update_fn) do
    case update_children(children, target_id, update_fn) do
      {:ok, updated_children} -> {:ok, %{element | children: updated_children}}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp find_and_update_element(_element, _target_id, _update_fn) do
    {:error, :not_found}
  end

  defp update_children(children, target_id, update_fn) do
    {updated_reversed, found} =
      Enum.reduce(children, {[], false}, fn child, {acc, found} ->
        if found do
          {[child | acc], found}
        else
          case find_and_update_element(child, target_id, update_fn) do
            {:ok, updated_child} -> {[updated_child | acc], true}
            {:error, :not_found} -> {[child | acc], false}
          end
        end
      end)

    if found, do: {:ok, Enum.reverse(updated_reversed)}, else: {:error, :not_found}
  end

  # ============================================================================
  # Private: Context Section Builders
  # ============================================================================

  defp build_designed_section(nil), do: "=== DESIGNED STATE ===\n\nNo wireframe loaded."

  defp build_designed_section(designed) do
    dom_tree = Map.get(designed, :dom_tree)
    handlers = Map.get(designed, :handlers, %{})
    init_scripts = Map.get(designed, :init_scripts, %{})
    custom_css = Map.get(designed, :custom_css, %{})
    custom_functions = Map.get(designed, :custom_functions, %{})

    sections = [
      "=== DESIGNED STATE (Source of Truth) ===",
      "",
      "This is what you authored. Changes here persist.",
      "",
      "--- DOM Structure ---",
      format_dom_tree(dom_tree, 0),
      "",
      if(map_size(handlers) > 0, do: "--- Handlers ---\n#{format_handlers(handlers)}", else: nil),
      if(map_size(init_scripts) > 0,
        do: "--- Init Scripts ---\n#{format_init_scripts(init_scripts)}",
        else: nil
      ),
      if(map_size(custom_css) > 0, do: "--- CSS ---\n#{format_css(custom_css)}", else: nil),
      if(map_size(custom_functions) > 0,
        do: "--- Functions ---\n#{format_functions(custom_functions)}",
        else: nil
      )
    ]

    Enum.reject(sections, &is_nil/1) |> Enum.join("\n")
  end

  defp build_running_section(nil), do: nil

  defp build_running_section(running) when running == %{}, do: nil

  defp build_running_section(running) do
    dom_tree = Map.get(running, :dom_tree)
    variables = Map.get(running, :variables, %{})
    console_logs = Map.get(running, :console_logs, [])

    Log.debug(:context, fn ->
      "[Context] Running state - dom: #{if dom_tree, do: "present", else: "nil"}, " <>
        "variables: #{map_size(variables)}, console_logs: #{length(console_logs)}"
    end)

    if length(console_logs) > 0 do
      Log.debug(:context, fn ->
        preview = console_logs |> Enum.take(3) |> inspect(limit: 200)
        "[Context] Console logs sample: #{preview}"
      end)
    end

    if is_nil(dom_tree) do
      nil
    else
      sections = [
        "=== RUNNING STATE (After Init Scripts) ===",
        "",
        "This shows the actual DOM after JavaScript execution.",
        "Includes dynamically created elements.",
        "",
        "--- Live DOM ---",
        format_dom_tree(dom_tree, 0),
        "",
        if(map_size(variables) > 0,
          do: "--- Runtime Variables ---\n#{format_variables(variables)}",
          else: nil
        ),
        if(length(console_logs) > 0,
          do: "--- Console Output ---\n#{format_console(console_logs)}",
          else: nil
        )
      ]

      Enum.reject(sections, &is_nil/1) |> Enum.join("\n")
    end
  end

  defp build_screenshot_block(screenshot) do
    %{
      type: "image",
      source: %{
        type: "base64",
        media_type: "image/png",
        data: screenshot
      }
    }
  end

  # ============================================================================
  # Private: Formatters
  # ============================================================================

  defp format_dom_tree(nil, _indent), do: "(empty)"

  defp format_dom_tree(element, indent) when is_map(element) do
    prefix = String.duplicate("  ", indent)
    # Handle both atom and string keys (designed state uses atoms, running state uses strings from JS)
    id = Map.get(element, :id) || Map.get(element, "id", "?")
    tag = Map.get(element, :tag) || Map.get(element, "tag", "?")
    classes = Map.get(element, :classes) || Map.get(element, "classes", [])
    content = Map.get(element, :content) || Map.get(element, "content")
    children = Map.get(element, :children) || Map.get(element, "children", [])

    class_str = if classes != [], do: ".#{Enum.join(classes, ".")}", else: ""
    content_str = if content && content != "", do: " \"#{content}\"", else: ""

    line = "#{prefix}<#{tag}##{id}#{class_str}>#{content_str}"

    if children != [] do
      child_lines = Enum.map(children, &format_dom_tree(&1, indent + 1))
      [line | child_lines] |> Enum.join("\n")
    else
      line
    end
  end

  defp format_dom_tree(_, _indent), do: "(invalid)"

  defp format_handlers(handlers) do
    Enum.map_join(handlers, "\n", fn {element_id, events} ->
      event_lines = Enum.map_join(events, "\n", fn {event_name, handler_info} ->
        # Handle both atom and string keys
        body = Map.get(handler_info, "body") || Map.get(handler_info, :body, "")
        params = Map.get(handler_info, "params") || Map.get(handler_info, :params, [])
        params_str = if params == [], do: "", else: "(#{Enum.join(params, ", ")})"
        "    #{event_name}#{params_str}: #{body}"
      end)
      "  #{element_id}:\n#{event_lines}"
    end)
  end

  defp format_init_scripts(scripts) do
    Enum.map_join(scripts, "\n", fn {name, code} ->
      "  #{name}: #{code}"
    end)
  end

  defp format_css(css) do
    Enum.map_join(css, "\n", fn {selector, rules} ->
      rules_str = css_rules_to_string(rules)
      "  #{selector} { #{rules_str} }"
    end)
  end

  defp css_rules_to_string(rules) when is_map(rules) do
    Enum.map_join(rules, "; ", fn {prop, val} ->
      "#{prop}: #{css_value_to_string(val)}"
    end)
  end

  defp css_rules_to_string(rules) when is_binary(rules), do: rules
  defp css_rules_to_string(_), do: ""

  # Handle CSS values that might be nested maps (LLM sometimes sends wrong structure)
  defp css_value_to_string(val) when is_binary(val), do: val
  defp css_value_to_string(val) when is_number(val), do: to_string(val)
  defp css_value_to_string(val) when is_map(val) do
    # LLM sent nested map - flatten it
    Enum.map_join(val, "; ", fn {p, v} -> "#{p}: #{css_value_to_string(v)}" end)
  end
  defp css_value_to_string(val), do: inspect(val)

  defp format_functions(functions) do
    Enum.map_join(functions, "\n", fn {name, code} ->
      "  #{name}: #{code}"
    end)
  end

  defp format_variables(variables) do
    Enum.map_join(variables, "\n", fn {name, value} ->
      "  #{name} = #{inspect(value)}"
    end)
  end

  defp format_console(logs) do
    logs
    |> Enum.take(-10)
    |> Enum.map_join("\n", fn log ->
      # Handle both atom and string keys (JS sends string keys)
      level = Map.get(log, :level) || Map.get(log, "level", "log")
      message = Map.get(log, :message) || Map.get(log, "message", "")
      "  [#{level}] #{message}"
    end)
  end


  # ============================================================================
  # Private: modify_elements helpers
  # ============================================================================

  defp process_removals(tree, remove_ids) do
    {final_tree, results} =
      Enum.reduce(remove_ids, {tree, []}, fn id, {current_tree, acc_results} ->
        case remove_element(current_tree, id) do
          {:ok, updated_tree} ->
            {updated_tree, [{:ok, "Removed #{id}"} | acc_results]}

          {:error, :not_found} ->
            {current_tree, [{:error, "Element '#{id}' not found"} | acc_results]}

          {:error, :cannot_remove_root} ->
            {current_tree, [{:error, "Cannot remove root element"} | acc_results]}
        end
      end)

    {final_tree, Enum.reverse(results)}
  end

  defp process_replacements(tree, replacements) do
    {final_tree, results} =
      Enum.reduce(replacements, {tree, []}, fn replacement, {current_tree, acc_results} ->
        element_id = Map.get(replacement, "element_id")
        new_element_spec = Map.get(replacement, "new_element")

        # Find the old element to preserve its children if not specified in new_element
        old_element = find_element_by_id(current_tree, element_id)

        # Preserve children from old element if new_element doesn't specify children
        merged_spec =
          case {Map.get(new_element_spec, "children"), old_element} do
            {nil, %{children: old_children}} when old_children != [] ->
              Map.put(new_element_spec, "children", convert_elements_to_specs(old_children))

            _ ->
              new_element_spec
          end

        # Collect all existing IDs from the tree for uniqueness checking
        used_ids = collect_all_ids(current_tree)

        # Build element with auto-generated IDs for children without IDs
        {new_element, _counter} = build_element_from_spec_with_ids(merged_spec, used_ids, 1)

        case replace_element(current_tree, element_id, new_element) do
          {:ok, updated_tree} ->
            {updated_tree, [{:ok, "Replaced #{element_id}"} | acc_results]}

          {:error, :not_found} ->
            {current_tree, [{:error, "Element '#{element_id}' not found"} | acc_results]}

          {:error, :cannot_replace_root} ->
            {current_tree, [{:error, "Cannot replace root element"} | acc_results]}
        end
      end)

    {final_tree, Enum.reverse(results)}
  end

  defp process_additions(tree, additions) do
    {final_tree, results} =
      Enum.reduce(additions, {tree, []}, fn addition, {current_tree, acc_results} ->
        parent_id = Map.get(addition, "parent_id")
        position = Map.get(addition, "position", "last")
        reference_id = Map.get(addition, "reference_id")

        # Collect all existing IDs from the tree for uniqueness checking
        used_ids = collect_all_ids(current_tree)

        # Build element with auto-generated IDs for children without IDs
        {new_element, _counter} = build_element_from_spec_with_ids(addition, used_ids, 1)

        case add_element(current_tree, parent_id, new_element, position, reference_id) do
          {:ok, updated_tree} ->
            {updated_tree, [{:ok, "Added #{new_element.id}"} | acc_results]}

          {:error, :parent_not_found} ->
            {current_tree, [{:error, "Parent element '#{parent_id}' not found"} | acc_results]}

          {:error, :duplicate_id} ->
            {current_tree,
             [{:error, "Element with ID '#{new_element.id}' already exists"} | acc_results]}

          {:error, :reference_not_found} ->
            {current_tree,
             [{:error, "Reference element '#{reference_id}' not found in parent"} | acc_results]}
        end
      end)

    {final_tree, Enum.reverse(results)}
  end

  # Extract handlers from DOM tree into flat map (element_id => handlers)
  defp extract_handlers_from_tree(element) when is_map(element) do
    # Get handlers from this element if present
    element_handlers =
      case {Map.get(element, :id), Map.get(element, :handlers)} do
        {id, handlers} when is_binary(id) and is_map(handlers) and map_size(handlers) > 0 ->
          normalized_handlers = normalize_handler_keys(handlers)
          %{id => normalized_handlers}

        _ ->
          %{}
      end

    # Recursively extract from children
    children = Map.get(element, :children, [])

    child_handlers =
      Enum.reduce(children, %{}, fn child, acc ->
        Map.merge(acc, extract_handlers_from_tree(child))
      end)

    Map.merge(child_handlers, element_handlers)
  end

  defp extract_handlers_from_tree(_), do: %{}

  # Normalize handler keys to strings (LLM sends JSON = always strings)
  defp normalize_handler_keys(handlers) when is_map(handlers) do
    Enum.reduce(handlers, %{}, fn {event, handler_info}, acc ->
      string_event = to_string(event)

      normalized_info =
        case handler_info do
          %{"params" => params, "body" => body} -> %{"params" => params, "body" => body}
          %{params: params, body: body} -> %{"params" => params, "body" => body}
          %{} = map -> Map.new(map, fn {k, v} -> {to_string(k), v} end)
          other -> other
        end

      Map.put(acc, string_event, normalized_info)
    end)
  end

  defp normalize_handler_keys(handlers), do: handlers

  # ============================================================================
  # Private: manage_attributes helpers
  # ============================================================================

  defp modify_element_attributes(tree, element_id, set_attrs, remove_attrs) do
    case find_and_update_element(tree, element_id, fn element ->
           current_attrs = Map.get(element, :attributes, %{})

           updated_attrs =
             current_attrs
             |> Map.merge(set_attrs)
             |> Map.drop(remove_attrs)

           Map.put(element, :attributes, updated_attrs)
         end) do
      {:ok, updated_tree} -> {:ok, updated_tree}
      {:error, :not_found} -> {:error, "Element '#{element_id}' not found"}
    end
  end

  # ============================================================================
  # Private: manage_handlers helpers
  # ============================================================================

  defp validate_element_exists(tree, element_id) do
    if element_exists?(tree, element_id) do
      :ok
    else
      {:error, "Element '#{element_id}' not found"}
    end
  end

  defp update_handlers_in_map(handlers_map, element_id, add_handlers, replace_handlers, remove_events) do
    current_element_handlers = Map.get(handlers_map, element_id, %{})

    # Normalize handler keys to strings for consistency (LLM sends JSON = strings)
    add_handlers_normalized = normalize_handler_keys(add_handlers)
    replace_handlers_normalized = normalize_handler_keys(replace_handlers)
    current_normalized = normalize_handler_keys(current_element_handlers)

    # Keep remove_events as strings
    remove_events_normalized = Enum.map(remove_events, &to_string/1)

    # Check add conflicts
    add_conflicts =
      Enum.filter(Map.keys(add_handlers_normalized), &Map.has_key?(current_normalized, &1))

    if length(add_conflicts) > 0 do
      {:error,
       "Handler already exists for events: #{Enum.join(add_conflicts, ", ")} on element '#{element_id}'"}
    else
      # Check replace requirements
      replace_missing =
        Enum.filter(
          Map.keys(replace_handlers_normalized),
          &(!Map.has_key?(current_normalized, &1))
        )

      if length(replace_missing) > 0 do
        {:error,
         "No existing handler to replace for events: #{Enum.join(replace_missing, ", ")} on element '#{element_id}'"}
      else
        # Update element's handlers (all string keys now)
        updated_element_handlers =
          current_normalized
          |> Map.merge(add_handlers_normalized)
          |> Map.merge(replace_handlers_normalized)
          |> Map.drop(remove_events_normalized)

        # Update the map (remove element key if no handlers left)
        updated_map =
          if map_size(updated_element_handlers) > 0 do
            Map.put(handlers_map, element_id, updated_element_handlers)
          else
            Map.delete(handlers_map, element_id)
          end

        {:ok, updated_map}
      end
    end
  end

  # ============================================================================
  # Private: DOM Tree Operations
  # ============================================================================

  defp remove_element(%{id: id}, target_id) when id == target_id do
    {:error, :cannot_remove_root}
  end

  defp remove_element(%{children: children} = element, target_id) do
    case remove_from_children(children, target_id) do
      {:ok, updated_children} -> {:ok, %{element | children: updated_children}}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp remove_element(_element, _target_id) do
    {:error, :not_found}
  end

  defp remove_from_children(children, target_id) do
    {updated_reversed, found} =
      Enum.reduce(children, {[], false}, fn child, {acc, found} ->
        cond do
          found ->
            {[child | acc], found}

          child.id == target_id ->
            {acc, true}

          true ->
            case remove_element(child, target_id) do
              {:ok, updated_child} -> {[updated_child | acc], true}
              {:error, :not_found} -> {[child | acc], false}
            end
        end
      end)

    if found, do: {:ok, Enum.reverse(updated_reversed)}, else: {:error, :not_found}
  end

  defp replace_element(%{id: id}, target_id, _new_element) when id == target_id do
    {:error, :cannot_replace_root}
  end

  defp replace_element(%{children: children} = element, target_id, new_element) do
    case replace_in_children(children, target_id, new_element) do
      {:ok, updated_children} -> {:ok, %{element | children: updated_children}}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp replace_element(_element, _target_id, _new_element) do
    {:error, :not_found}
  end

  defp replace_in_children(children, target_id, new_element) do
    {updated_reversed, found} =
      Enum.reduce(children, {[], false}, fn child, {acc, found} ->
        cond do
          found ->
            {[child | acc], found}

          child.id == target_id ->
            {[new_element | acc], true}

          true ->
            case replace_element(child, target_id, new_element) do
              {:ok, updated_child} -> {[updated_child | acc], true}
              {:error, :not_found} -> {[child | acc], false}
            end
        end
      end)

    if found, do: {:ok, Enum.reverse(updated_reversed)}, else: {:error, :not_found}
  end

  defp add_element(%{id: id, children: children} = element, parent_id, new_element, position, reference_id)
       when id == parent_id do
    if element_exists?(element, new_element.id) do
      {:error, :duplicate_id}
    else
      case insert_at_position(children, new_element, position, reference_id) do
        {:ok, updated_children} -> {:ok, %{element | children: updated_children}}
        error -> error
      end
    end
  end

  defp add_element(%{children: children} = element, parent_id, new_element, position, reference_id) do
    case add_to_children(children, parent_id, new_element, position, reference_id) do
      {:ok, updated_children} -> {:ok, %{element | children: updated_children}}
      error -> error
    end
  end

  defp add_element(_element, _parent_id, _new_element, _position, _reference_id) do
    {:error, :parent_not_found}
  end

  defp add_to_children(children, parent_id, new_element, position, reference_id) do
    {updated_reversed, found} =
      Enum.reduce(children, {[], false}, fn child, {acc, found} ->
        if found do
          {[child | acc], found}
        else
          case add_element(child, parent_id, new_element, position, reference_id) do
            {:ok, updated_child} -> {[updated_child | acc], true}
            {:error, :parent_not_found} -> {[child | acc], false}
            error -> throw(error)
          end
        end
      end)

    if found, do: {:ok, Enum.reverse(updated_reversed)}, else: {:error, :parent_not_found}
  catch
    error -> error
  end

  defp insert_at_position(children, new_element, "first", _reference_id) do
    {:ok, [new_element | children]}
  end

  defp insert_at_position(children, new_element, "last", _reference_id) do
    {:ok, children ++ [new_element]}
  end

  defp insert_at_position(children, new_element, "before", reference_id)
       when not is_nil(reference_id) do
    case find_index_by_id(children, reference_id) do
      {:ok, index} -> {:ok, List.insert_at(children, index, new_element)}
      :not_found -> {:error, :reference_not_found}
    end
  end

  defp insert_at_position(children, new_element, "after", reference_id)
       when not is_nil(reference_id) do
    case find_index_by_id(children, reference_id) do
      {:ok, index} -> {:ok, List.insert_at(children, index + 1, new_element)}
      :not_found -> {:error, :reference_not_found}
    end
  end

  defp insert_at_position(_children, _new_element, _position, _reference_id) do
    {:error, :invalid_position}
  end

  defp find_index_by_id(children, target_id) do
    children
    |> Enum.with_index()
    |> Enum.find_value(fn {child, index} ->
      if Map.get(child, :id) == target_id, do: {:ok, index}
    end)
    |> case do
      {:ok, _index} = result -> result
      nil -> :not_found
    end
  end

  defp element_exists?(%{id: id}, target_id) when id == target_id, do: true

  defp element_exists?(%{children: children}, target_id) do
    Enum.any?(children, &element_exists?(&1, target_id))
  end

  defp element_exists?(_, _), do: false

  # ============================================================================
  # Private: Element Building from Specs
  # ============================================================================

  defp build_element_from_spec_with_ids(spec, used_ids, counter) do
    tag = Map.get(spec, "tag")

    # Generate ID if not provided
    {element_id, updated_used_ids} =
      case Map.get(spec, "id") do
        nil ->
          base_id = "auto-#{tag}-#{counter}"
          unique_id = ensure_unique_id(base_id, used_ids)
          {unique_id, MapSet.put(used_ids, unique_id)}

        provided_id ->
          {provided_id, MapSet.put(used_ids, provided_id)}
      end

    # Recursively build children with auto-IDs
    {children, final_counter} =
      case Map.get(spec, "children") do
        child_specs when is_list(child_specs) ->
          {built_children, child_counter} =
            Enum.reduce(child_specs, {[], counter + 1}, fn child_spec, {acc_children, current_counter} ->
              {child_element, next_counter} =
                build_element_from_spec_with_ids(child_spec, updated_used_ids, current_counter)

              {acc_children ++ [child_element], next_counter}
            end)

          {built_children, child_counter}

        _ ->
          {[], counter + 1}
      end

    element = %{
      tag: tag,
      id: element_id,
      content: Map.get(spec, "content"),
      classes: Map.get(spec, "classes", []),
      attributes: Map.get(spec, "attributes", %{}),
      handlers: Map.get(spec, "handlers", %{}),
      children: children
    }

    {element, final_counter}
  end

  defp collect_all_ids(element) when is_map(element) do
    child_ids =
      element
      |> Map.get(:children, [])
      |> Enum.reduce(MapSet.new(), fn child, acc ->
        MapSet.union(acc, collect_all_ids(child))
      end)

    case Map.get(element, :id) do
      nil -> child_ids
      id -> MapSet.put(child_ids, id)
    end
  end

  defp collect_all_ids(_), do: MapSet.new()

  defp ensure_unique_id(proposed_id, used_ids) do
    if MapSet.member?(used_ids, proposed_id) do
      find_unique_variant(proposed_id, used_ids, 1)
    else
      proposed_id
    end
  end

  defp find_unique_variant(base_id, used_ids, suffix) do
    candidate = "#{base_id}-#{suffix}"

    if MapSet.member?(used_ids, candidate) do
      find_unique_variant(base_id, used_ids, suffix + 1)
    else
      candidate
    end
  end

  defp find_element_by_id(%{id: id} = element, target_id) when id == target_id, do: element

  defp find_element_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child -> find_element_by_id(child, target_id) end)
  end

  defp find_element_by_id(_, _target_id), do: nil

  defp convert_elements_to_specs(elements) when is_list(elements) do
    Enum.map(elements, &convert_element_to_spec/1)
  end

  defp convert_element_to_spec(%{} = element) do
    %{
      "tag" => Map.get(element, :tag),
      "id" => Map.get(element, :id),
      "content" => Map.get(element, :content),
      "classes" => Map.get(element, :classes, []),
      "attributes" => Map.get(element, :attributes, %{}),
      "handlers" => Map.get(element, :handlers, %{}),
      "children" => convert_elements_to_specs(Map.get(element, :children, []))
    }
  end
end
