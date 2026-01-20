defmodule Koalemos.Lenses.ContextAgentLens do
  @moduledoc """
  ContextAgentLens provides context-focused file management for comparison testing.

  This lens combines traditional coding tools (Write, Edit, Glob, Grep, Bash, TodoWrite)
  with an open/close paradigm for automatic context management. Files explicitly opened
  appear in context automatically and stay updated after edits.

  ## Design Philosophy

  - Context-focused: Open files appear in context, not in messages
  - Automatic updates: Edited files auto-refresh in context
  - Explicit control: Agent chooses what to open/close
  - Constraint-based: Edit only works on open files (parallel to "Read before Edit")

  ## Paradigm Comparison

  **Traditional Agent**: Read → Edit (content in messages)
  **Context Agent**: Open → Edit (content in context)

  ## Tools

  - `open` - Add file/directory to context (like Read but persistent)
  - `close` - Remove file/directory from context
  - `write` - Create/overwrite files (auto-opens new files)
  - `edit` - Exact string replacement (only works on open files, auto-refreshes)
  - `glob` - Find files by pattern
  - `grep` - Search file contents with regex
  - `bash` - Execute shell commands
  - `todo_write` - Manage task list

  ## Usage

  ```elixir
  lenses: [
    ["Koalemos.Lenses.ContextAgentLens", %{
      working_directory: "/path/to/project",
      max_open_files: 25
    }]
  ]
  ```
  """

  require Logger

  @default_timeout 120_000
  @max_line_length 2000
  @default_max_open_files 25

  @doc """
  Provide context including system prompt, open files/directories, and todos.

  Context blocks are rendered in this order:
  1. System prompt (if configured)
  2. Open files summary
  3. Each open file (with line numbers) or directory (with listings)
  4. Todos (if present)
  """
  def provide_context(state, config \\ %{}) do
    lens_state = Map.get(state.context, :lens_state, %{})
    open_items = Map.get(lens_state, :open_items, %{})
    todos = Map.get(lens_state, :todos, [])

    # Evaluate config templates with context
    evaluated_config = evaluate_config(config, state.context)
    max_files = Map.get(evaluated_config, :max_open_files, @default_max_open_files)

    # System prompt
    system_prompt_blocks =
      case Map.get(evaluated_config, :system_prompt) do
        nil -> []
        "" -> []
        prompt when is_binary(prompt) -> [%{type: "text", text: prompt}]
        _ -> []
      end

    # Open files summary and content
    open_file_blocks =
      if open_items == %{} do
        []
      else
        count = map_size(open_items)
        paths = Map.keys(open_items) |> Enum.sort() |> Enum.join(", ")

        summary = %{
          type: "text",
          text: "## Open Files: #{count}/#{max_files}\n\n#{paths}\n"
        }

        content_blocks =
          open_items
          |> Enum.sort_by(fn {path, _} -> path end)
          |> Enum.map(&render_open_item/1)

        [summary | content_blocks]
      end

    # Todos
    todo_blocks =
      if Enum.empty?(todos) do
        []
      else
        [%{type: "text", text: render_todos(todos)}]
      end

    system_prompt_blocks ++ open_file_blocks ++ todo_blocks
  end

  @doc """
  Provide tool definitions for this lens.
  """
  def tools(_config \\ %{}) do
    [
      {__MODULE__, :open},
      {__MODULE__, :close},
      {__MODULE__, :write},
      {__MODULE__, :edit},
      {__MODULE__, :glob},
      {__MODULE__, :grep},
      {__MODULE__, :bash},
      {__MODULE__, :todo_write}
    ]
  end

  # Tool info definitions

  def info(tool, context \\ %{})

  def info(:open, _context) do
    %{
      name: "Open",
      description: """
      Open a file or directory to add it to your working context.
      - Files: Content appears in context with line numbers
      - Directories: Listing appears with file metadata
      Content stays visible in context across turns and auto-updates after edits.
      Maximum 25 files can be open simultaneously.

      Tip: Close files that are no longer relevant to free up space for new files.
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

  def info(:close, _context) do
    %{
      name: "Close",
      description: """
      Close a file or directory, removing it from your working context.
      Use this to free up space when files are no longer needed for your current task.
      This helps manage context efficiently and stay within the maximum open file limit.
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

  def info(:write, _context) do
    %{
      name: "Write",
      description: """
      Create a new file or completely overwrite an existing file.
      The entire content will replace any existing content.
      Parent directories are created if they don't exist.
      New files are automatically opened and added to context.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          file_path: %{
            type: "string",
            description: "Absolute or relative path to the file to write"
          },
          content: %{
            type: "string",
            description: "The complete content to write to the file"
          }
        },
        required: ["file_path", "content"]
      }
    }
  end

  def info(:edit, _context) do
    %{
      name: "Edit",
      description: """
      Replace an exact string in a file.
      IMPORTANT: File must be open first (use 'open' tool).
      Fails if old_string is not found in the file.
      By default, only replaces the first occurrence.
      Set replace_all to true to replace all occurrences.
      File content in context automatically refreshes after edit.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          file_path: %{
            type: "string",
            description: "Absolute or relative path to the file to edit"
          },
          old_string: %{
            type: "string",
            description: "The exact string to find and replace"
          },
          new_string: %{
            type: "string",
            description: "The replacement string"
          },
          replace_all: %{
            type: "boolean",
            description: "Replace all occurrences instead of just the first. Default: false"
          }
        },
        required: ["file_path", "old_string", "new_string"]
      }
    }
  end

  def info(:glob, _context) do
    %{
      name: "Glob",
      description: """
      Find files matching a glob pattern.
      Returns list of file paths matching the pattern.
      Supports patterns like "**/*.ex", "src/**/*.ts", etc.
      Tip: Use 'open <file>' to add files to context for viewing.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          pattern: %{
            type: "string",
            description: "Glob pattern to match (e.g., \"**/*.ex\", \"src/**/*.ts\")"
          },
          path: %{
            type: "string",
            description: "Base directory to search in. Defaults to working directory"
          }
        },
        required: ["pattern"]
      }
    }
  end

  def info(:grep, _context) do
    %{
      name: "Grep",
      description: """
      Search file contents using regex patterns.
      Returns matching files or content based on output_mode.
      Tip: Use 'open <file>' to view full content of matching files.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          pattern: %{
            type: "string",
            description: "Regex pattern to search for"
          },
          path: %{
            type: "string",
            description: "File or directory to search in. Defaults to working directory"
          },
          glob: %{
            type: "string",
            description: "Glob pattern to filter files (e.g., \"*.ex\", \"**/*.ts\")"
          },
          output_mode: %{
            type: "string",
            enum: ["files_with_matches", "content", "count"],
            description:
              "Output mode: 'files_with_matches' (default), 'content' (show lines), 'count' (match counts)"
          }
        },
        required: ["pattern"]
      }
    }
  end

  def info(:bash, _context) do
    %{
      name: "Bash",
      description: """
      Execute a shell command.
      Commands run in the working directory by default.
      Use for system operations, git commands, build tools, etc.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          command: %{
            type: "string",
            description: "The shell command to execute"
          },
          description: %{
            type: "string",
            description: "Optional description of what the command does"
          },
          workdir: %{
            type: "string",
            description: "Working directory for the command. Defaults to project root"
          },
          timeout: %{
            type: "number",
            description: "Timeout in milliseconds. Default: #{@default_timeout}"
          }
        },
        required: ["command"]
      }
    }
  end

  def info(:todo_write, _context) do
    %{
      name: "TodoWrite",
      description: """
      Create and manage a structured task list for tracking progress.
      Use this to plan complex tasks, track multi-step work, and show progress to the user.

      Each todo has:
      - content: What needs to be done (imperative form, e.g., "Fix the bug")
      - activeForm: Present continuous form shown during execution (e.g., "Fixing the bug")
      - status: "pending", "in_progress", or "completed"

      Best practices:
      - Only one task should be "in_progress" at a time
      - Mark tasks "completed" immediately after finishing
      - Break complex tasks into smaller steps
      - Use for tasks with 3+ steps
      """,
      input_schema: %{
        type: "object",
        properties: %{
          todos: %{
            type: "array",
            description: "The complete updated todo list",
            items: %{
              type: "object",
              properties: %{
                content: %{
                  type: "string",
                  description: "Task description in imperative form (e.g., 'Run tests')"
                },
                activeForm: %{
                  type: "string",
                  description: "Task description in present continuous (e.g., 'Running tests')"
                },
                status: %{
                  type: "string",
                  enum: ["pending", "in_progress", "completed"],
                  description: "Current status of the task"
                }
              },
              required: ["content", "activeForm", "status"]
            }
          }
        },
        required: ["todos"]
      }
    }
  end

  # Tool execution

  def execute(:open, args, context) do
    path = args["path"]
    lens_state = Map.get(context, :lens_state, %{})
    open_items = Map.get(lens_state, :open_items, %{})

    # Get config for max_open_files
    config = Map.get(context, :current_lens_config, %{})
    evaluated_config = evaluate_config(config, context)
    max_files = Map.get(evaluated_config, :max_open_files, @default_max_open_files)

    # Check limit BEFORE opening
    if map_size(open_items) >= max_files do
      paths = Map.keys(open_items) |> Enum.sort() |> Enum.join(", ")

      {
        "Error: Maximum #{max_files} files already open (#{paths}). Close some files first.",
        []
      }
    else
      working_dir = get_working_dir(context)
      full_path = resolve_path(path, working_dir)

      cond do
        File.regular?(full_path) ->
          # Open file
          case File.read(full_path) do
            {:ok, content} ->
              lines = String.split(content, "\n") |> length()

              item = %{
                type: :file,
                full_path: full_path,
                content: content,
                lines: lines,
                last_modified: DateTime.utc_now()
              }

              updated_items = Map.put(open_items, path, item)
              {"opened: #{path} (#{lines} lines)", [open_items: updated_items]}

            {:error, reason} ->
              {"Error: Could not read file #{path}: #{inspect(reason)}", []}
          end

        File.dir?(full_path) ->
          # Open directory
          case File.ls(full_path) do
            {:ok, entries} ->
              entries_with_metadata =
                entries
                |> Enum.sort()
                |> Enum.map(fn name ->
                  entry_path = Path.join(full_path, name)

                  if File.dir?(entry_path) do
                    %{name: name, type: :directory}
                  else
                    lines = count_lines(entry_path)
                    %{name: name, type: :file, lines: lines}
                  end
                end)

              item = %{
                type: :directory,
                full_path: full_path,
                entries: entries_with_metadata
              }

              updated_items = Map.put(open_items, path, item)

              {"opened: #{path}/ (#{length(entries_with_metadata)} entries)",
               [open_items: updated_items]}

            {:error, reason} ->
              {"Error: Could not read directory #{path}: #{inspect(reason)}", []}
          end

        true ->
          {"Error: Path not found: #{path}", []}
      end
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
      {"Error: #{path} is not open", []}
    end
  end

  def execute(:write, args, context) do
    file_path = args["file_path"]
    content = args["content"]

    # Validate content is a string/binary
    content_to_write = cond do
      is_binary(content) -> content
      is_map(content) or is_list(content) ->
        # If it's a data structure, try to encode as JSON
        case Jason.encode(content, pretty: true) do
          {:ok, json} -> json
          {:error, _} -> inspect(content, pretty: true)
        end
      true ->
        # For anything else, convert to string representation
        inspect(content, pretty: true)
    end

    working_dir = get_working_dir(context)
    full_path = resolve_path(file_path, working_dir)

    # Create parent directories if needed
    dir = Path.dirname(full_path)

    case File.mkdir_p(dir) do
      :ok ->
        case File.write(full_path, content_to_write) do
          :ok ->
            lines = content_to_write |> String.split("\n") |> length()

            # Always add to open_items (new or updated)
            lens_state = Map.get(context, :lens_state, %{})
            open_items = Map.get(lens_state, :open_items, %{})

            new_item = %{
              type: :file,
              full_path: full_path,
              content: content_to_write,
              lines: lines,
              last_modified: DateTime.utc_now()
            }

            updated_items = Map.put(open_items, file_path, new_item)

            {"Successfully wrote #{lines} lines to #{file_path} (auto-opened)",
             [open_items: updated_items]}

          {:error, reason} ->
            {"Error: Could not write to #{file_path}: #{inspect(reason)}", []}
        end

      {:error, reason} ->
        {"Error: Could not create directory #{dir}: #{inspect(reason)}", []}
    end
  end

  def execute(:edit, args, context) do
    file_path = args["file_path"]
    old_string = args["old_string"]
    new_string = args["new_string"]
    replace_all = args["replace_all"] || false

    # Check if file is open FIRST
    lens_state = Map.get(context, :lens_state, %{})
    open_items = Map.get(lens_state, :open_items, %{})

    unless Map.has_key?(open_items, file_path) do
      {
        "Error: File '#{file_path}' is not open. Use 'open #{file_path}' first.",
        []
      }
    else
      working_dir = get_working_dir(context)
      full_path = resolve_path(file_path, working_dir)

      case File.read(full_path) do
        {:ok, content} ->
          if String.contains?(content, old_string) do
            new_content =
              if replace_all do
                String.replace(content, old_string, new_string)
              else
                String.replace(content, old_string, new_string, global: false)
              end

            case File.write(full_path, new_content) do
              :ok ->
                count =
                  if replace_all do
                    # Count occurrences
                    length(String.split(content, old_string)) - 1
                  else
                    1
                  end

                # Auto-refresh: Re-read file and update open_items
                lines = String.split(new_content, "\n") |> length()

                updated_item = %{
                  open_items[file_path]
                  | content: new_content,
                    lines: lines,
                    last_modified: DateTime.utc_now()
                }

                updated_items = Map.put(open_items, file_path, updated_item)

                {"Successfully replaced #{count} occurrence(s) in #{file_path} (context auto-refreshed)",
                 [open_items: updated_items]}

              {:error, reason} ->
                {"Error: Could not write to #{file_path}: #{inspect(reason)}", []}
            end
          else
            {
              "Error: old_string not found in #{file_path}. The exact string must exist in the file.",
              []
            }
          end

        {:error, :enoent} ->
          {"Error: File not found: #{file_path}", []}

        {:error, reason} ->
          {"Error: Could not read file #{file_path}: #{inspect(reason)}", []}
      end
    end
  end

  def execute(:glob, args, context) do
    pattern = args["pattern"]
    base_path = args["path"]

    working_dir = get_working_dir(context)
    search_path = if base_path, do: resolve_path(base_path, working_dir), else: working_dir

    full_pattern =
      if String.starts_with?(pattern, "/") do
        pattern
      else
        Path.join(search_path, pattern)
      end

    matches =
      full_pattern
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()

    if Enum.empty?(matches) do
      {"No files found matching pattern: #{pattern}", []}
    else
      # Make paths relative to search_path for cleaner output
      relative_matches =
        Enum.map(matches, fn path ->
          Path.relative_to(path, search_path)
        end)

      result = Enum.join(relative_matches, "\n")

      {
        "Found #{length(matches)} file(s):\n\n#{result}\n\nTip: Use 'open <file>' to add files to context",
        []
      }
    end
  end

  def execute(:grep, args, context) do
    pattern = args["pattern"]
    search_path = args["path"]
    glob_pattern = args["glob"]
    output_mode = args["output_mode"] || "files_with_matches"

    working_dir = get_working_dir(context)
    base_path = if search_path, do: resolve_path(search_path, working_dir), else: working_dir

    case Regex.compile(pattern) do
      {:ok, regex} ->
        files = get_searchable_files(base_path, glob_pattern)
        results = search_files(files, regex, base_path, output_mode)
        format_grep_results(results, pattern, output_mode)

      {:error, reason} ->
        {"Error: Invalid regex pattern '#{pattern}': #{inspect(reason)}", []}
    end
  end

  def execute(:bash, args, context) do
    command = args["command"]
    description = args["description"]
    workdir = args["workdir"]
    timeout_ms = args["timeout"] || @default_timeout

    working_dir = if workdir, do: resolve_path(workdir, context), else: get_working_dir(context)

    # Log command if description provided
    if description do
      Logger.info("Bash: #{description}")
    end

    # Run command with timeout support
    task =
      Task.async(fn ->
        System.cmd("bash", ["-c", command],
          cd: working_dir,
          stderr_to_stdout: true,
          env: [{"TERM", "dumb"}]
        )
      end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, 0}} ->
        trimmed = String.trim(output)

        if trimmed == "" do
          {"Command completed successfully (no output)", []}
        else
          {"#{trimmed}", []}
        end

      {:ok, {output, exit_code}} ->
        trimmed = String.trim(output)
        {"Command failed with exit code #{exit_code}:\n\n#{trimmed}", []}

      nil ->
        {"Error: Command timed out after #{timeout_ms}ms", []}

      {:exit, reason} ->
        {"Error: Command crashed: #{inspect(reason)}", []}
    end
  rescue
    e in ArgumentError ->
      {"Error: Invalid command: #{Exception.message(e)}", []}

    e ->
      {"Error: Command execution failed: #{Exception.message(e)}", []}
  end

  def execute(:todo_write, args, _context) do
    todos = args["todos"] || []

    # Validate todos
    case validate_todos(todos) do
      :ok ->
        # Count by status for summary
        pending = Enum.count(todos, &(&1["status"] == "pending"))
        in_progress = Enum.count(todos, &(&1["status"] == "in_progress"))
        completed = Enum.count(todos, &(&1["status"] == "completed"))

        summary =
          "Todo list updated: #{completed} completed, #{in_progress} in progress, #{pending} pending"

        {summary, [todos: todos]}

      {:error, reason} ->
        {"Error: #{reason}", []}
    end
  end

  def execute(tool_name, _args, _context) do
    {"Error: Unknown tool: #{inspect(tool_name)}", []}
  end

  # Private helpers

  defp validate_todos(todos) when is_list(todos) do
    in_progress_count = Enum.count(todos, &(&1["status"] == "in_progress"))

    cond do
      not Enum.all?(todos, &valid_todo?/1) ->
        {:error, "Each todo must have content, activeForm, and status fields"}

      in_progress_count > 1 ->
        {:error, "Only one todo should be in_progress at a time (found #{in_progress_count})"}

      true ->
        :ok
    end
  end

  defp validate_todos(_), do: {:error, "todos must be an array"}

  defp valid_todo?(todo) when is_map(todo) do
    is_binary(todo["content"]) and
      String.length(todo["content"]) > 0 and
      is_binary(todo["activeForm"]) and
      String.length(todo["activeForm"]) > 0 and
      todo["status"] in ["pending", "in_progress", "completed"]
  end

  defp valid_todo?(_), do: false

  defp render_todos(todos) do
    lines =
      todos
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {todo, idx} ->
        status_icon =
          case todo["status"] do
            "completed" -> "[x]"
            "in_progress" -> "[>]"
            "pending" -> "[ ]"
            _ -> "[?]"
          end

        content =
          if todo["status"] == "in_progress" do
            todo["activeForm"]
          else
            todo["content"]
          end

        "#{idx}. #{status_icon} #{content}"
      end)

    """
    ## Current Tasks

    #{lines}
    """
  end

  # Render an open file or directory for context display
  defp render_open_item({path, %{type: :file, content: content, lines: lines}}) do
    # Truncate if too large
    max_lines = 500

    {display_content, truncation_note} =
      if lines > max_lines do
        truncated =
          content
          |> String.split("\n")
          |> Enum.take(max_lines)
          |> Enum.join("\n")

        {truncated, "\n\n[... #{lines - max_lines} more lines. Use offset/limit if needed.]"}
      else
        {content, ""}
      end

    numbered =
      display_content
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {line, num} ->
        "#{String.pad_leading(Integer.to_string(num), 4)} | #{line}"
      end)

    %{
      type: "text",
      text: """
      ## Open File: #{path} (#{lines} lines)

      ```
      #{numbered}
      ```
      #{truncation_note}
      """
    }
  end

  defp render_open_item({path, %{type: :directory, entries: entries}}) do
    listing =
      Enum.map_join(entries, "\n", fn entry ->
        case entry do
          %{type: :directory, name: name} -> "  #{name}/"
          %{type: :file, name: name, lines: lines} when not is_nil(lines) -> "  #{name} (#{lines} lines)"
          %{name: name} -> "  #{name}"
        end
      end)

    %{
      type: "text",
      text: """
      ## Open Directory: #{path}/ (#{length(entries)} entries)

      #{listing}
      """
    }
  end

  defp resolve_path(path, base_path) do
    if Path.type(path) == :absolute do
      path
    else
      Path.join(base_path, path) |> Path.expand()
    end
  end

  defp get_working_dir(context) do
    # Check lens config first (may contain EEx templates), then context, then cwd
    config = Map.get(context, :current_lens_config, %{})
    evaluated_config = evaluate_config(config, context)

    Map.get(evaluated_config, :working_directory) ||
      Map.get(context, :working_directory) ||
      File.cwd!()
  end

  defp count_lines(path) do
    case File.read(path) do
      {:ok, content} -> content |> String.split("\n") |> length()
      {:error, _} -> nil
    end
  end

  defp get_searchable_files(base_path, nil) do
    # Default: search all files recursively, excluding common binary/generated dirs
    exclude_dirs = ~w(.git node_modules _build deps .elixir_ls coverage)

    base_path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(fn path ->
      File.regular?(path) &&
        not Enum.any?(exclude_dirs, fn dir ->
          String.contains?(path, "/#{dir}/") || String.ends_with?(path, "/#{dir}")
        end)
    end)
  end

  defp get_searchable_files(base_path, glob_pattern) do
    full_pattern =
      if String.starts_with?(glob_pattern, "/") do
        glob_pattern
      else
        Path.join(base_path, "**/" <> glob_pattern)
      end

    full_pattern
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
  end

  defp search_files(files, regex, base_path, output_mode) do
    files
    |> Enum.reduce([], fn file, acc ->
      case File.read(file) do
        {:ok, content} ->
          relative_path = Path.relative_to(file, base_path)
          matches = find_matches(content, regex, output_mode)

          if Enum.empty?(matches) do
            acc
          else
            [{relative_path, matches} | acc]
          end

        {:error, _} ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp find_matches(content, regex, "files_with_matches") do
    if Regex.match?(regex, content), do: [:match], else: []
  end

  defp find_matches(content, regex, "count") do
    matches = Regex.scan(regex, content)
    if Enum.empty?(matches), do: [], else: [length(matches)]
  end

  defp find_matches(content, regex, "content") do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _num} -> Regex.match?(regex, line) end)
    |> Enum.map(fn {line, num} -> {num, line} end)
  end

  defp format_grep_results([], pattern, _output_mode) do
    {"No matches found for pattern: #{pattern}", []}
  end

  defp format_grep_results(results, pattern, "files_with_matches") do
    files = Enum.map(results, fn {path, _} -> path end)

    {
      "Found #{length(files)} file(s) matching '#{pattern}':\n\n#{Enum.join(files, "\n")}\n\nTip: Use 'open <file>' to view full content",
      []
    }
  end

  defp format_grep_results(results, pattern, "count") do
    lines =
      Enum.map_join(results, "\n", fn {path, [count]} ->
        "#{path}: #{count} match(es)"
      end)

    total = Enum.reduce(results, 0, fn {_, [count]}, acc -> acc + count end)
    {"Found #{total} total match(es) for '#{pattern}':\n\n#{lines}", []}
  end

  defp format_grep_results(results, pattern, "content") do
    output =
      Enum.map_join(results, "\n\n", fn {path, matches} ->
        lines =
          Enum.map_join(matches, "\n", fn {num, line} ->
            truncated = truncate_line(line, @max_line_length)
            "  #{num}: #{truncated}"
          end)

        "#{path}:\n#{lines}"
      end)

    match_count = Enum.reduce(results, 0, fn {_, matches}, acc -> acc + length(matches) end)

    {
      "Found #{match_count} match(es) for '#{pattern}' in #{length(results)} file(s):\n\n#{output}",
      []
    }
  end

  defp truncate_line(line, max_length) do
    if String.length(line) > max_length do
      String.slice(line, 0, max_length) <> "..."
    else
      line
    end
  end

  # Evaluate EEx templates in config values
  # This allows dynamic configuration using context values like:
  # system_prompt: "<%= Map.get(@context, :system_prompt, \"default\") %>"
  defp evaluate_config(config, context) when is_map(config) do
    Map.new(config, fn {key, value} ->
      {key, evaluate_template_value(value, context)}
    end)
  end

  defp evaluate_config(config, _context), do: config

  # Evaluate a single value - recursively handle strings, maps, and lists
  defp evaluate_template_value(value, context) when is_binary(value) do
    # Check if string contains EEx markers
    if String.contains?(value, "<%") do
      try do
        assigns = %{context: context}
        EEx.eval_string(value, assigns: assigns)
      rescue
        error ->
          Logger.warning(
            "Failed to evaluate EEx template in lens config: #{Exception.message(error)}"
          )

          # Return original value on failure
          value
      end
    else
      value
    end
  end

  defp evaluate_template_value(value, context) when is_map(value) do
    evaluate_config(value, context)
  end

  defp evaluate_template_value(value, context) when is_list(value) do
    Enum.map(value, &evaluate_template_value(&1, context))
  end

  defp evaluate_template_value(value, _context), do: value
end
