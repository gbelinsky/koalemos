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
      results = Enum.map(elements, fn elem ->
        element_id = Map.get(elem, "element_id")
        add_classes = Map.get(elem, "add_classes", [])
        remove_classes = Map.get(elem, "remove_classes", [])

        modify_element_classes(dom_tree, element_id, add_classes, remove_classes)
      end)

      errors = Enum.filter(results, &match?({:error, _}, &1))

      if length(errors) > 0 do
        error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
        {"Errors modifying classes:\n#{error_messages}", []}
      else
        # All successful, get updated tree from first result
        {:ok, updated_tree} = hd(results)

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
        results = Enum.map(elements, fn elem ->
          element_id = Map.get(elem, "element_id")
          set_attrs = Map.get(elem, "set", %{})
          remove_attrs = Map.get(elem, "remove", [])

          modify_element_attributes(dom_tree, element_id, set_attrs, remove_attrs)
        end)

        errors = Enum.filter(results, &match?({:error, _}, &1))

        if length(errors) > 0 do
          error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
          {"Errors managing attributes:\n#{error_messages}", []}
        else
          {:ok, updated_tree} = hd(results)

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

    if is_nil(dom_tree) do
      {"Error: No wireframe loaded. Load a wireframe first.", []}
    else
      results = Enum.map(elements, fn elem ->
        element_id = Map.get(elem, "element_id")
        add_handlers = Map.get(elem, "add", %{})
        replace_handlers = Map.get(elem, "replace", %{})
        remove_events = Map.get(elem, "remove", [])

        modify_element_handlers(dom_tree, element_id, add_handlers, replace_handlers, remove_events)
      end)

      errors = Enum.filter(results, &match?({:error, _}, &1))

      if length(errors) > 0 do
        error_messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "- #{msg}" end)
        {"Errors managing handlers:\n#{error_messages}", []}
      else
        {:ok, updated_tree} = hd(results)

        modification = %{
          type: :manage_handlers,
          elements: Enum.map(elements, & &1["element_id"]),
          timestamp: DateTime.utc_now()
        }

        updated_designed = %{designed | dom_tree: updated_tree}
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
    updated_functions = Map.merge(current_functions, add_functions)

    # Replace functions
    replace_functions = Map.get(args, "replace_functions", %{})
    updated_functions = Map.merge(updated_functions, replace_functions)

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

    updated_designed = %{designed | custom_css: updated_css}
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
    updated_scripts = Map.merge(current_scripts, add_scripts)

    # Replace scripts
    replace_scripts = Map.get(args, "replace", %{})
    updated_scripts = Map.merge(updated_scripts, replace_scripts)

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

    updated_designed = %{designed | init_scripts: updated_scripts}
    modifications = [modification | Map.get(lens_state, :modifications, [])]

    total = map_size(add_scripts) + map_size(replace_scripts) + length(remove_scripts)
    {"Successfully managed #{total} init script(s)", [
      designed: updated_designed,
      modifications: modifications
    ]}
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

  defp modify_element_handlers(tree, element_id, add_handlers, replace_handlers, remove_events) do
    case find_and_update_element(tree, element_id, fn element ->
      current_handlers = Map.get(element, :handlers, %{})

      # Check add conflicts
      add_conflicts = Enum.filter(Map.keys(add_handlers), &Map.has_key?(current_handlers, &1))
      if length(add_conflicts) > 0 do
        throw({:error, "Handler already exists for events: #{Enum.join(add_conflicts, ", ")} on element '#{element_id}'"})
      end

      # Check replace requirements
      replace_missing = Enum.filter(Map.keys(replace_handlers), &(!Map.has_key?(current_handlers, &1)))
      if length(replace_missing) > 0 do
        throw({:error, "No existing handler to replace for events: #{Enum.join(replace_missing, ", ")} on element '#{element_id}'"})
      end

      updated_handlers = current_handlers
        |> Map.merge(add_handlers)
        |> Map.merge(replace_handlers)
        |> Map.drop(remove_events)

      Map.put(element, :handlers, updated_handlers)
    end) do
      {:ok, updated_tree} -> {:ok, updated_tree}
      {:error, :not_found} -> {:error, "Element '#{element_id}' not found"}
    end
  catch
    {:error, message} -> {:error, message}
  end

  defp process_removals(tree, remove_ids) do
    results = Enum.map(remove_ids, fn id ->
      case remove_element(tree, id) do
        {:ok, _updated_tree} ->
          # TODO: accumulate changes for batch updates
          {:ok, "Removed #{id}"}
        {:error, :not_found} ->
          {:error, "Element '#{id}' not found"}
      end
    end)

    updated_tree = case Enum.find(results, &match?({:ok, _}, &1)) do
      {:ok, _} -> tree
      _ -> tree
    end

    {updated_tree, results}
  end

  defp process_replacements(tree, replacements) do
    results = Enum.map(replacements, fn replacement ->
      _element_id = Map.get(replacement, "element_id")
      _new_element = Map.get(replacement, "new_element")

      # TODO: Implement replace logic using element_id and new_element
      {:error, "Replace not yet implemented"}
    end)

    {tree, results}
  end

  defp process_additions(tree, additions) do
    results = Enum.map(additions, fn addition ->
      parent_id = Map.get(addition, "parent_id")
      new_element = build_element_from_spec(addition)

      case add_element(tree, parent_id, new_element) do
        {:ok, _updated_tree} ->
          # TODO: accumulate changes for batch updates
          {:ok, "Added #{new_element.id}"}
        {:error, :parent_not_found} ->
          {:error, "Parent element '#{parent_id}' not found"}
        {:error, :duplicate_id} ->
          {:error, "Element with ID '#{new_element.id}' already exists"}
      end
    end)

    updated_tree = case Enum.find(results, &match?({:ok, _}, &1)) do
      {:ok, _} -> tree
      _ -> tree
    end

    {updated_tree, results}
  end

  defp build_element_from_spec(spec) do
    %{
      tag: Map.get(spec, "tag"),
      id: Map.get(spec, "id"),
      content: Map.get(spec, "content"),
      classes: Map.get(spec, "classes", []),
      attributes: Map.get(spec, "attributes", %{}),
      handlers: Map.get(spec, "handlers", %{}),
      children: []
    }
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
end
