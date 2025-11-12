defmodule Koalemos.Steps.System.ConfigTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.System.Config

  describe "execute/2" do
    test "adds all config values to context with runtime priority" do
      config_sources = %{
        static: %{
          provider: :anthropic,
          llm_model: "claude-sonnet-4-20250514",
          max_tokens: 4096,
          temperature: 0.1
        },
        runtime: %{}
      }

      state = %{context: %{}}

      assert {:ok, diff} = Config.execute(config_sources, state)
      assert diff == [add_or_update: config_sources.static]
    end

    test "runtime config overrides static config" do
      config_sources = %{
        static: %{
          provider: :anthropic,
          llm_model: "claude-sonnet-4-20250514",
          max_tokens: 4096
        },
        runtime: %{
          llm_model: "claude-opus-4-20250514",
          max_tokens: 8000
        }
      }

      state = %{context: %{}}

      assert {:ok, diff} = Config.execute(config_sources, state)

      expected = %{
        provider: :anthropic,
        llm_model: "claude-opus-4-20250514",
        max_tokens: 8000
      }

      assert diff == [add_or_update: expected]
    end

    test "works with empty config sources" do
      config_sources = %{static: %{}, runtime: %{}}
      state = %{context: %{}}

      assert {:ok, diff} = Config.execute(config_sources, state)
      assert diff == [add_or_update: %{}]
    end

    test "works with nested config values" do
      config_sources = %{
        static: %{
          lenses: ["Koalemos.Lenses.Notes"],
          settings: %{
            timeout: 5000,
            retry: true
          }
        },
        runtime: %{}
      }

      state = %{context: %{}}

      assert {:ok, diff} = Config.execute(config_sources, state)
      assert diff == [add_or_update: config_sources.static]
    end
  end
end
