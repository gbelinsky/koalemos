defmodule Koalemos.Parsers.HTMLParser do
  @moduledoc """
  HTML parser for wireframe editor.

  Converts HTML into structured data for manipulation:
  - Full DOM tree with nested children
  - Auto-generated unique IDs
  - Extracted style/script elements for future processing
  - Metadata (title, meta tags)

  ## Usage

      iex> html = "<div><h1>Hello</h1></div>"
      iex> {:ok, result} = HTMLParser.parse_html(html)
      iex> result.dom_tree.tag
      "div"

  ## Output Format

      %{
        dom_tree: %{
          tag: "div",
          id: "root",
          classes: [],
          attributes: %{},
          styles: %{},
          content: nil,
          children: [...]
        },
        style_elements: [
          %{type: :inline, content: "...", attributes: %{}},
          %{type: :external, src: "...", attributes: %{}}
        ],
        script_elements: [
          %{type: :inline, content: "...", attributes: %{}},
          %{type: :external, src: "...", attributes: %{}}
        ],
        metadata: %{
          title: "Page Title",
          meta_tags: [%{name: "...", content: "..."}]
        }
      }
  """

  @doc """
  Parse HTML string into structured format.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def parse_html(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, floki_tree} ->
        # Extract special elements before DOM conversion
        style_elements = extract_style_elements(floki_tree)
        script_elements = extract_script_elements(floki_tree)
        metadata = extract_metadata(floki_tree)

        # Extract body content for the DOM tree, or use entire tree if no body
        body_content = extract_body_content(floki_tree)

        # Convert to DOM tree with unique IDs
        {dom_tree, _counter, _used_ids} = convert_to_dom_tree(body_content, 1, MapSet.new())

        result = %{
          dom_tree: dom_tree,
          style_elements: style_elements,
          script_elements: script_elements,
          metadata: metadata
        }

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extract body content from full HTML document, or return tree as-is
  defp extract_body_content(floki_tree) do
    case Floki.find(floki_tree, "body") do
      [{"body", _attrs, children}] -> children
      [] -> floki_tree  # No body tag, use entire tree
    end
  end

  @doc """
  Parse HTML from file path.

  Convenience wrapper around `parse_html/1`.
  """
  def parse_file(file_path) when is_binary(file_path) do
    case File.read(file_path) do
      {:ok, html} -> parse_html(html)
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # DOM Tree Conversion
  # ============================================================================

  @doc false
  def convert_to_dom_tree(floki_nodes, counter, used_ids) when is_list(floki_nodes) do
    case floki_nodes do
      # Single element - convert it directly without wrapping
      [single_node] ->
        convert_node(single_node, counter, used_ids)

      # Multiple root nodes - wrap in a container div
      _ ->
        {children, final_counter, final_used_ids} =
          convert_children(floki_nodes, counter, used_ids)

        root_id = ensure_unique_id("root", final_used_ids)

        root = %{
          tag: "div",
          id: root_id,
          classes: [],
          attributes: %{},
          styles: %{},
          content: nil,
          children: children
        }

        {root, final_counter, MapSet.put(final_used_ids, root_id)}
    end
  end

  def convert_to_dom_tree(floki_node, counter, used_ids) do
    convert_node(floki_node, counter, used_ids)
  end

  # Convert a single Floki node to our DOM format
  defp convert_node({tag, attributes, children}, counter, used_ids) do
    # Extract/generate ID
    {id, remaining_attrs, new_counter} =
      extract_or_generate_id(attributes, tag, counter, used_ids)

    # Extract classes
    {classes, remaining_attrs} = extract_classes(remaining_attrs)

    # Extract inline styles
    {styles, remaining_attrs} = extract_inline_styles(remaining_attrs)

    # Convert remaining attributes to map
    attrs_map = Enum.into(remaining_attrs, %{})

    # Process children
    {converted_children, final_counter, final_used_ids} =
      convert_children(children, new_counter, MapSet.put(used_ids, id))

    # Check if this is a text leaf node
    {content, children_list} =
      if converted_children == [] and children != [] do
        text = extract_text_content(children)
        if text != "", do: {text, []}, else: {nil, []}
      else
        {nil, converted_children}
      end

    node = %{
      tag: tag,
      id: id,
      classes: classes,
      attributes: attrs_map,
      styles: styles,
      content: content,
      children: children_list
    }

    {node, final_counter, final_used_ids}
  end

  # Skip text nodes (they're handled as content in parent)
  defp convert_node(text, counter, used_ids) when is_binary(text) do
    {nil, counter, used_ids}
  end

  # Skip other node types
  defp convert_node(_node, counter, used_ids) do
    {nil, counter, used_ids}
  end

  # Convert list of children nodes
  defp convert_children(children, counter, used_ids) do
    Enum.reduce(children, {[], counter, used_ids}, fn child, {acc, cnt, ids} ->
      case convert_node(child, cnt, ids) do
        {nil, new_cnt, new_ids} ->
          {acc, new_cnt, new_ids}
        {node, new_cnt, new_ids} ->
          {acc ++ [node], new_cnt, new_ids}
      end
    end)
  end

  # ============================================================================
  # ID Generation
  # ============================================================================

  # Extract existing ID or generate unique auto ID
  defp extract_or_generate_id(attributes, tag, counter, used_ids) do
    case List.keytake(attributes, "id", 0) do
      {{"id", existing_id}, remaining} ->
        # Use existing ID, ensure uniqueness
        unique_id = ensure_unique_id(existing_id, used_ids)
        {unique_id, remaining, counter}

      nil ->
        # Generate auto ID
        base_id = "auto-#{tag}-#{counter}"
        unique_id = ensure_unique_id(base_id, used_ids)
        {unique_id, attributes, counter + 1}
    end
  end

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

  # ============================================================================
  # Attribute Extraction
  # ============================================================================

  defp extract_classes(attributes) do
    case List.keytake(attributes, "class", 0) do
      {{"class", class_string}, remaining} ->
        classes = String.split(class_string, ~r/\s+/, trim: true)
        {classes, remaining}
      nil ->
        {[], attributes}
    end
  end

  defp extract_inline_styles(attributes) do
    case List.keytake(attributes, "style", 0) do
      {{"style", style_string}, remaining} ->
        styles = parse_style_string(style_string)
        {styles, remaining}
      nil ->
        {%{}, attributes}
    end
  end

  defp parse_style_string(style_string) do
    style_string
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(fn declaration ->
      case String.split(declaration, ":", parts: 2) do
        [key, value] -> {String.trim(key), String.trim(value)}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp extract_text_content(children) do
    children
    |> Enum.filter(&is_binary/1)
    |> Enum.join("")
    |> String.trim()
  end

  # ============================================================================
  # Style Element Extraction
  # ============================================================================

  defp extract_style_elements(floki_tree) do
    # Find all <style> tags
    style_tags = Floki.find(floki_tree, "style")

    # Find all <link> tags with rel="stylesheet"
    link_tags = Floki.find(floki_tree, "link[rel='stylesheet']")

    # Convert to our format
    inline_styles = Enum.map(style_tags, fn {"style", attrs, children} ->
      content = extract_text_content(children)
      attributes = Enum.into(attrs, %{})

      %{
        type: :inline,
        content: content,
        attributes: attributes
      }
    end)

    external_styles = Enum.map(link_tags, fn {"link", attrs, _children} ->
      attributes = Enum.into(attrs, %{})
      href = Map.get(attributes, "href", "")

      %{
        type: :external,
        src: href,
        attributes: attributes
      }
    end)

    inline_styles ++ external_styles
  end

  # ============================================================================
  # Script Element Extraction
  # ============================================================================

  defp extract_script_elements(floki_tree) do
    script_tags = Floki.find(floki_tree, "script")

    Enum.map(script_tags, fn {"script", attrs, children} ->
      attributes = Enum.into(attrs, %{})

      case Map.get(attributes, "src") do
        nil ->
          # Inline script
          content = extract_text_content(children)
          %{
            type: :inline,
            content: content,
            attributes: attributes
          }

        src ->
          # External script
          %{
            type: :external,
            src: src,
            attributes: attributes
          }
      end
    end)
  end

  # ============================================================================
  # Metadata Extraction
  # ============================================================================

  defp extract_metadata(floki_tree) do
    # Extract title
    title = case Floki.find(floki_tree, "title") do
      [{"title", _attrs, children}] -> extract_text_content(children)
      _ -> nil
    end

    # Extract meta tags
    meta_tags =
      floki_tree
      |> Floki.find("meta")
      |> Enum.map(fn {"meta", attrs, _children} ->
        Enum.into(attrs, %{})
      end)

    %{
      title: title,
      meta_tags: meta_tags
    }
  end
end
