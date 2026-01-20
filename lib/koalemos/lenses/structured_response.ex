defmodule Koalemos.Lenses.StructuredResponse do
  @moduledoc """
  Lens that provides a `respond` tool based on an inline schema.

  This lens enables structured output from agents by providing a tool
  with parameters matching a user-defined schema. The schema is converted
  to JSON Schema format for the LLM tool call.

  ## Config

  - `schema` - Map defining the response structure (required)
  - `tool_name` - Override tool name (default: "respond")
  - `tool_description` - Override tool description

  ## Schema Format

  Internal format (converted to JSON Schema for tool calls):

      %{
        field_name: %{
          type: :string | :integer | :boolean | :array | :enum | :map,
          description: "...",           # optional
          required: true | false,       # optional, default true
          values: [...],                # for :enum
          items: %{...} | :string,      # for :array - nested schema or primitive
          properties: %{...}            # for :map - nested schema
        }
      }

  ## Example

      ["Koalemos.Lenses.StructuredResponse", %{
        schema: %{
          summary: %{type: :string, description: "Brief summary"},
          confidence: %{type: :enum, values: ["high", "medium", "low"]},
          tags: %{type: :array, items: :string, required: false}
        }
      }]

  ## Usage with StructuredResponseAgent

  This lens is automatically added by `StructuredResponseAgent` - you don't
  need to add it manually. The agent will capture the response when the
  `respond` tool is called.
  """

  @doc """
  Provides no context - this lens only provides a tool.
  """
  def provide_context(_state, _config), do: []

  @doc """
  Returns the respond tool.
  """
  def tools(_config), do: [{__MODULE__, :respond}]

  @doc """
  Builds the tool info with JSON Schema from the lens config.
  """
  def info(:respond, context) do
    config = get_lens_config(context)
    schema = Map.get(config, :schema, %{})
    tool_name = Map.get(config, :tool_name, "respond")

    tool_description =
      Map.get(
        config,
        :tool_description,
        "Provide your structured response using this tool. Call this when you have gathered enough information to respond."
      )

    %{
      name: tool_name,
      description: tool_description,
      input_schema: schema_to_json_schema(schema)
    }
  end

  @doc """
  Executes the respond tool - stores input in lens_state for capture.
  """
  def execute(:respond, input, _context) do
    # Return the input as-is via lens_state
    # StructuredResponseAgent looks for :structured_response key
    {"Response recorded.", [structured_response: input]}
  end

  # Convert internal schema format to JSON Schema
  defp schema_to_json_schema(schema) when is_map(schema) do
    properties =
      Enum.into(schema, %{}, fn {field, spec} ->
        {Atom.to_string(field), field_to_json_schema(spec)}
      end)

    required =
      schema
      |> Enum.filter(fn {_field, spec} -> Map.get(spec, :required, true) end)
      |> Enum.map(fn {field, _} -> Atom.to_string(field) end)

    %{
      type: "object",
      properties: properties,
      required: required
    }
  end

  defp schema_to_json_schema(_), do: %{type: "object", properties: %{}, required: []}

  # String type
  defp field_to_json_schema(%{type: :string} = spec) do
    %{type: "string"}
    |> add_description(spec)
  end

  # Integer type
  defp field_to_json_schema(%{type: :integer} = spec) do
    %{type: "integer"}
    |> add_description(spec)
  end

  # Number type (float)
  defp field_to_json_schema(%{type: :number} = spec) do
    %{type: "number"}
    |> add_description(spec)
  end

  # Boolean type
  defp field_to_json_schema(%{type: :boolean} = spec) do
    %{type: "boolean"}
    |> add_description(spec)
  end

  # Enum type - string with allowed values
  defp field_to_json_schema(%{type: :enum, values: values} = spec) when is_list(values) do
    %{type: "string", enum: values}
    |> add_description(spec)
  end

  # Array type with items
  defp field_to_json_schema(%{type: :array, items: items} = spec) do
    items_schema =
      case items do
        :string -> %{type: "string"}
        :integer -> %{type: "integer"}
        :number -> %{type: "number"}
        :boolean -> %{type: "boolean"}
        nested when is_map(nested) -> schema_to_json_schema(nested)
      end

    %{type: "array", items: items_schema}
    |> add_description(spec)
  end

  # Array type without items (defaults to string)
  defp field_to_json_schema(%{type: :array} = spec) do
    %{type: "array", items: %{type: "string"}}
    |> add_description(spec)
  end

  # Map/object type with nested properties
  defp field_to_json_schema(%{type: :map, properties: nested} = spec) when is_map(nested) do
    schema_to_json_schema(nested)
    |> add_description(spec)
  end

  # Map type without properties (free-form object)
  defp field_to_json_schema(%{type: :map} = spec) do
    %{type: "object"}
    |> add_description(spec)
  end

  # Fallback - treat as string
  defp field_to_json_schema(spec) when is_map(spec) do
    %{type: "string"}
    |> add_description(spec)
  end

  defp field_to_json_schema(_), do: %{type: "string"}

  # Add description if present
  defp add_description(base, spec) do
    case Map.get(spec, :description) do
      nil -> base
      desc -> Map.put(base, :description, desc)
    end
  end

  # Get lens config from context
  defp get_lens_config(context) do
    Map.get(context, :current_lens_config, %{})
  end
end
