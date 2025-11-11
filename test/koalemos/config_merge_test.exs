defmodule Koalemos.ConfigMergeTest do
  use ExUnit.Case, async: true
  alias Koalemos.ConfigMerge

  describe "runtime_priority/1" do
    test "runtime overrides static" do
      config_sources = %{
        static: %{a: 1, b: 2},
        runtime: %{b: 3, c: 4}
      }

      assert ConfigMerge.runtime_priority(config_sources) == %{a: 1, b: 3, c: 4}
    end

    test "static used when runtime empty" do
      config_sources = %{
        static: %{timeout: 30, max_retries: 3},
        runtime: %{}
      }

      assert ConfigMerge.runtime_priority(config_sources) == %{timeout: 30, max_retries: 3}
    end

    test "runtime used when static empty" do
      config_sources = %{
        static: %{},
        runtime: %{model: "claude-4"}
      }

      assert ConfigMerge.runtime_priority(config_sources) == %{model: "claude-4"}
    end

    test "both empty returns empty" do
      config_sources = %{static: %{}, runtime: %{}}
      assert ConfigMerge.runtime_priority(config_sources) == %{}
    end
  end

  describe "static_priority/1" do
    test "static overrides runtime" do
      config_sources = %{
        static: %{a: 1, b: 2},
        runtime: %{b: 3, c: 4}
      }

      assert ConfigMerge.static_priority(config_sources) == %{a: 1, b: 2, c: 4}
    end

    test "static always wins for shared keys" do
      config_sources = %{
        static: %{critical_setting: "DO_NOT_OVERRIDE"},
        runtime: %{critical_setting: "attempted_override"}
      }

      result = ConfigMerge.static_priority(config_sources)
      assert result.critical_setting == "DO_NOT_OVERRIDE"
    end
  end

  describe "get_key/3" do
    test "runtime key takes priority" do
      config_sources = %{
        static: %{timeout: 30},
        runtime: %{timeout: 60}
      }

      assert ConfigMerge.get_key(config_sources, :timeout, 10) == 60
    end

    test "static key used when runtime missing" do
      config_sources = %{
        static: %{timeout: 30},
        runtime: %{}
      }

      assert ConfigMerge.get_key(config_sources, :timeout, 10) == 30
    end

    test "default used when both missing" do
      config_sources = %{
        static: %{},
        runtime: %{}
      }

      assert ConfigMerge.get_key(config_sources, :timeout, 10) == 10
    end

    test "nil default when not specified" do
      config_sources = %{static: %{}, runtime: %{}}
      assert ConfigMerge.get_key(config_sources, :missing_key) == nil
    end

    test "handles atom and string keys correctly" do
      config_sources = %{
        static: %{action: "static_action"},
        runtime: %{"action" => "runtime_action"}
      }

      # Atom key checks runtime and static
      assert ConfigMerge.get_key(config_sources, :action) == "static_action"
    end
  end

  describe "merge_lenses/2" do
    test "config lenses override base lenses for same module" do
      base = [["PersonaLens", %{personas: [:professional]}]]
      config = [["PersonaLens", %{personas: [:casual]}]]

      result = ConfigMerge.merge_lenses(base, config)

      assert result == [["PersonaLens", %{personas: [:casual]}]]
    end

    test "config lenses add to base lenses" do
      base = [["PersonaLens", %{}], ["Scratchpad", %{}]]
      config = [["FileSystem", %{root: "/tmp"}]]

      result = ConfigMerge.merge_lenses(base, config)

      assert length(result) == 3
      assert ["PersonaLens", %{}] in result
      assert ["Scratchpad", %{}] in result
      assert ["FileSystem", %{root: "/tmp"}] in result
    end

    test "handles mix of override and add" do
      base = [
        ["PersonaLens", %{personas: [:professional]}],
        ["Scratchpad", %{}]
      ]

      config = [
        ["PersonaLens", %{personas: [:casual]}],
        ["FileSystem", %{}]
      ]

      result = ConfigMerge.merge_lenses(base, config)

      assert length(result) == 3

      # PersonaLens should be overridden
      persona_lens = Enum.find(result, fn [mod, _] -> mod == "PersonaLens" end)
      assert persona_lens == ["PersonaLens", %{personas: [:casual]}]

      # Scratchpad should be preserved
      assert ["Scratchpad", %{}] in result

      # FileSystem should be added
      assert ["FileSystem", %{}] in result
    end

    test "empty base with config lenses" do
      base = []
      config = [["PersonaLens", %{personas: [:technical]}]]

      result = ConfigMerge.merge_lenses(base, config)

      assert result == [["PersonaLens", %{personas: [:technical]}]]
    end

    test "base lenses with empty config" do
      base = [["PersonaLens", %{}], ["Scratchpad", %{}]]
      config = []

      result = ConfigMerge.merge_lenses(base, config)

      assert result == [["PersonaLens", %{}], ["Scratchpad", %{}]]
    end

    test "both empty returns empty" do
      result = ConfigMerge.merge_lenses([], [])
      assert result == []
    end

    test "handles lenses without config (string only)" do
      base = ["PersonaLens", "Scratchpad"]
      config = ["FileSystem"]

      result = ConfigMerge.merge_lenses(base, config)

      assert length(result) == 3
      assert ["PersonaLens", %{}] in result
      assert ["Scratchpad", %{}] in result
      assert ["FileSystem", %{}] in result
    end

    test "override lens without config to lens with config" do
      base = ["PersonaLens"]
      config = [["PersonaLens", %{personas: [:casual]}]]

      result = ConfigMerge.merge_lenses(base, config)

      assert result == [["PersonaLens", %{personas: [:casual]}]]
    end
  end

  describe "runtime_only/1" do
    test "returns only runtime config" do
      config_sources = %{
        static: %{a: 1, b: 2},
        runtime: %{c: 3, d: 4}
      }

      assert ConfigMerge.runtime_only(config_sources) == %{c: 3, d: 4}
    end

    test "returns empty map when runtime empty" do
      config_sources = %{static: %{a: 1}, runtime: %{}}
      assert ConfigMerge.runtime_only(config_sources) == %{}
    end
  end

  describe "static_only/1" do
    test "returns only static config" do
      config_sources = %{
        static: %{a: 1, b: 2},
        runtime: %{c: 3, d: 4}
      }

      assert ConfigMerge.static_only(config_sources) == %{a: 1, b: 2}
    end

    test "returns empty map when static empty" do
      config_sources = %{static: %{}, runtime: %{a: 1}}
      assert ConfigMerge.static_only(config_sources) == %{}
    end
  end

  describe "both_sources/1" do
    test "returns tuple of both sources" do
      config_sources = %{
        static: %{a: 1},
        runtime: %{b: 2}
      }

      assert ConfigMerge.both_sources(config_sources) == {%{a: 1}, %{b: 2}}
    end
  end
end
