defmodule Koalemos.Lenses.FileNavigationLensTest do
  use ExUnit.Case, async: true

  alias Koalemos.Lenses.FileNavigationLens

  @test_dir "test/fixtures/file_navigation"

  setup do
    # Create test directory and files
    File.mkdir_p!(@test_dir)
    File.write!(Path.join(@test_dir, "sample.ex"), "defmodule Sample do\n  def hello, do: :world\nend\n")
    File.write!(Path.join(@test_dir, "readme.md"), "# Test\n\nThis is a test file.\n")
    File.mkdir_p!(Path.join(@test_dir, "subdir"))
    File.write!(Path.join(@test_dir, "subdir/nested.ex"), "defmodule Nested do\nend\n")

    on_exit(fn ->
      File.rm_rf!(@test_dir)
    end)

    :ok
  end

  describe "tools/1" do
    test "returns open and close tools" do
      tools = FileNavigationLens.tools()

      assert length(tools) == 2
      assert {FileNavigationLens, :open} in tools
      assert {FileNavigationLens, :close} in tools
    end
  end

  describe "info/1" do
    test "returns schema for open tool" do
      info = FileNavigationLens.info(:open)

      assert info.name == "open"
      assert info.input_schema.properties.path.type == "string"
      assert "path" in info.input_schema.required
    end

    test "returns schema for close tool" do
      info = FileNavigationLens.info(:close)

      assert info.name == "close"
      assert info.input_schema.properties.path.type == "string"
      assert "path" in info.input_schema.required
    end
  end

  describe "execute(:open, ...) for files" do
    test "opens a file successfully" do
      context = %{working_directory: File.cwd!()}
      args = %{"path" => Path.join(@test_dir, "sample.ex")}

      {result, lens_updates} = FileNavigationLens.execute(:open, args, context)

      assert result =~ "opened:"
      assert result =~ "lines"
      assert Keyword.has_key?(lens_updates, :open_items)

      open_items = Keyword.get(lens_updates, :open_items)
      path = Path.join(@test_dir, "sample.ex")
      assert Map.has_key?(open_items, path)
      assert open_items[path].type == :file
      assert open_items[path].content =~ "defmodule Sample"
    end

    test "returns error for non-existent file" do
      context = %{working_directory: File.cwd!()}
      args = %{"path" => "nonexistent.ex"}

      {result, lens_updates} = FileNavigationLens.execute(:open, args, context)

      assert result =~ "error: path not found"
      assert lens_updates == []
    end
  end

  describe "execute(:open, ...) for directories" do
    test "opens a directory successfully" do
      context = %{working_directory: File.cwd!()}
      args = %{"path" => @test_dir}

      {result, lens_updates} = FileNavigationLens.execute(:open, args, context)

      assert result =~ "opened:"
      assert result =~ "entries"
      assert Keyword.has_key?(lens_updates, :open_items)

      open_items = Keyword.get(lens_updates, :open_items)
      assert Map.has_key?(open_items, @test_dir)
      assert open_items[@test_dir].type == :directory
      assert is_list(open_items[@test_dir].entries)
    end

    test "directory entries include metadata" do
      context = %{working_directory: File.cwd!()}
      args = %{"path" => @test_dir}

      {_result, lens_updates} = FileNavigationLens.execute(:open, args, context)

      open_items = Keyword.get(lens_updates, :open_items)
      entries = open_items[@test_dir].entries

      # Find the subdir entry
      subdir_entry = Enum.find(entries, fn e -> e.name == "subdir" end)
      assert subdir_entry.type == :directory

      # Find a file entry
      sample_entry = Enum.find(entries, fn e -> e.name == "sample.ex" end)
      assert sample_entry.type == :file
      assert is_integer(sample_entry.lines)
    end
  end

  describe "execute(:close, ...)" do
    test "closes an open file" do
      path = Path.join(@test_dir, "sample.ex")

      context = %{
        working_directory: File.cwd!(),
        lens_state: %{
          open_items: %{
            path => %{type: :file, content: "...", lines: 3}
          }
        }
      }

      args = %{"path" => path}

      {result, lens_updates} = FileNavigationLens.execute(:close, args, context)

      assert result =~ "closed:"
      open_items = Keyword.get(lens_updates, :open_items)
      refute Map.has_key?(open_items, path)
    end

    test "returns error when closing file that's not open" do
      context = %{
        working_directory: File.cwd!(),
        lens_state: %{open_items: %{}}
      }

      args = %{"path" => "not_open.ex"}

      {result, lens_updates} = FileNavigationLens.execute(:close, args, context)

      assert result =~ "error: not open"
      assert lens_updates == []
    end
  end

  describe "provide_context/2" do
    test "returns empty list when no files open" do
      state = %{context: %{lens_state: %{open_items: %{}}}}

      blocks = FileNavigationLens.provide_context(state)

      assert blocks == []
    end

    test "renders open file with line numbers" do
      path = Path.join(@test_dir, "sample.ex")
      content = "line 1\nline 2\nline 3\n"

      state = %{
        context: %{
          lens_state: %{
            open_items: %{
              path => %{type: :file, content: content, lines: 4}
            }
          }
        }
      }

      blocks = FileNavigationLens.provide_context(state)

      assert length(blocks) == 1
      [block] = blocks
      assert block.type == "text"
      assert block.text =~ "File: #{path}"
      assert block.text =~ "1 | line 1"
      assert block.text =~ "2 | line 2"
    end

    test "renders open directory with listing" do
      state = %{
        context: %{
          lens_state: %{
            open_items: %{
              @test_dir => %{
                type: :directory,
                entries: [
                  %{name: "file.ex", type: :file, lines: 10},
                  %{name: "subdir", type: :directory}
                ]
              }
            }
          }
        }
      }

      blocks = FileNavigationLens.provide_context(state)

      assert length(blocks) == 1
      [block] = blocks
      assert block.type == "text"
      assert block.text =~ "Directory: #{@test_dir}"
      assert block.text =~ "file.ex (10 lines)"
      assert block.text =~ "subdir/"
    end

    test "renders multiple open items sorted by path" do
      state = %{
        context: %{
          lens_state: %{
            open_items: %{
              "z_file.ex" => %{type: :file, content: "z", lines: 1},
              "a_file.ex" => %{type: :file, content: "a", lines: 1}
            }
          }
        }
      }

      blocks = FileNavigationLens.provide_context(state)

      assert length(blocks) == 2
      # Should be sorted: a_file first, z_file second
      assert Enum.at(blocks, 0).text =~ "a_file.ex"
      assert Enum.at(blocks, 1).text =~ "z_file.ex"
    end
  end
end
