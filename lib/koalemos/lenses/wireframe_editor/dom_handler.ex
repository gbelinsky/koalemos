defmodule Koalemos.Lenses.WireframeEditor.DOMHandler do
  @moduledoc """
  DOM manipulation operations for WireframeEditor.

  Implements all 9 wireframe editing tools:
  - Structure tools: modify_classes, modify_elements, manage_attributes
  - Behavior tools: manage_handlers, manage_functions, manage_variables, manage_css, manage_init_scripts
  - Testing tool: trigger_interaction

  Uses existing HTMLParser for parsing, implements tree manipulation and serialization.
  """

  # TODO: Will be used when tools are fully implemented
  # alias Koalemos.Parsers.HTMLParser
  # alias Koalemos.Caches.DOMStateCache
  require Logger

  @doc """
  Modify CSS classes on one or more elements (batch operation).

  Returns {result_text, lens_updates}.
  """
  def modify_classes(lens_state, %{"elements" => elements}) do
    designed = Map.get(lens_state, :designed, %{})
    dom_tree = Map.get(designed, :dom_tree)

    if is_nil(dom_tree) do
      {"Error: No wireframe loaded. Load a wireframe first.", []}
    else
      # Thread updated tree through each modification using reduce
      {final_tree, results} = Enum.reduce(elements, {dom_tree, []}, fn elem, {current_tree, acc_results} ->
        element_id = Map.get(elem, "element_id")
        add_classes = Map.get(elem, "add_classes", [])
        remove_classes = Map.get(elem, "remove_classes", [])

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
        {"Errors modifying classes:\n#{error_messages}", []}
      else
        updated_tree = final_tree

        # Track modification
        modification = %{
          type: :modify_classes,
          elements: Enum.map(elements, & &1["element_id"]),
          timestamp: DateTime.utc_now()
        }

        updated_designed = %{designed | dom_tree: updated_tree}
        modifications = [modification | Map.get(lens_state, :modifications, [])]

        count = length(elements)
        {"Successfully modified classes on #{count} element(s)", [
          designed: updated_designed,
          modifications: modifications
        ]}
      end
    end
  end

  @doc """
  Add, remove, or replace elements (batch operation).

  Returns {result_text, lens_updates}.
  """
  def modify_elements(lens_state, args) do
    designed = Map.get(lens_state, :designed, %{})
    dom_tree = Map.get(designed, :dom_tree)

    if is_nil(dom_tree) do
      {"Error: No wireframe loaded. Load a wireframe first.", []}
    else
      # Validate args structure before processing
      case validate_modify_elements_args(args) do
        :ok ->
          # Process in order: remove, replace, add
          updated_tree = dom_tree

          # Remove elements
          remove_ids = Map.get(args, "remove_elements", [])
          {updated_tree, remove_results} = process_removals(updated_tree, remove_ids)

          # Replace elements
          replacements = Map.get(args, "replace_elements", [])
          {updated_tree, replace_results} = process_replacements(updated_tree, replacements)

          # Add elements
          additions = Map.get(args, "add_elements", [])
          {updated_tree, add_results} = process_additions(updated_tree, additions)

          # Collect results
          all_results = remove_results ++ replace_results ++ add_results
          errors = Enum.filter(all_results, &match?({:error, _}, &1))

          if length(errors) > 0 do
            error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
            {"Errors modifying elements:\n#{error_messages}", []}
          else
            # Track modification
            modification = %{
              type: :modify_elements,
              removed: length(remove_ids),
              replaced: length(replacements),
              added: length(additions),
              timestamp: DateTime.utc_now()
            }

            updated_designed = %{designed | dom_tree: updated_tree}
            modifications = [modification | Map.get(lens_state, :modifications, [])]

            total = length(remove_ids) + length(replacements) + length(additions)
            {"Successfully modified #{total} element(s)", [
              designed: updated_designed,
              modifications: modifications
            ]}
          end

        {:error, error_message} ->
          {error_message, []}
      end
    end
  end

  @doc """
  Manage HTML attributes on elements (rejects 'class' - use modify_classes instead).

  Returns {result_text, lens_updates}.
  """
  def manage_attributes(lens_state, %{"elements" => elements}) do
    designed = Map.get(lens_state, :designed, %{})
    dom_tree = Map.get(designed, :dom_tree)

    if is_nil(dom_tree) do
      {"Error: No wireframe loaded. Load a wireframe first.", []}
    else
      # Validate no 'class' attribute
      has_class_attr = Enum.any?(elements, fn elem ->
        set_attrs = Map.get(elem, "set", %{})
        Map.has_key?(set_attrs, "class")
      end)

      if has_class_attr do
        {"Error: Cannot set 'class' attribute. Use modify_classes tool instead.", []}
      else
        # Thread updated tree through each modification using reduce
        {final_tree, results} = Enum.reduce(elements, {dom_tree, []}, fn elem, {current_tree, acc_results} ->
          element_id = Map.get(elem, "element_id")
          set_attrs = Map.get(elem, "set", %{})
          remove_attrs = Map.get(elem, "remove", [])

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
          {"Errors managing attributes:\n#{error_messages}", []}
        else
          updated_tree = final_tree

          modification = %{
            type: :manage_attributes,
            elements: Enum.map(elements, & &1["element_id"]),
            timestamp: DateTime.utc_now()
          }

          updated_designed = %{designed | dom_tree: updated_tree}
          modifications = [modification | Map.get(lens_state, :modifications, [])]

          count = length(elements)
          {"Successfully managed attributes on #{count} element(s)", [
            designed: updated_designed,
            modifications: modifications
          ]}
        end
      end
    end
  end

  @doc """
  Manage event handlers on elements.

  Returns {result_text, lens_updates}.
  """
  def manage_handlers(lens_state, %{"elements" => elements}) do
    designed = Map.get(lens_state, :designed, %{})
    dom_tree = Map.get(designed, :dom_tree)
    current_handlers = Map.get(designed, :handlers, %{})

    if is_nil(dom_tree) do
      {"Error: No wireframe loaded. Load a wireframe first.", []}
    else
      # Single source of truth: only modify designed.handlers (flat map)
      # No need to touch DOM tree - handlers live only in the flat map
      {final_handlers, results} = Enum.reduce(elements, {current_handlers, []},
        fn elem, {handlers_map, acc_results} ->
          element_id = Map.get(elem, "element_id")
          add_handlers = Map.get(elem, "add", %{})
          replace_handlers = Map.get(elem, "replace", %{})
          remove_events = Map.get(elem, "remove", [])

          # First validate element exists in DOM tree
          case validate_element_exists(dom_tree, element_id) do
            {:error, msg} ->
              {handlers_map, [{:error, msg} | acc_results]}

            :ok ->
              # Update handlers in flat map
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
        {"Errors managing handlers:\n#{error_messages}", []}
      else
        modification = %{
          type: :manage_handlers,
          elements: Enum.map(elements, & &1["element_id"]),
          timestamp: DateTime.utc_now()
        }

        updated_designed = Map.put(designed, :handlers, final_handlers)
        modifications = [modification | Map.get(lens_state, :modifications, [])]

        count = length(elements)
        {"Successfully managed handlers on #{count} element(s)", [
          designed: updated_designed,
          modifications: modifications
        ]}
      end
    end
  end

  @doc """
  Add, remove, or replace JavaScript functions.

  Returns {result_text, lens_updates}.
  """
  def manage_functions(lens_state, args) do
    designed = Map.get(lens_state, :designed, %{})
    current_functions = Map.get(designed, :custom_functions, %{})

    # Add functions
    add_functions = Map.get(args, "add_functions", %{})

    # Validate add functions
    case validate_functions(add_functions) do
      {:error, {name, error}} ->
        {"Error: Function '#{name}' has invalid JavaScript syntax: #{error}", []}

      :ok ->
        # Replace functions
        replace_functions = Map.get(args, "replace_functions", %{})

        # Validate replace functions
        case validate_functions(replace_functions) do
          {:error, {name, error}} ->
            {"Error: Function '#{name}' has invalid JavaScript syntax: #{error}", []}

          :ok ->
            # All valid - proceed with updates
            updated_functions = current_functions
              |> Map.merge(add_functions)
              |> Map.merge(replace_functions)

            # Remove functions
            remove_functions = Map.get(args, "remove_functions", [])
            updated_functions = Map.drop(updated_functions, remove_functions)

            modification = %{
              type: :manage_functions,
              added: map_size(add_functions),
              replaced: map_size(replace_functions),
              removed: length(remove_functions),
              timestamp: DateTime.utc_now()
            }

            updated_designed = %{designed | custom_functions: updated_functions}
            modifications = [modification | Map.get(lens_state, :modifications, [])]

            total = map_size(add_functions) + map_size(replace_functions) + length(remove_functions)
            {"Successfully managed #{total} function(s)", [
              designed: updated_designed,
              modifications: modifications
            ]}
        end
    end
  end

  @doc """
  Set or remove global JavaScript variables.

  Returns {result_text, lens_updates}.
  """
  def manage_variables(lens_state, args) do
    designed = Map.get(lens_state, :designed, %{})
    current_variables = Map.get(designed, :custom_variables, %{})

    # Set variables
    set_variables = Map.get(args, "set_variables", %{})
    updated_variables = Map.merge(current_variables, set_variables)

    # Remove variables
    remove_variables = Map.get(args, "remove_variables", [])
    updated_variables = Map.drop(updated_variables, remove_variables)

    modification = %{
      type: :manage_variables,
      set: map_size(set_variables),
      removed: length(remove_variables),
      timestamp: DateTime.utc_now()
    }

    updated_designed = %{designed | custom_variables: updated_variables}
    modifications = [modification | Map.get(lens_state, :modifications, [])]

    total = map_size(set_variables) + length(remove_variables)
    {"Successfully managed #{total} variable(s)", [
      designed: updated_designed,
      modifications: modifications
    ]}
  end

  @doc """
  Add, remove, or replace custom CSS rules.

  Returns {result_text, lens_updates}.
  """
  def manage_css(lens_state, args) do
    designed = Map.get(lens_state, :designed, %{})
    current_css = Map.get(designed, :custom_css, %{})

    # Add CSS
    add_css = Map.get(args, "add", %{})
    updated_css = Map.merge(current_css, add_css)

    # Replace CSS
    replace_css = Map.get(args, "replace", %{})
    updated_css = Map.merge(updated_css, replace_css)

    # Remove CSS
    remove_selectors = Map.get(args, "remove", [])
    updated_css = Map.drop(updated_css, remove_selectors)

    modification = %{
      type: :manage_css,
      added: map_size(add_css),
      replaced: map_size(replace_css),
      removed: length(remove_selectors),
      timestamp: DateTime.utc_now()
    }

    # Include dom_tree in update so broadcast happens (even though CSS doesn't modify tree)
    updated_designed = designed
      |> Map.put(:custom_css, updated_css)
      |> Map.put(:dom_tree, Map.get(designed, :dom_tree))  # Include tree for broadcast

    modifications = [modification | Map.get(lens_state, :modifications, [])]

    total = map_size(add_css) + map_size(replace_css) + length(remove_selectors)
    {"Successfully managed #{total} CSS rule(s)", [
      designed: updated_designed,
      modifications: modifications
    ]}
  end

  @doc """
  Add, remove, or replace initialization scripts.

  Returns {result_text, lens_updates}.
  """
  def manage_init_scripts(lens_state, args) do
    designed = Map.get(lens_state, :designed, %{})
    current_scripts = Map.get(designed, :init_scripts, %{})

    # Add scripts
    add_scripts = Map.get(args, "add", %{})

    # Validate add scripts
    case validate_init_scripts(add_scripts) do
      {:error, {name, error}} ->
        {"Error: Init script '#{name}' has invalid JavaScript syntax: #{error}", []}

      :ok ->
        # Replace scripts
        replace_scripts = Map.get(args, "replace", %{})

        # Validate replace scripts
        case validate_init_scripts(replace_scripts) do
          {:error, {name, error}} ->
            {"Error: Init script '#{name}' has invalid JavaScript syntax: #{error}", []}

          :ok ->
            # All valid - proceed with updates
            updated_scripts = current_scripts
              |> Map.merge(add_scripts)
              |> Map.merge(replace_scripts)

            # Remove scripts
            remove_scripts = Map.get(args, "remove", [])
            updated_scripts = Map.drop(updated_scripts, remove_scripts)

            modification = %{
              type: :manage_init_scripts,
              added: map_size(add_scripts),
              replaced: map_size(replace_scripts),
              removed: length(remove_scripts),
              timestamp: DateTime.utc_now()
            }

            # Include dom_tree in update so broadcast happens (triggers reload in preview)
            # IMPORTANT: Preserve all other fields (handlers, css, functions, variables)
            updated_designed = designed
              |> Map.put(:init_scripts, updated_scripts)
              |> Map.put(:dom_tree, Map.get(designed, :dom_tree))

            require Logger
            Logger.debug("[manage_init_scripts] Before update - handlers present? #{inspect(Map.has_key?(designed, :handlers))}")
            Logger.debug("[manage_init_scripts] After update - handlers present? #{inspect(Map.has_key?(updated_designed, :handlers))}")
            Logger.debug("[manage_init_scripts] Handler count: #{map_size(Map.get(updated_designed, :handlers, %{}))}")

            modifications = [modification | Map.get(lens_state, :modifications, [])]

            total = map_size(add_scripts) + map_size(replace_scripts) + length(remove_scripts)
            {"Successfully managed #{total} init script(s)", [
              designed: updated_designed,
              modifications: modifications
            ]}
        end
    end
  end

  @doc """
  Trigger interactions for testing (EPHEMERAL - changes not persisted).

  Returns {result_text, lens_updates}.
  """
  def trigger_interaction(_lens_state, args, _context) do
    # TODO: Implement interaction with preview iframe
    # For now, return placeholder response
    action = Map.get(args, "action")
    element_id = Map.get(args, "element_id")

    """
    Triggered interaction: #{action} on #{element_id || "page"}

    NOTE: This is a TESTING tool - changes are EPHEMERAL and won't persist to design.
    Check the LIVE DOM STATE in context to see what happened.
    For PERMANENT changes, use the design tools (modify_elements, manage_handlers, etc.).
    """
    |> then(&{&1, []})
  end

  # Private helper functions

  # Validate modify_elements args structure
  defp validate_modify_elements_args(args) when not is_map(args) do
    {:error, "Error: Invalid arguments - expected a map but received: #{inspect(args)}"}
  end

  defp validate_modify_elements_args(args) do
    # Check remove_elements if present
    with :ok <- validate_array_field(args, "remove_elements", "element IDs"),
         :ok <- validate_array_field(args, "replace_elements", "replacement specs"),
         :ok <- validate_array_field(args, "add_elements", "addition specs") do
      :ok
    end
  end

  # Validate that a field (if present) is an array/list
  defp validate_array_field(args, field_name, description) do
    case Map.get(args, field_name) do
      nil ->
        :ok
      value when is_list(value) ->
        :ok
      value ->
        {:error, "Error: Invalid '#{field_name}' - expected array of #{description}, got: #{inspect(value)}"}
    end
  end

  defp modify_element_classes(tree, element_id, add_classes, remove_classes) do
    case find_and_update_element(tree, element_id, fn element ->
      current_classes = Map.get(element, :classes, [])
      updated_classes = current_classes
        |> Kernel.++(add_classes)
        |> Kernel.--(remove_classes)
        |> Enum.uniq()

      Map.put(element, :classes, updated_classes)
    end) do
      {:ok, updated_tree} -> {:ok, updated_tree}
      {:error, :not_found} -> {:error, "Element '#{element_id}' not found"}
    end
  end

  defp modify_element_attributes(tree, element_id, set_attrs, remove_attrs) do
    case find_and_update_element(tree, element_id, fn element ->
      current_attrs = Map.get(element, :attributes, %{})
      updated_attrs = current_attrs
        |> Map.merge(set_attrs)
        |> Map.drop(remove_attrs)

      Map.put(element, :attributes, updated_attrs)
    end) do
      {:ok, updated_tree} -> {:ok, updated_tree}
      {:error, :not_found} -> {:error, "Element '#{element_id}' not found"}
    end
  end

  # Validate element exists in DOM tree (read-only check)
  defp validate_element_exists(tree, element_id) do
    if element_exists?(tree, element_id) do
      :ok
    else
      {:error, "Element '#{element_id}' not found"}
    end
  end

  # Update handlers in flat map only (single source of truth)
  defp update_handlers_in_map(handlers_map, element_id, add_handlers, replace_handlers, remove_events) do
    current_element_handlers = Map.get(handlers_map, element_id, %{})

    # Convert incoming handler keys to atoms for consistency
    add_handlers_atom = atomize_handler_keys(add_handlers)
    replace_handlers_atom = atomize_handler_keys(replace_handlers)
    remove_events_atom = Enum.map(remove_events, fn
      event when is_binary(event) -> String.to_atom(event)
      event -> event
    end)

    # Check add conflicts
    add_conflicts = Enum.filter(Map.keys(add_handlers_atom), &Map.has_key?(current_element_handlers, &1))
    if length(add_conflicts) > 0 do
      {:error, "Handler already exists for events: #{Enum.join(add_conflicts, ", ")} on element '#{element_id}'"}
    else
      # Check replace requirements
      replace_missing = Enum.filter(Map.keys(replace_handlers_atom), &(!Map.has_key?(current_element_handlers, &1)))
      if length(replace_missing) > 0 do
        {:error, "No existing handler to replace for events: #{Enum.join(replace_missing, ", ")} on element '#{element_id}'"}
      else
        # Update element's handlers
        updated_element_handlers = current_element_handlers
          |> Map.merge(add_handlers_atom)
          |> Map.merge(replace_handlers_atom)
          |> Map.drop(remove_events_atom)

        # Update the map (remove element key if no handlers left)
        updated_map = if map_size(updated_element_handlers) > 0 do
          Map.put(handlers_map, element_id, updated_element_handlers)
        else
          Map.delete(handlers_map, element_id)
        end

        {:ok, updated_map}
      end
    end
  end

  defp process_removals(tree, remove_ids) do
    {final_tree, results} = Enum.reduce(remove_ids, {tree, []}, fn id, {current_tree, acc_results} ->
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
    {final_tree, results} = Enum.reduce(replacements, {tree, []}, fn replacement, {current_tree, acc_results} ->
      element_id = Map.get(replacement, "element_id")
      new_element_spec = Map.get(replacement, "new_element")

      # Collect all existing IDs from the tree for uniqueness checking
      used_ids = collect_all_ids(current_tree)

      # Build element with auto-generated IDs for children without IDs
      {new_element, _counter} = build_element_from_spec_with_ids(new_element_spec, used_ids, 1)

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
    {final_tree, results} = Enum.reduce(additions, {tree, []}, fn addition, {current_tree, acc_results} ->
      parent_id = Map.get(addition, "parent_id")

      # Collect all existing IDs from the tree for uniqueness checking
      used_ids = collect_all_ids(current_tree)

      # Build element with auto-generated IDs for children without IDs
      {new_element, _counter} = build_element_from_spec_with_ids(addition, used_ids, 1)

      case add_element(current_tree, parent_id, new_element) do
        {:ok, updated_tree} ->
          {updated_tree, [{:ok, "Added #{new_element.id}"} | acc_results]}
        {:error, :parent_not_found} ->
          {current_tree, [{:error, "Parent element '#{parent_id}' not found"} | acc_results]}
        {:error, :duplicate_id} ->
          {current_tree, [{:error, "Element with ID '#{new_element.id}' already exists"} | acc_results]}
      end
    end)

    {final_tree, Enum.reverse(results)}
  end

  # Build element from spec WITH auto-ID generation for children
  defp build_element_from_spec_with_ids(spec, used_ids, counter) do
    tag = Map.get(spec, "tag")

    # Generate ID if not provided
    {element_id, updated_used_ids} = case Map.get(spec, "id") do
      nil ->
        # Auto-generate ID
        base_id = "auto-#{tag}-#{counter}"
        unique_id = ensure_unique_id(base_id, used_ids)
        {unique_id, MapSet.put(used_ids, unique_id)}

      provided_id ->
        {provided_id, MapSet.put(used_ids, provided_id)}
    end

    # Recursively build children with auto-IDs
    {children, final_counter} = case Map.get(spec, "children") do
      child_specs when is_list(child_specs) ->
        {built_children, child_counter} = Enum.reduce(child_specs, {[], counter + 1}, fn child_spec, {acc_children, current_counter} ->
          {child_element, next_counter} = build_element_from_spec_with_ids(child_spec, updated_used_ids, current_counter)
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

  # Collect all IDs in the tree into a MapSet
  defp collect_all_ids(element) when is_map(element) do
    child_ids = element
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

  # Ensure ID is unique by appending -1, -2, etc. if needed
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
    {updated, found} = Enum.reduce(children, {[], false}, fn child, {acc, found} ->
      if found do
        {acc ++ [child], found}
      else
        case find_and_update_element(child, target_id, update_fn) do
          {:ok, updated_child} -> {acc ++ [updated_child], true}
          {:error, :not_found} -> {acc ++ [child], false}
        end
      end
    end)

    if found, do: {:ok, updated}, else: {:error, :not_found}
  end

  defp remove_element(%{id: id} = _element, target_id) when id == target_id do
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
    {updated, found} = Enum.reduce(children, {[], false}, fn child, {acc, found} ->
      cond do
        found -> {acc ++ [child], found}
        child.id == target_id -> {acc, true}
        true ->
          case remove_element(child, target_id) do
            {:ok, updated_child} -> {acc ++ [updated_child], true}
            {:error, :not_found} -> {acc ++ [child], false}
          end
      end
    end)

    if found, do: {:ok, updated}, else: {:error, :not_found}
  end

  defp replace_element(%{id: id} = _element, target_id, _new_element) when id == target_id do
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
    {updated, found} = Enum.reduce(children, {[], false}, fn child, {acc, found} ->
      cond do
        found -> {acc ++ [child], found}
        child.id == target_id -> {acc ++ [new_element], true}
        true ->
          case replace_element(child, target_id, new_element) do
            {:ok, updated_child} -> {acc ++ [updated_child], true}
            {:error, :not_found} -> {acc ++ [child], false}
          end
      end
    end)

    if found, do: {:ok, updated}, else: {:error, :not_found}
  end

  defp add_element(%{id: id, children: children} = element, parent_id, new_element) when id == parent_id do
    # Check for duplicate ID
    if element_exists?(element, new_element.id) do
      {:error, :duplicate_id}
    else
      {:ok, %{element | children: children ++ [new_element]}}
    end
  end
  defp add_element(%{children: children} = element, parent_id, new_element) do
    case add_to_children(children, parent_id, new_element) do
      {:ok, updated_children} -> {:ok, %{element | children: updated_children}}
      error -> error
    end
  end
  defp add_element(_element, _parent_id, _new_element) do
    {:error, :parent_not_found}
  end

  defp add_to_children(children, parent_id, new_element) do
    {updated, found} = Enum.reduce(children, {[], false}, fn child, {acc, found} ->
      if found do
        {acc ++ [child], found}
      else
        case add_element(child, parent_id, new_element) do
          {:ok, updated_child} -> {acc ++ [updated_child], true}
          {:error, :parent_not_found} -> {acc ++ [child], false}
          error -> throw(error)
        end
      end
    end)

    if found, do: {:ok, updated}, else: {:error, :parent_not_found}
  catch
    error -> error
  end

  defp element_exists?(%{id: id}, target_id) when id == target_id, do: true
  defp element_exists?(%{children: children}, target_id) do
    Enum.any?(children, &element_exists?(&1, target_id))
  end
  defp element_exists?(_, _), do: false

  # Helper to convert handler map keys from strings to atoms
  # Handles both simple format {event: "code"} and structured format {event: %{params: [], body: "code"}}
  defp atomize_handler_keys(handlers) when is_map(handlers) do
    handlers
    |> Enum.map(fn {key, value} ->
      atom_key = if is_binary(key), do: String.to_atom(key), else: key

      # Convert nested maps to atom keys too
      atom_value = case value do
        %{"params" => params, "body" => body} ->
          %{params: params, body: body}
        %{} = map when is_map(map) ->
          Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
        other ->
          other
      end

      {atom_key, atom_value}
    end)
    |> Map.new()
  end
  defp atomize_handler_keys(_), do: %{}

  # JavaScript Validation Helpers

  # Validate a map of functions using NodeJS
  defp validate_functions(functions) when map_size(functions) == 0, do: :ok
  defp validate_functions(functions) when is_map(functions) do
    Enum.reduce_while(functions, :ok, fn {name, code}, :ok ->
      case NodeJS.call({"js_parser", :validateFunction}, [code]) do
        {:ok, %{"valid" => true}} ->
          {:cont, :ok}

        {:ok, %{"valid" => false, "error" => error}} ->
          {:halt, {:error, {name, error}}}

        {:error, reason} ->
          {:halt, {:error, {name, "Validation service error: #{inspect(reason)}"}}}
      end
    end)
  end

  # Validate a map of init scripts using NodeJS
  defp validate_init_scripts(scripts) when map_size(scripts) == 0, do: :ok
  defp validate_init_scripts(scripts) when is_map(scripts) do
    Enum.reduce_while(scripts, :ok, fn {name, code}, :ok ->
      case NodeJS.call({"js_parser", :validateInitScript}, [code]) do
        {:ok, %{"valid" => true}} ->
          {:cont, :ok}

        {:ok, %{"valid" => false, "error" => error}} ->
          {:halt, {:error, {name, error}}}

        {:error, reason} ->
          {:halt, {:error, {name, "Validation service error: #{inspect(reason)}"}}}
      end
    end)
  end
end
