defmodule Koalemos.Parsers.JavaScriptParser do
  @moduledoc """
  JavaScript parser using AST analysis via Node.js.

  Extracts structured data from JavaScript code for wireframe manipulation:
  - Window variables (`window.x = value`)
  - Window functions (`window.f = () => {}`)
  - Event handlers (`document.getElementById(...).addEventListener(...)`)
  - Init script (remaining code after extraction)

  ## Usage

      iex> code = "window.myVar = 42; window.myFunc = () => console.log('hello');"
      iex> {:ok, result} = JavaScriptParser.parse(code)
      iex> result.variables
      %{"myVar" => 42}
      iex> result.functions
      %{"myFunc" => "() => console.log('hello')"}

  ## Pipeline Pattern

  Use with HTMLParser for complete parsing:

      {:ok, %{script_elements: scripts}} = HTMLParser.parse_html(html)

      inline_scripts = Enum.filter(scripts, & &1.type == :inline)

      parsed_js = Enum.map(inline_scripts, fn script ->
        JavaScriptParser.parse(script.content)
      end)

  ## Output Format

      %{
        variables: %{"varName" => json_value},
        functions: %{"funcName" => "function code"},
        handlers: %{
          "element-id" => %{
            "click" => %{params: ["event"], body: "code"}
          }
        },
        init_script: "remaining code"
      }
  """

  @doc """
  Parse JavaScript code and extract structured data.

  Returns `{:ok, result}` or `{:error, reason}`.

  ## Examples

      iex> JavaScriptParser.parse("window.x = 10;")
      {:ok, %{variables: %{"x" => 10}, functions: %{}, handlers: %{}, init_script: ""}}

      iex> JavaScriptParser.parse("invalid javascript {{")
      {:error, "Parse error: ..."}
  """
  def parse(code) when is_binary(code) do
    try do
      result = NodeJS.call!({"js_parser", :parseJavaScript}, [code])

      case result do
        %{"error" => error} when not is_nil(error) ->
          {:error, error}

        %{
          "variables" => variables,
          "functions" => functions,
          "handlers" => handlers,
          "initScript" => init_script
        } ->
          {:ok,
           %{
             variables: variables,
             functions: functions,
             handlers: convert_handlers(handlers),
             init_script: init_script
           }}

        other ->
          {:error, "Unexpected parser result: #{inspect(other)}"}
      end
    rescue
      e ->
        {:error, Exception.message(e)}
    end
  end

  # Convert handler format from Node.js to Elixir-friendly structure
  defp convert_handlers(handlers) when is_map(handlers) do
    handlers
    |> Enum.map(fn {element_id, events} ->
      converted_events =
        events
        |> Enum.map(fn {event_type, handler_data} ->
          {event_type,
           %{
             params: Map.get(handler_data, "params", []),
             body: Map.get(handler_data, "body", "")
           }}
        end)
        |> Enum.into(%{})

      {element_id, converted_events}
    end)
    |> Enum.into(%{})
  end

  defp convert_handlers(_), do: %{}
end
