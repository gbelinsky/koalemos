defmodule Koalemos.Lenses.TraditionalAgentLens do
  @moduledoc """
  TraditionalAgentLens provides opencode-compatible tools for fair comparison testing.

  This lens implements identical tool names, parameters, and behaviors to opencode,
  enabling direct comparison between traditional agent approaches and Koalemos's
  dynamic context approaches.

  ## Design Philosophy

  - Minimal context: just basic tool instructions
  - No dynamic context injection - agent must explicitly read files
  - No automatic file state, AST analysis, or relationship mapping
  - Tool behaviors and limitations match opencode exactly

  ## Tools

  - `Read` - Read file contents with line numbers
  - `Write` - Create or overwrite files
  - `Edit` - Exact string replacement in files
  - `Glob` - Find files by pattern
  - `Grep` - Search file contents with regex
  - `Bash` - Execute shell commands
  - `TodoWrite` - Manage task list for tracking progress

  ## Usage

  ```elixir
  lenses: [
    ["Koalemos.Lenses.TraditionalAgentLens", %{
      working_directory: "/path/to/project"
    }]
  ]
  ```
  """

  require Logger

  @default_timeout 120_000
  @default_read_limit 2000
  @max_line_length 2000

  @doc """
  Provide context including optional static system prompt and current todos.

  Config options:
  - `system_prompt` - Static system prompt to inject (for comparison testing).
                      Supports EEx templates with @context access.
  - `working_directory` - Base directory for file operations.
                          Supports EEx templates with @context access.
  """
  def provide_context(state, config \\ %{}) do
    lens_state = Map.get(state.context, :lens_state, %{})
    todos = Map.get(lens_state, :todos, [])

    # Evaluate config templates with context
    evaluated_config = evaluate_config(config, state.context)

    # Start with static system prompt if provided
    system_prompt_block =
      case Map.get(evaluated_config, :system_prompt) do
        nil -> []
        "" -> []  # Explicitly filter empty strings
        prompt when is_binary(prompt) -> [%{type: "text", text: prompt}]
        _ -> []
      end

    # Add todo context if todos exist
    todo_block =
      if Enum.empty?(todos) do
        []
      else
        [%{type: "text", text: render_todos(todos)}]
      end

    system_prompt_block ++ todo_block
  end

  @doc """
  Provide tool definitions for this lens.
  """
  def tools(_config \\ %{}) do
    [
      {__MODULE__, :read},
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

  def info(:read, _context) do
    %{
      name: "Read",
      description: """
      Read file contents with line numbers.
      Returns content with line number prefix (e.g., "42: content").
      Lines longer than #{@max_line_length} characters are truncated.
      """,
      input_schema: %{
        type: "object",
        properties: %{
          file_path: %{
            type: "string",
            description: "Absolute or relative path to the file to read"
          },
          offset: %{
            type: "number",
            description: "Line number to start from (0-based). Default: 0"
          },
          limit: %{
            type: "number",
            description: "Maximum number of lines to read. Default: #{@default_read_limit}"
          }
        },
        required: ["file_path"]
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
      Fails if old_string is not found in the file.
      By default, only replaces the first occurrence.
      Set replace_all to true to replace all occurrences.
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

  def execute(:read, args, context) do
    file_path = args["file_path"]
    offset = args["offset"] || 0
    limit = args["limit"] || @default_read_limit

    full_path = resolve_path(file_path, context)

    case File.read(full_path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n")
          |> Enum.drop(offset)
          |> Enum.take(limit)
          |> Enum.with_index(offset + 1)
          |> Enum.map_join("\n", fn {line, num} ->
            truncated = truncate_line(line, @max_line_length)
            "#{num}: #{truncated}"
          end)

        total_lines = content |> String.split("\n") |> length()
        shown_lines = min(limit, max(0, total_lines - offset))

        header = "File: #{file_path} (#{total_lines} total lines, showing #{shown_lines} from line #{offset + 1})\n\n"
        {header <> lines, []}

      {:error, :enoent} ->
        {"Error: File not found: #{file_path}", []}

      {:error, :eisdir} ->
        {"Error: Path is a directory, not a file: #{file_path}", []}

      {:error, reason} ->
        {"Error: Could not read file #{file_path}: #{inspect(reason)}", []}
    end
  end

  def execute(:write, args, context) do
    file_path = args["file_path"]
    content = args["content"]

    full_path = resolve_path(file_path, context)

    # Create parent directories if needed
    dir = Path.dirname(full_path)

    case File.mkdir_p(dir) do
      :ok ->
        case File.write(full_path, content) do
          :ok ->
            lines = content |> String.split("\n") |> length()
            {"Successfully wrote #{lines} lines to #{file_path}", []}

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

    full_path = resolve_path(file_path, context)

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

              {"Successfully replaced #{count} occurrence(s) in #{file_path}", []}

            {:error, reason} ->
              {"Error: Could not write to #{file_path}: #{inspect(reason)}", []}
          end
        else
          {"Error: old_string not found in #{file_path}. The exact string must exist in the file.", []}
        end

      {:error, :enoent} ->
        {"Error: File not found: #{file_path}", []}

      {:error, reason} ->
        {"Error: Could not read file #{file_path}: #{inspect(reason)}", []}
    end
  end

  def execute(:glob, args, context) do
    pattern = args["pattern"]
    base_path = args["path"]

    search_path = if base_path, do: resolve_path(base_path, context), else: get_working_dir(context)

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
      {"Found #{length(matches)} file(s):\n\n#{result}", []}
    end
  end

  def execute(:grep, args, context) do
    pattern = args["pattern"]
    search_path = args["path"]
    glob_pattern = args["glob"]
    output_mode = args["output_mode"] || "files_with_matches"

    base_path = if search_path, do: resolve_path(search_path, context), else: get_working_dir(context)

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

        summary = "Todo list updated: #{completed} completed, #{in_progress} in progress, #{pending} pending"
        {summary, [todos: todos]}

      {:error, reason} ->
        {"Error: #{reason}", []}
    end
  end

  def execute(tool_name, _args, _context) do
    {"Error: Unknown tool: #{inspect(tool_name)}", []}
  end

  # Private helpers

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
          Logger.warning("Failed to evaluate EEx template in lens config: #{Exception.message(error)}")
          value  # Return original value on failure
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

  defp resolve_path(path, context) do
    base = get_working_dir(context)

    if Path.type(path) == :absolute do
      path
    else
      Path.join(base, path) |> Path.expand()
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

  defp truncate_line(line, max_length) do
    if String.length(line) > max_length do
      String.slice(line, 0, max_length) <> "..."
    else
      line
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
    {"Found #{length(files)} file(s) matching '#{pattern}':\n\n#{Enum.join(files, "\n")}", []}
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
    {"Found #{match_count} match(es) for '#{pattern}' in #{length(results)} file(s):\n\n#{output}", []}
  end
end
