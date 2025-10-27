defmodule Koalemos.Steps.System.ActionTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.System.Action

  # Test helper routine
  defmodule TestRoutine do
    def routine_definition do
      %{start: %{type: Action, transitions: []}}
    end

    def handle_action(:initialize, _state) do
      {:ok, [add: %{initialized: true}]}
    end

    def handle_action(:set_value, state) do
      value = state.context[:value] || 42
      {:ok, [add: %{result: value * 2}]}
    end

    def handle_action(:fail_with_error, _state) do
      raise "Intentional error"
    end
  end

  defmodule RoutineWithoutActions do
    def routine_definition do
      %{start: %{type: Action, transitions: []}}
    end

    # No handle_action/2 defined
  end

  defmodule RoutineWithInvalidClause do
    def routine_definition do
      %{start: %{type: Action, transitions: []}}
    end

    # Only accepts specific action
    def handle_action(:specific_action, _state) do
      {:ok, []}
    end
  end

  describe "execute/2" do
    test "calls routine handle_action and returns result" do
      config = %{action: :initialize}
      state = %{
        current_routine_module: TestRoutine,
        context: %{}
      }

      assert {:ok, diff} = Action.execute(config, state)
      assert diff == [add: %{initialized: true}]
    end

    test "passes state to handle_action" do
      config = %{action: :set_value}
      state = %{
        current_routine_module: TestRoutine,
        context: %{value: 10}
      }

      assert {:ok, diff} = Action.execute(config, state)
      assert diff == [add: %{result: 20}]
    end

    test "returns error when action not defined" do
      config = %{action: :nonexistent_action}
      state = %{
        current_routine_module: RoutineWithoutActions,
        context: %{}
      }

      assert {:error, error_msg} = Action.execute(config, state)
      assert error_msg =~ "Action nonexistent_action not defined"
      assert error_msg =~ "RoutineWithoutActions"
    end

    test "returns error when action has invalid arguments" do
      config = %{action: :wrong_action}
      state = %{
        current_routine_module: RoutineWithInvalidClause,
        context: %{}
      }

      assert {:error, error_msg} = Action.execute(config, state)
      assert error_msg =~ "Action wrong_action has invalid arguments"
      assert error_msg =~ "RoutineWithInvalidClause"
    end

    test "returns error when action raises exception" do
      config = %{action: :fail_with_error}
      state = %{
        current_routine_module: TestRoutine,
        context: %{}
      }

      assert {:error, error_msg} = Action.execute(config, state)
      assert error_msg =~ "Action fail_with_error failed"
      assert error_msg =~ "Intentional error"
    end

    test "includes routine module in error messages" do
      config = %{action: :missing}
      state = %{
        current_routine_module: TestRoutine,
        context: %{}
      }

      assert {:error, error_msg} = Action.execute(config, state)
      assert error_msg =~ "TestRoutine"
    end
  end
end
