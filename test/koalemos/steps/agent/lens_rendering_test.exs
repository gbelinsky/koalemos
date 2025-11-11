defmodule Koalemos.Steps.Agent.LensRenderingTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.Agent.LensRendering

  # Test helper lenses
  defmodule TestLens do
    def provide_context(_state) do
      ["Test lens context block 1", "Test lens context block 2"]
    end
  end

  defmodule AnotherLens do
    def provide_context(_state) do
      ["Another lens context"]
    end
  end

  defmodule LensWithoutProvideContext do
    # Doesn't implement provide_context/1
  end

  describe "execute/2" do
    test "collects context from single lens (string format)" do
      state = %{
        context: %{
          lenses: ["Koalemos.Steps.Agent.LensRenderingTest.TestLens"]
        }
      }

      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert diff == [add_or_update: %{
        lens_text_contexts: ["Test lens context block 1", "Test lens context block 2"],
        lens_image_contexts: []
      }]
    end

    test "collects context from multiple lenses (string format)" do
      state = %{
        context: %{
          lenses: [
            "Koalemos.Steps.Agent.LensRenderingTest.TestLens",
            "Koalemos.Steps.Agent.LensRenderingTest.AnotherLens"
          ]
        }
      }

      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert [add_or_update: %{lens_text_contexts: contexts, lens_image_contexts: images}] = diff
      assert length(contexts) == 3
      assert "Test lens context block 1" in contexts
      assert "Test lens context block 2" in contexts
      assert "Another lens context" in contexts
      assert images == []
    end

    test "collects context from lens with config (list format)" do
      state = %{
        context: %{
          lenses: [
            ["Koalemos.Steps.Agent.LensRenderingTest.TestLens", %{some: "config"}]
          ]
        }
      }

      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert [add_or_update: %{lens_text_contexts: contexts, lens_image_contexts: images}] = diff
      assert length(contexts) == 2
      assert images == []
    end

    test "handles lens without provide_context gracefully" do
      state = %{
        context: %{
          lenses: [
            "Koalemos.Steps.Agent.LensRenderingTest.TestLens",
            "Koalemos.Steps.Agent.LensRenderingTest.LensWithoutProvideContext"
          ]
        }
      }

      # Should succeed but only get contexts from TestLens
      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert [add_or_update: %{lens_text_contexts: contexts, lens_image_contexts: images}] = diff
      assert length(contexts) == 2  # Only from TestLens
      assert images == []
    end

    test "returns empty list when no lenses configured" do
      state = %{context: %{}}

      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert diff == [add_or_update: %{lens_text_contexts: [], lens_image_contexts: []}]
    end

    test "uses lenses key when active_lenses not present" do
      state = %{
        context: %{
          lenses: ["Koalemos.Steps.Agent.LensRenderingTest.AnotherLens"]
        }
      }

      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert [add_or_update: %{lens_text_contexts: contexts, lens_image_contexts: _}] = diff
      assert "Another lens context" in contexts
    end

    test "returns error when lens module not found" do
      state = %{
        context: %{
          lenses: ["NonExistent.Lens.Module"]
        }
      }

      assert {:error, error_msg} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert error_msg =~ "Lens context rendering failed"
      assert error_msg =~ "not an already existing atom"
    end

    test "passes state to provide_context" do
      defmodule StatefulLens do
        def provide_context(state) do
          value = get_in(state, [:context, :test_value]) || "default"
          ["Context with value: #{value}"]
        end
      end

      state = %{
        context: %{
          lenses: ["Koalemos.Steps.Agent.LensRenderingTest.StatefulLens"],
          test_value: "custom"
        }
      }

      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert [add_or_update: %{lens_text_contexts: contexts, lens_image_contexts: _}] = diff
      assert "Context with value: custom" in contexts
    end

    test "flattens contexts from all lenses into single list" do
      defmodule MultiBlockLens do
        def provide_context(_state) do
          ["Block 1", "Block 2", "Block 3"]
        end
      end

      state = %{
        context: %{
          lenses: [
            "Koalemos.Steps.Agent.LensRenderingTest.TestLens",
            "Koalemos.Steps.Agent.LensRenderingTest.MultiBlockLens"
          ]
        }
      }

      assert {:ok, diff} = LensRendering.execute(%{static: %{}, runtime: %{}}, state)
      assert [add_or_update: %{lens_text_contexts: contexts, lens_image_contexts: _}] = diff
      assert length(contexts) == 5  # 2 from TestLens + 3 from MultiBlockLens
    end
  end
end
