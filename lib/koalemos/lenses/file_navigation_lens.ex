defmodule Koalemos.Lenses.FileNavigationLens do
  @moduledoc """
  FileNavigationLens provides explicit file/directory context management.

  Instead of tools returning file contents in conversation history, this lens
  manages a "working set" of open files and directories. Open items appear
  in the agent's context; closed items are removed.

  ## Design Philosophy

  - Conversation and tool results are separate from file context
  - Agent explicitly controls what's in its working memory
  - Tools return status only (ok/error), not content
  - Content appears via lens context

  ## Tools

  - `open` - Open a file or directory (content appears in context)
  - `close` - Close a file or directory (removed from context)

  ## Usage

  ```elixir
  lenses: [
    "Koalemos.Lenses.FileNavigationLens"
  ]
  ```

  ## Context Rendering

  Open files show content with line numbers. Open directories show a listing
  with file metadata (type, line count for files).
  """

  require Logger

  @doc """
  Provide context blocks for all open files and directories.
  """
  def provide_context(state, _config \\ %{}) do
    lens_state = Map.get(state.context, :lens_state, %{})
    open_items = Map.get(lens_state, :open_items, %{})

    if open_items == %{} do
      []
    else
      open_items
      |> Enum.sort_by(fn {path, _} -> path end)
      |> Enum.map(&render_item/1)
    end
  end

  @doc """
  Provide tool definitions for this lens.
  """
  def tools(_config \\ %{}) do
    [{__MODULE__, :open}, {__MODULE__, :close}]
  end

  def info(:open) do
    %{
      name: "open",
      description: """
      Open a file or directory to add it to your working context.
      - Files: content will appear in your context with line numbers
      - Directories: listing will appear with file metadata
      Returns status only; content appears in context on next turn.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          path: %{
            type: "string",
            description: "Path to file or directory (absolute or relative to working directory)"
          }
        },
        required: ["path"]
      }
    }
  end

  def info(:close) do
    %{
      name: "close",
      description: """
      Close a file or directory, removing it from your working context.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          path: %{
            type: "string",
            description: "Path to close (must match the path used to open)"
          }
        },
        required: ["path"]
      }
    }
  end

  def execute(:open, args, context) do
    path = args["path"]
    base_path = get_base_path(context)
    full_path = resolve_path(path, base_path)

    cond do
      File.regular?(full_path) ->
        open_file(path, full_path, context)

      File.dir?(full_path) ->
        open_directory(path, full_path, context)

      true ->
        {"error: path not found: #{path}", []}
    end
  end

  def execute(:close, args, context) do
    path = args["path"]
    lens_state = Map.get(context, :lens_state, %{})
    open_items = Map.get(lens_state, :open_items, %{})

    if Map.has_key?(open_items, path) do
      updated_items = Map.delete(open_items, path)
      {"closed: #{path}", [open_items: updated_items]}
    else
      {"error: not open: #{path}", []}
    end
  end

  def execute(tool_name, _args, _context) do
    {"error: unknown tool: #{inspect(tool_name)}", []}
  end

  # Private functions

  defp open_file(path, full_path, context) do
    case File.read(full_path) do
      {:ok, content} ->
        lens_state = Map.get(context, :lens_state, %{})
        open_items = Map.get(lens_state, :open_items, %{})

        line_count = content |> String.split("\n") |> length()

        item = %{
          type: :file,
          full_path: full_path,
          content: content,
          lines: line_count
        }

        updated_items = Map.put(open_items, path, item)
        {"opened: #{path} (#{line_count} lines)", [open_items: updated_items]}

      {:error, reason} ->
        {"error: could not read #{path}: #{inspect(reason)}", []}
    end
  end

  defp open_directory(path, full_path, context) do
    case File.ls(full_path) do
      {:ok, entries} ->
        lens_state = Map.get(context, :lens_state, %{})
        open_items = Map.get(lens_state, :open_items, %{})

        entries_with_meta =
          entries
          |> Enum.sort()
          |> Enum.map(fn name ->
            entry_path = Path.join(full_path, name)
            build_entry_meta(name, entry_path)
          end)

        item = %{
          type: :directory,
          full_path: full_path,
          entries: entries_with_meta
        }

        updated_items = Map.put(open_items, path, item)
        {"opened: #{path}/ (#{length(entries)} entries)", [open_items: updated_items]}

      {:error, reason} ->
        {"error: could not list #{path}: #{inspect(reason)}", []}
    end
  end

  defp build_entry_meta(name, entry_path) do
    cond do
      File.dir?(entry_path) ->
        %{name: name, type: :directory}

      File.regular?(entry_path) ->
        lines = count_lines(entry_path)
        %{name: name, type: :file, lines: lines}

      true ->
        %{name: name, type: :other}
    end
  end

  defp count_lines(path) do
    case File.read(path) do
      {:ok, content} -> content |> String.split("\n") |> length()
      {:error, _} -> nil
    end
  end

  defp render_item({path, %{type: :file, content: content, lines: lines}}) do
    numbered_content =
      content
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {line, num} ->
        "#{String.pad_leading(Integer.to_string(num), 4)} | #{line}"
      end)

    %{
      type: "text",
      text: """
      ## File: #{path} (#{lines} lines)

      ```
      #{numbered_content}
      ```
      """
    }
  end

  defp render_item({path, %{type: :directory, entries: entries}}) do
    listing =
      Enum.map_join(entries, "\n", fn entry ->
        case entry do
          %{type: :directory, name: name} ->
            "  #{name}/"

          %{type: :file, name: name, lines: lines} when is_integer(lines) ->
            "  #{name} (#{lines} lines)"

          %{type: :file, name: name} ->
            "  #{name}"

          %{name: name} ->
            "  #{name}"
        end
      end)

    %{
      type: "text",
      text: """
      ## Directory: #{path}/ (#{length(entries)} entries)

      #{listing}
      """
    }
  end

  defp get_base_path(context) do
    # Could be configured via lens config or context
    Map.get(context, :working_directory, File.cwd!())
  end

  defp resolve_path(path, base_path) do
    if Path.type(path) == :absolute do
      path
    else
      Path.join(base_path, path) |> Path.expand()
    end
  end
end
