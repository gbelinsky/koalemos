defmodule Koalemos.Steps.System.ConfigTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.System.Config

  describe "execute/2" do
    test "adds all config values to context" do
      config = %{
        provider: :anthropic,
        llm_model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        temperature: 0.1
      }

      state = %{context: %{}}

      assert {:ok, diff} = Config.execute(config, state)
      assert diff == [add_or_update: config]
    end

    test "works with empty config" do
      config = %{}
      state = %{context: %{}}

      assert {:ok, diff} = Config.execute(config, state)
      assert diff == [add_or_update: %{}]
    end

    test "works with nested config values" do
      config = %{
        lenses: [{Koalemos.Lenses.Notes, []}],
        settings: %{
          timeout: 5000,
          retry: true
        }
      }

      state = %{context: %{}}

      assert {:ok, diff} = Config.execute(config, state)
      assert diff == [add_or_update: config]
    end

    test "uses add_or_update for safe merging" do
      config = %{key1: "value1", key2: "value2"}
      state = %{context: %{existing: "data"}}

      assert {:ok, [add_or_update: ^config]} = Config.execute(config, state)
    end
  end
end
