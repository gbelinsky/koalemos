defmodule WireframeEditorWeb.MessageCards.InlineToolIndicator do
  @moduledoc """
  Renders a subtle inline indicator for tool usage.

  Shows a compact summary of what the tool did, with an option to expand
  and see full parameters.
  """
  use Phoenix.Component

  attr :tool_call, :map, required: true, doc: "Tool call with name and input"
  attr :expanded, :boolean, default: false, doc: "Whether to show full details"

  def render(assigns) do
    summary = generate_summary(assigns.tool_call)
    assigns = assign(assigns, :summary, summary)

    ~H"""
    <div class="inline-tool-indicator text-xs text-slate-600 py-0.5">
      <span class="tool-summary">
        <%= @summary %>
      </span>
      <%= if @expanded do %>
        <details class="mt-0.5">
          <summary class="text-[0.65rem] text-slate-500 cursor-pointer hover:text-slate-700">
            Show details
          </summary>
          <pre class="text-[0.65rem] bg-slate-50 rounded p-1.5 mt-0.5 overflow-x-auto"><code><%= format_input(@tool_call["input"]) %></code></pre>
        </details>
      <% end %>
    </div>
    """
  end

  # Generate human-readable summary for each tool type
  # Handle both atom and string keys
  defp generate_summary(tool_call) when is_map(tool_call) do
    name = Map.get(tool_call, "name") || Map.get(tool_call, :name)
    input = Map.get(tool_call, "input") || Map.get(tool_call, :input)

    case name do
      "modify_elements" -> summarize_modify_elements(input)
      "modify_classes" -> summarize_modify_classes(input)
      "manage_attributes" -> summarize_manage_attributes(input)
      "manage_handlers" -> summarize_manage_handlers(input)
      "manage_functions" -> summarize_manage_functions(input)
      "manage_variables" -> summarize_manage_variables(input)
      "manage_css" -> summarize_manage_css(input)
      "manage_init_scripts" -> summarize_manage_init_scripts(input)
      "trigger_interaction" -> summarize_trigger_interaction(input)
      "choose_transition" -> summarize_choose_transition(input)
      _ when is_binary(name) -> "↦ Used tool: #{name}"
      _ -> "↦ Tool executed"
    end
  end

  defp generate_summary(_), do: "↦ Tool executed"

  # modify_elements: Added 3, removed 2, replaced 1
  defp summarize_modify_elements(input) do
    added = length(Map.get(input, "add_elements", []))
    removed = length(Map.get(input, "remove_elements", []))
    replaced = length(Map.get(input, "replace_elements", []))

    total = added + removed + replaced
    parts = []

    parts = if added > 0, do: ["#{added} added" | parts], else: parts
    parts = if removed > 0, do: ["#{removed} removed" | parts], else: parts
    parts = if replaced > 0, do: ["#{replaced} replaced" | parts], else: parts

    if total > 0 do
      "↦ Modified #{total} #{pluralize("element", total)} (#{Enum.join(parts, ", ")})"
    else
      "↦ Modified elements"
    end
  end

  # modify_classes: Styled 5 elements
  defp summarize_modify_classes(input) do
    elements = Map.get(input, "elements", [])
    count = length(elements)

    if count == 1 do
      element = List.first(elements)
      element_id = Map.get(element, "element_id", "element")
      added = length(Map.get(element, "add_classes", []))
      removed = length(Map.get(element, "remove_classes", []))

      details =
        cond do
          added > 0 and removed > 0 ->
            "(added #{added}, removed #{removed})"

          added > 0 ->
            "(added #{added})"

          removed > 0 ->
            "(removed #{removed})"

          true ->
            ""
        end

      "◐ Styled #{element_id} #{details}"
    else
      "◐ Styled #{count} #{pluralize("element", count)}"
    end
  end

  # manage_attributes: Updated attributes on 4 elements
  defp summarize_manage_attributes(input) do
    elements = Map.get(input, "elements", [])
    count = length(elements)

    if count == 1 do
      element = List.first(elements)
      element_id = Map.get(element, "element_id", "element")
      set_count = map_size(Map.get(element, "set", %{}))
      remove_count = length(Map.get(element, "remove", []))

      action =
        cond do
          set_count > 0 and remove_count > 0 -> "Updated"
          set_count > 0 -> "Set"
          remove_count > 0 -> "Removed"
          true -> "Modified"
        end

      "⚬ #{action} attributes on #{element_id}"
    else
      "⚬ Updated attributes on #{count} #{pluralize("element", count)}"
    end
  end

  # manage_handlers: Managed 3 handlers (2 added, 1 removed)
  defp summarize_manage_handlers(input) do
    elements = Map.get(input, "elements", [])

    total_added =
      Enum.reduce(elements, 0, fn el, acc ->
        acc + map_size(Map.get(el, "add", %{}))
      end)

    total_removed =
      Enum.reduce(elements, 0, fn el, acc ->
        acc + length(Map.get(el, "remove", []))
      end)

    total_replaced =
      Enum.reduce(elements, 0, fn el, acc ->
        acc + map_size(Map.get(el, "replace", %{}))
      end)

    total = total_added + total_removed + total_replaced

    if length(elements) == 1 and total == 1 do
      element = List.first(elements)
      element_id = Map.get(element, "element_id", "element")

      event_type =
        cond do
          total_added > 0 -> Map.keys(Map.get(element, "add", %{})) |> List.first()
          total_replaced > 0 -> Map.keys(Map.get(element, "replace", %{})) |> List.first()
          total_removed > 0 -> List.first(Map.get(element, "remove", []))
          true -> "handler"
        end

      action =
        cond do
          total_added > 0 -> "Added"
          total_replaced > 0 -> "Updated"
          total_removed > 0 -> "Removed"
          true -> "Modified"
        end

      "⚡ #{action} #{event_type} handler #{if action == "Removed", do: "from", else: "to"} #{element_id}"
    else
      parts = []
      parts = if total_added > 0, do: ["#{total_added} added" | parts], else: parts
      parts = if total_removed > 0, do: ["#{total_removed} removed" | parts], else: parts
      parts = if total_replaced > 0, do: ["#{total_replaced} updated" | parts], else: parts

      "⚡ Managed #{total} #{pluralize("handler", total)} (#{Enum.join(parts, ", ")})"
    end
  end

  # manage_functions: Managed 4 functions (2 added, 2 updated)
  defp summarize_manage_functions(input) do
    added = map_size(Map.get(input, "add_functions", %{}))
    removed = length(Map.get(input, "remove_functions", []))
    replaced = map_size(Map.get(input, "replace_functions", %{}))

    total = added + removed + replaced

    if total == 1 do
      name =
        cond do
          added > 0 -> Map.keys(Map.get(input, "add_functions", %{})) |> List.first()
          replaced > 0 -> Map.keys(Map.get(input, "replace_functions", %{})) |> List.first()
          removed > 0 -> List.first(Map.get(input, "remove_functions", []))
          true -> "function"
        end

      action =
        cond do
          added > 0 -> "Added"
          replaced > 0 -> "Updated"
          removed > 0 -> "Removed"
          true -> "Modified"
        end

      "ƒ #{action} function #{name}"
    else
      parts = []
      parts = if added > 0, do: ["#{added} added" | parts], else: parts
      parts = if removed > 0, do: ["#{removed} removed" | parts], else: parts
      parts = if replaced > 0, do: ["#{replaced} updated" | parts], else: parts

      "ƒ Managed #{total} #{pluralize("function", total)} (#{Enum.join(parts, ", ")})"
    end
  end

  # manage_variables: Set 3 variables
  defp summarize_manage_variables(input) do
    set_count = map_size(Map.get(input, "set_variables", %{}))
    removed_count = length(Map.get(input, "remove_variables", []))

    total = set_count + removed_count

    if total == 1 do
      if set_count > 0 do
        name = Map.keys(Map.get(input, "set_variables", %{})) |> List.first()
        "⊕ Set variable #{name}"
      else
        name = List.first(Map.get(input, "remove_variables", []))
        "⊕ Removed variable #{name}"
      end
    else
      parts = []
      parts = if set_count > 0, do: ["#{set_count} set" | parts], else: parts
      parts = if removed_count > 0, do: ["#{removed_count} removed" | parts], else: parts

      "⊕ Managed #{total} #{pluralize("variable", total)} (#{Enum.join(parts, ", ")})"
    end
  end

  # manage_css: Managed 5 CSS rules (4 added, 1 removed)
  defp summarize_manage_css(input) do
    # LLM sometimes sends JSON strings instead of maps - normalize them
    added = safe_map_size(Map.get(input, "add", %{}))
    removed = length(Map.get(input, "remove", []))
    replaced = safe_map_size(Map.get(input, "replace", %{}))

    total = added + removed + replaced

    if total == 1 do
      selector =
        cond do
          added > 0 -> safe_map_keys(Map.get(input, "add", %{})) |> List.first()
          replaced > 0 -> safe_map_keys(Map.get(input, "replace", %{})) |> List.first()
          removed > 0 -> List.first(Map.get(input, "remove", []))
          true -> "rule"
        end

      action =
        cond do
          added > 0 -> "Added"
          replaced > 0 -> "Updated"
          removed > 0 -> "Removed"
          true -> "Modified"
        end

      "⌘ #{action} CSS rule #{selector || "rule"}"
    else
      parts = []
      parts = if added > 0, do: ["#{added} added" | parts], else: parts
      parts = if removed > 0, do: ["#{removed} removed" | parts], else: parts
      parts = if replaced > 0, do: ["#{replaced} updated" | parts], else: parts

      "⌘ Managed #{total} CSS #{pluralize("rule", total)} (#{Enum.join(parts, ", ")})"
    end
  end

  # manage_init_scripts: Managed 2 init scripts
  defp summarize_manage_init_scripts(input) do
    # LLM sometimes sends JSON strings instead of maps - normalize them
    added = safe_map_size(Map.get(input, "add", %{}))
    removed = length(Map.get(input, "remove", []))
    replaced = safe_map_size(Map.get(input, "replace", %{}))

    total = added + removed + replaced

    if total == 1 do
      name =
        cond do
          added > 0 -> safe_map_keys(Map.get(input, "add", %{})) |> List.first()
          replaced > 0 -> safe_map_keys(Map.get(input, "replace", %{})) |> List.first()
          removed > 0 -> List.first(Map.get(input, "remove", []))
          true -> "script"
        end

      action =
        cond do
          added > 0 -> "Added"
          replaced > 0 -> "Updated"
          removed > 0 -> "Removed"
          true -> "Modified"
        end

      "⟳ #{action} init script #{name}"
    else
      parts = []
      parts = if added > 0, do: ["#{added} added" | parts], else: parts
      parts = if removed > 0, do: ["#{removed} removed" | parts], else: parts
      parts = if replaced > 0, do: ["#{replaced} updated" | parts], else: parts

      "⟳ Managed #{total} init #{pluralize("script", total)} (#{Enum.join(parts, ", ")})"
    end
  end

  # trigger_interaction: Tested: clicked btn-submit
  defp summarize_trigger_interaction(input) do
    action = Map.get(input, "action")
    element_id = Map.get(input, "element_id")

    case action do
      "click" ->
        "⊙ Tested: clicked #{element_id}"

      "fill_input" ->
        value = Map.get(input, "value", "")
        "⊙ Tested: filled #{element_id} with \"#{value}\""

      "submit_form" ->
        "⊙ Tested: submitted form #{element_id}"

      "execute_js" ->
        "⊙ Tested: executed custom JavaScript"

      _ ->
        "⊙ Tested interaction"
    end
  end

  # choose_transition: → Transitioning to make_change
  defp summarize_choose_transition(input) do
    transition = Map.get(input, "transition", "next step")
    "→ Transitioning to #{transition}"
  end

  # Helper to pluralize words
  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: "#{word}s"

  # Safe map_size that handles JSON strings from LLM
  defp safe_map_size(value) when is_map(value), do: map_size(value)

  defp safe_map_size(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> map_size(map)
      _ -> 0
    end
  end

  defp safe_map_size(_), do: 0

  # Safe map keys extraction that handles JSON strings
  defp safe_map_keys(value) when is_map(value), do: Map.keys(value)

  defp safe_map_keys(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> Map.keys(map)
      _ -> []
    end
  end

  defp safe_map_keys(_), do: []

  # Format tool input as pretty JSON
  defp format_input(input) when is_map(input) do
    Jason.encode!(input, pretty: true)
  rescue
    _ -> inspect(input)
  end

  defp format_input(input), do: inspect(input)
end
