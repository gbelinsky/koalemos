defmodule Koalemos.Lenses.TraditionalAgentLensTest do
  use ExUnit.Case, async: true

  alias Koalemos.Lenses.TraditionalAgentLens

  @test_dir "test/fixtures/traditional_agent"

  setup do
    # Create test directory and files
    File.mkdir_p!(@test_dir)
    File.write!(Path.join(@test_dir, "sample.ex"), "defmodule Sample do\n  def hello, do: :world\nend\n")
    File.write!(Path.join(@test_dir, "readme.md"), "# Test\n\nThis is a test file.\n")
    File.mkdir_p!(Path.join(@test_dir, "subdir"))
    File.write!(Path.join(@test_dir, "subdir/nested.ex"), "defmodule Nested do\n  def nested, do: :ok\nend\n")

    on_exit(fn ->
      File.rm_rf!(@test_dir)
    end)

    {:ok, working_dir: File.cwd!()}
  end

  describe "tools/1" do
    test "returns all seven tools" do
      tools = TraditionalAgentLens.tools()

      assert length(tools) == 7
      assert {TraditionalAgentLens, :read} in tools
      assert {TraditionalAgentLens, :write} in tools
      assert {TraditionalAgentLens, :edit} in tools
      assert {TraditionalAgentLens, :glob} in tools
      assert {TraditionalAgentLens, :grep} in tools
      assert {TraditionalAgentLens, :bash} in tools
      assert {TraditionalAgentLens, :todo_write} in tools
    end
  end

  describe "info/2" do
    test "returns schema for Read tool" do
      info = TraditionalAgentLens.info(:read)

      assert info.name == "Read"
      assert info.input_schema.properties.file_path.type == "string"
      assert info.input_schema.properties.offset.type == "number"
      assert info.input_schema.properties.limit.type == "number"
      assert "file_path" in info.input_schema.required
    end

    test "returns schema for Write tool" do
      info = TraditionalAgentLens.info(:write)

      assert info.name == "Write"
      assert info.input_schema.properties.file_path.type == "string"
      assert info.input_schema.properties.content.type == "string"
      assert "file_path" in info.input_schema.required
      assert "content" in info.input_schema.required
    end

    test "returns schema for Edit tool" do
      info = TraditionalAgentLens.info(:edit)

      assert info.name == "Edit"
      assert info.input_schema.properties.file_path.type == "string"
      assert info.input_schema.properties.old_string.type == "string"
      assert info.input_schema.properties.new_string.type == "string"
      assert info.input_schema.properties.replace_all.type == "boolean"
      assert "file_path" in info.input_schema.required
      assert "old_string" in info.input_schema.required
      assert "new_string" in info.input_schema.required
    end

    test "returns schema for Glob tool" do
      info = TraditionalAgentLens.info(:glob)

      assert info.name == "Glob"
      assert info.input_schema.properties.pattern.type == "string"
      assert info.input_schema.properties.path.type == "string"
      assert "pattern" in info.input_schema.required
    end

    test "returns schema for Grep tool" do
      info = TraditionalAgentLens.info(:grep)

      assert info.name == "Grep"
      assert info.input_schema.properties.pattern.type == "string"
      assert info.input_schema.properties.path.type == "string"
      assert info.input_schema.properties.glob.type == "string"
      assert info.input_schema.properties.output_mode.type == "string"
      assert "pattern" in info.input_schema.required
    end

    test "returns schema for Bash tool" do
      info = TraditionalAgentLens.info(:bash)

      assert info.name == "Bash"
      assert info.input_schema.properties.command.type == "string"
      assert info.input_schema.properties.description.type == "string"
      assert info.input_schema.properties.workdir.type == "string"
      assert info.input_schema.properties.timeout.type == "number"
      assert "command" in info.input_schema.required
    end
  end

  describe "execute(:read, ...)" do
    test "reads a file with line numbers", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"file_path" => Path.join(@test_dir, "sample.ex")}

      {result, lens_updates} = TraditionalAgentLens.execute(:read, args, context)

      assert result =~ "File: #{Path.join(@test_dir, "sample.ex")}"
      assert result =~ "1: defmodule Sample do"
      assert result =~ "2:   def hello, do: :world"
      assert result =~ "3: end"
      assert lens_updates == []
    end

    test "supports offset parameter", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"file_path" => Path.join(@test_dir, "sample.ex"), "offset" => 1}

      {result, _} = TraditionalAgentLens.execute(:read, args, context)

      # Should start from line 2 (0-based offset of 1)
      assert result =~ "2:   def hello, do: :world"
      refute result =~ "1: defmodule"
    end

    test "supports limit parameter", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"file_path" => Path.join(@test_dir, "sample.ex"), "limit" => 1}

      {result, _} = TraditionalAgentLens.execute(:read, args, context)

      assert result =~ "1: defmodule Sample do"
      refute result =~ "2:   def hello"
    end

    test "returns error for non-existent file", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"file_path" => "nonexistent.ex"}

      {result, lens_updates} = TraditionalAgentLens.execute(:read, args, context)

      assert result =~ "Error: File not found"
      assert lens_updates == []
    end

    test "returns error for directory", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"file_path" => @test_dir}

      {result, lens_updates} = TraditionalAgentLens.execute(:read, args, context)

      assert result =~ "Error: Path is a directory"
      assert lens_updates == []
    end
  end

  describe "execute(:write, ...)" do
    test "writes a new file", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      new_file = Path.join(@test_dir, "new_file.ex")
      args = %{"file_path" => new_file, "content" => "defmodule New do\nend\n"}

      {result, lens_updates} = TraditionalAgentLens.execute(:write, args, context)

      assert result =~ "Successfully wrote"
      assert result =~ "lines"
      assert lens_updates == []
      assert File.read!(new_file) == "defmodule New do\nend\n"
    end

    test "overwrites existing file", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      existing_file = Path.join(@test_dir, "sample.ex")
      args = %{"file_path" => existing_file, "content" => "# overwritten\n"}

      {result, _} = TraditionalAgentLens.execute(:write, args, context)

      assert result =~ "Successfully wrote"
      assert File.read!(existing_file) == "# overwritten\n"
    end

    test "creates parent directories", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      deep_file = Path.join(@test_dir, "deep/nested/file.ex")
      args = %{"file_path" => deep_file, "content" => "content\n"}

      {result, _} = TraditionalAgentLens.execute(:write, args, context)

      assert result =~ "Successfully wrote"
      assert File.exists?(deep_file)
    end
  end

  describe "execute(:edit, ...)" do
    test "replaces first occurrence by default", %{working_dir: working_dir} do
      # Create a file with repeated content
      test_file = Path.join(@test_dir, "edit_test.ex")
      File.write!(test_file, "hello world\nhello again\n")

      context = %{working_directory: working_dir}
      args = %{"file_path" => test_file, "old_string" => "hello", "new_string" => "goodbye"}

      {result, lens_updates} = TraditionalAgentLens.execute(:edit, args, context)

      assert result =~ "Successfully replaced 1 occurrence"
      assert lens_updates == []
      assert File.read!(test_file) == "goodbye world\nhello again\n"
    end

    test "replaces all occurrences when replace_all is true", %{working_dir: working_dir} do
      test_file = Path.join(@test_dir, "edit_all_test.ex")
      File.write!(test_file, "hello world\nhello again\n")

      context = %{working_directory: working_dir}
      args = %{"file_path" => test_file, "old_string" => "hello", "new_string" => "goodbye", "replace_all" => true}

      {result, _} = TraditionalAgentLens.execute(:edit, args, context)

      assert result =~ "Successfully replaced 2 occurrence"
      assert File.read!(test_file) == "goodbye world\ngoodbye again\n"
    end

    test "returns error when old_string not found", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"file_path" => Path.join(@test_dir, "sample.ex"), "old_string" => "not_found", "new_string" => "replacement"}

      {result, lens_updates} = TraditionalAgentLens.execute(:edit, args, context)

      assert result =~ "Error: old_string not found"
      assert lens_updates == []
    end

    test "returns error for non-existent file", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"file_path" => "nonexistent.ex", "old_string" => "a", "new_string" => "b"}

      {result, _} = TraditionalAgentLens.execute(:edit, args, context)

      assert result =~ "Error: File not found"
    end
  end

  describe "execute(:glob, ...)" do
    test "finds files matching pattern", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "**/*.ex", "path" => @test_dir}

      {result, lens_updates} = TraditionalAgentLens.execute(:glob, args, context)

      assert result =~ "Found"
      assert result =~ "sample.ex"
      assert result =~ "subdir/nested.ex"
      assert lens_updates == []
    end

    test "returns message when no files match", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "**/*.xyz", "path" => @test_dir}

      {result, _} = TraditionalAgentLens.execute(:glob, args, context)

      assert result =~ "No files found"
    end

    test "uses working directory when path not specified", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "test/fixtures/traditional_agent/**/*.ex"}

      {result, _} = TraditionalAgentLens.execute(:glob, args, context)

      assert result =~ "Found"
      assert result =~ ".ex"
    end
  end

  describe "execute(:grep, ...)" do
    test "finds files with matches (default output mode)", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "defmodule", "path" => @test_dir}

      {result, lens_updates} = TraditionalAgentLens.execute(:grep, args, context)

      assert result =~ "Found"
      assert result =~ "file(s) matching"
      assert result =~ "sample.ex"
      assert lens_updates == []
    end

    test "shows content with content output mode", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "hello", "path" => @test_dir, "output_mode" => "content"}

      {result, _} = TraditionalAgentLens.execute(:grep, args, context)

      assert result =~ "def hello, do: :world"
    end

    test "shows count with count output mode", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "def", "path" => @test_dir, "output_mode" => "count"}

      {result, _} = TraditionalAgentLens.execute(:grep, args, context)

      assert result =~ "match(es)"
    end

    test "filters by glob pattern", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "defmodule", "path" => @test_dir, "glob" => "*.md"}

      {result, _} = TraditionalAgentLens.execute(:grep, args, context)

      assert result =~ "No matches found"
    end

    test "returns error for invalid regex", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"pattern" => "[invalid", "path" => @test_dir}

      {result, _} = TraditionalAgentLens.execute(:grep, args, context)

      assert result =~ "Error: Invalid regex"
    end
  end

  describe "execute(:bash, ...)" do
    test "executes simple command", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"command" => "echo hello"}

      {result, lens_updates} = TraditionalAgentLens.execute(:bash, args, context)

      assert result == "hello"
      assert lens_updates == []
    end

    test "returns exit code on failure", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"command" => "exit 1"}

      {result, _} = TraditionalAgentLens.execute(:bash, args, context)

      assert result =~ "Command failed with exit code 1"
    end

    test "uses specified workdir", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"command" => "pwd", "workdir" => @test_dir}

      {result, _} = TraditionalAgentLens.execute(:bash, args, context)

      assert result =~ @test_dir
    end

    test "captures stderr", %{working_dir: working_dir} do
      context = %{working_directory: working_dir}
      args = %{"command" => "echo error >&2"}

      {result, _} = TraditionalAgentLens.execute(:bash, args, context)

      assert result =~ "error"
    end
  end

  describe "provide_context/2" do
    test "returns empty when no system_prompt and no todos" do
      state = %{context: %{}}
      config = %{}

      blocks = TraditionalAgentLens.provide_context(state, config)

      assert blocks == []
    end

    test "includes system_prompt when provided" do
      state = %{context: %{}}
      config = %{system_prompt: "You are a helpful assistant."}

      blocks = TraditionalAgentLens.provide_context(state, config)

      assert length(blocks) == 1
      [block] = blocks
      assert block.type == "text"
      assert block.text == "You are a helpful assistant."
    end

    test "includes todo list when todos exist" do
      todos = [
        %{"content" => "First task", "activeForm" => "Doing first task", "status" => "completed"},
        %{"content" => "Second task", "activeForm" => "Doing second task", "status" => "in_progress"},
        %{"content" => "Third task", "activeForm" => "Doing third task", "status" => "pending"}
      ]

      state = %{context: %{lens_state: %{todos: todos}}}
      config = %{}

      blocks = TraditionalAgentLens.provide_context(state, config)

      assert length(blocks) == 1
      [todo_block] = blocks
      assert todo_block.type == "text"
      assert todo_block.text =~ "Current Tasks"
      assert todo_block.text =~ "[x] First task"
      assert todo_block.text =~ "[>] Doing second task"
      assert todo_block.text =~ "[ ] Third task"
    end

    test "includes both system_prompt and todos" do
      todos = [
        %{"content" => "Task 1", "activeForm" => "Doing task 1", "status" => "pending"}
      ]

      state = %{context: %{lens_state: %{todos: todos}}}
      config = %{system_prompt: "Custom system prompt here."}

      blocks = TraditionalAgentLens.provide_context(state, config)

      assert length(blocks) == 2
      [prompt_block, todo_block] = blocks
      assert prompt_block.text == "Custom system prompt here."
      assert todo_block.text =~ "Current Tasks"
    end
  end

  describe "info(:todo_write, ...)" do
    test "returns schema for TodoWrite tool" do
      info = TraditionalAgentLens.info(:todo_write)

      assert info.name == "TodoWrite"
      assert info.input_schema.properties.todos.type == "array"
      assert "todos" in info.input_schema.required
    end
  end

  describe "execute(:todo_write, ...)" do
    test "creates a todo list" do
      context = %{}
      todos = [
        %{"content" => "Task 1", "activeForm" => "Doing task 1", "status" => "pending"},
        %{"content" => "Task 2", "activeForm" => "Doing task 2", "status" => "pending"}
      ]
      args = %{"todos" => todos}

      {result, lens_updates} = TraditionalAgentLens.execute(:todo_write, args, context)

      assert result =~ "Todo list updated"
      assert result =~ "0 completed"
      assert result =~ "0 in progress"
      assert result =~ "2 pending"
      assert Keyword.get(lens_updates, :todos) == todos
    end

    test "tracks in_progress and completed" do
      context = %{}
      todos = [
        %{"content" => "Task 1", "activeForm" => "Doing task 1", "status" => "completed"},
        %{"content" => "Task 2", "activeForm" => "Doing task 2", "status" => "in_progress"},
        %{"content" => "Task 3", "activeForm" => "Doing task 3", "status" => "pending"}
      ]
      args = %{"todos" => todos}

      {result, _} = TraditionalAgentLens.execute(:todo_write, args, context)

      assert result =~ "1 completed"
      assert result =~ "1 in progress"
      assert result =~ "1 pending"
    end

    test "rejects multiple in_progress todos" do
      context = %{}
      todos = [
        %{"content" => "Task 1", "activeForm" => "Doing task 1", "status" => "in_progress"},
        %{"content" => "Task 2", "activeForm" => "Doing task 2", "status" => "in_progress"}
      ]
      args = %{"todos" => todos}

      {result, lens_updates} = TraditionalAgentLens.execute(:todo_write, args, context)

      assert result =~ "Error"
      assert result =~ "Only one todo should be in_progress"
      assert lens_updates == []
    end

    test "rejects invalid todo format" do
      context = %{}
      args = %{"todos" => [%{"content" => "Missing fields"}]}

      {result, lens_updates} = TraditionalAgentLens.execute(:todo_write, args, context)

      assert result =~ "Error"
      assert lens_updates == []
    end

    test "rejects empty content" do
      context = %{}
      todos = [%{"content" => "", "activeForm" => "Doing", "status" => "pending"}]
      args = %{"todos" => todos}

      {result, lens_updates} = TraditionalAgentLens.execute(:todo_write, args, context)

      assert result =~ "Error"
      assert lens_updates == []
    end
  end
end
