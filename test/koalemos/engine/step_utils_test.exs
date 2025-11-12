defmodule Koalemos.Engine.StepUtilsTest do
  use ExUnit.Case, async: true
  alias Koalemos.Engine.StepUtils
  require Koalemos.Engine.StepUtils

  # Test step module that implements various behaviors
  defmodule TestStep do
    def function_that_returns_diff(_arg, _state) do
      {:ok, [{:add, %{added_by_test: true}}]}
    end

    def function_with_multiple_args(arg1, arg2, _state) do
      {:ok, [{:add, %{arg1: arg1, arg2: arg2}}]}
    end

    def function_that_returns_error(_state) do
      {:error, "something went wrong"}
    end

    def function_that_updates_existing(_state) do
      {:ok, [{:update, %{existing_key: "updated"}}]}
    end

    def function_that_appends(_state) do
      {:ok, [{:append_to, %{messages: "new message"}}]}
    end

    def function_that_raises(_state) do
      raise "intentional error"
    end

    def zero_arity_function do
      :zero_arity_result
    end
  end

  describe "call_step_function_if_exists/4" do
    test "calls function and applies diff when function exists" do
      state = %{context: %{}, other_field: :preserved}

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :function_that_returns_diff,
          ["arg"],
          state
        )

      assert result.context.added_by_test == true
      assert result.other_field == :preserved
    end

    test "passes arguments correctly" do
      state = %{context: %{}}

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :function_with_multiple_args,
          ["first", "second"],
          state
        )

      assert result.context.arg1 == "first"
      assert result.context.arg2 == "second"
    end

    test "returns state unchanged when function doesn't exist" do
      state = %{context: %{existing: "data"}, other: :field}

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :nonexistent_function,
          [],
          state
        )

      assert result == state
    end

    test "adds error to context when function returns error" do
      state = %{context: %{}}

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :function_that_returns_error,
          [],
          state
        )

      assert result.context.error == "something went wrong"
    end

    test "applies update diff correctly" do
      state = %{context: %{existing_key: "original"}}

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :function_that_updates_existing,
          [],
          state
        )

      assert result.context.existing_key == "updated"
    end

    test "applies append_to diff correctly" do
      state = %{context: %{messages: ["old message"]}}

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :function_that_appends,
          [],
          state
        )

      assert result.context.messages == ["old message", "new message"]
    end

    test "works with empty args list" do
      state = %{context: %{}}

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :function_that_returns_error,
          [],
          state
        )

      assert result.context.error == "something went wrong"
    end

    test "preserves all state fields besides context" do
      state = %{
        context: %{},
        workflow_id: "test-123",
        current_step: :some_step,
        nested: %{data: :here}
      }

      result =
        StepUtils.call_step_function_if_exists(
          TestStep,
          :function_that_returns_diff,
          ["arg"],
          state
        )

      assert result.workflow_id == "test-123"
      assert result.current_step == :some_step
      assert result.nested == %{data: :here}
      assert result.context.added_by_test == true
    end

    test "handles module that doesn't exist" do
      state = %{context: %{original: "data"}}

      result =
        StepUtils.call_step_function_if_exists(
          NonExistentModule,
          :some_function,
          [],
          state
        )

      assert result == state
    end
  end

  describe "call_step_function_with_diff/4" do
    test "returns both state and diff when function exists" do
      state = %{context: %{}}

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          TestStep,
          :function_that_returns_diff,
          ["arg"],
          state
        )

      assert new_state.context.added_by_test == true
      assert diff == [{:add, %{added_by_test: true}}]
    end

    test "returns empty diff when function doesn't exist" do
      state = %{context: %{original: "data"}}

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          TestStep,
          :nonexistent_function,
          [],
          state
        )

      assert new_state == state
      assert diff == []
    end

    test "returns empty diff when function returns error" do
      state = %{context: %{}}

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          TestStep,
          :function_that_returns_error,
          [],
          state
        )

      assert new_state.context.error == "something went wrong"
      assert diff == []
    end

    test "returns correct diff for update operation" do
      state = %{context: %{existing_key: "original"}}

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          TestStep,
          :function_that_updates_existing,
          [],
          state
        )

      assert new_state.context.existing_key == "updated"
      assert diff == [{:update, %{existing_key: "updated"}}]
    end

    test "returns correct diff for append_to operation" do
      state = %{context: %{messages: []}}

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          TestStep,
          :function_that_appends,
          [],
          state
        )

      assert new_state.context.messages == ["new message"]
      assert diff == [{:append_to, %{messages: "new message"}}]
    end

    test "passes multiple arguments correctly" do
      state = %{context: %{}}

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          TestStep,
          :function_with_multiple_args,
          ["first", "second"],
          state
        )

      assert new_state.context.arg1 == "first"
      assert new_state.context.arg2 == "second"
      assert diff == [{:add, %{arg1: "first", arg2: "second"}}]
    end

    test "preserves state when function doesn't exist" do
      state = %{
        context: %{data: "original"},
        other_fields: :preserved
      }

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          TestStep,
          :missing,
          [],
          state
        )

      assert new_state == state
      assert diff == []
    end

    test "handles module that doesn't exist" do
      state = %{context: %{}}

      {new_state, diff} =
        StepUtils.call_step_function_with_diff(
          NonExistentModule,
          :function,
          [],
          state
        )

      assert new_state == state
      assert diff == []
    end
  end

  describe "safe_call/2 and safe_call/3 macro" do
    test "calls function that exists with no args" do
      result = StepUtils.safe_call(TestStep, :zero_arity_function)
      assert result == :zero_arity_result
    end

    test "calls function that exists with args" do
      result =
        StepUtils.safe_call(TestStep, :function_with_multiple_args, ["a", "b", %{context: %{}}])

      assert {:ok, _diff} = result
    end

    test "returns nil when function doesn't exist" do
      result = StepUtils.safe_call(TestStep, :nonexistent_function, [])
      assert result == nil
    end

    test "returns nil when module doesn't exist" do
      result = StepUtils.safe_call(NonExistentModule, :function, [])
      assert result == nil
    end

    test "returns nil when function raises" do
      result = StepUtils.safe_call(TestStep, :function_that_raises, [%{context: %{}}])
      assert result == nil
    end

    test "works with module variable" do
      module_var = TestStep
      result = StepUtils.safe_call(module_var, :zero_arity_function)
      assert result == :zero_arity_result
    end

    test "checks arity correctly" do
      # zero_arity_function expects 0 args
      result_correct = StepUtils.safe_call(TestStep, :zero_arity_function, [])
      assert result_correct == :zero_arity_result

      # Calling with wrong arity returns nil
      result_wrong = StepUtils.safe_call(TestStep, :zero_arity_function, [:extra_arg])
      assert result_wrong == nil
    end

    test "handles atoms that aren't loaded modules" do
      result = StepUtils.safe_call(:not_a_module, :function, [])
      assert result == nil
    end
  end

  describe "integration scenarios" do
    defmodule ComplexStep do
      def setup(config, _state) do
        {:ok, [{:add, %{setup_config: config, setup_called: true}}]}
      end

      def execute(config, state) do
        if Map.get(state.context, :setup_called) do
          {:ok, [{:add_or_update, %{result: "success", config: config}}]}
        else
          {:error, "setup not called"}
        end
      end

      def optional_callback(_state) do
        {:ok, [{:add, %{optional: true}}]}
      end
    end

    test "complete step lifecycle with setup and execute" do
      initial_state = %{context: %{}, step: :init}

      # Call setup
      state_after_setup =
        StepUtils.call_step_function_if_exists(
          ComplexStep,
          :setup,
          [%{key: "value"}],
          initial_state
        )

      assert state_after_setup.context.setup_called == true
      assert state_after_setup.context.setup_config == %{key: "value"}
      # Other fields preserved
      assert state_after_setup.step == :init

      # Call execute
      state_after_execute =
        StepUtils.call_step_function_if_exists(
          ComplexStep,
          :execute,
          [%{execution_config: true}],
          state_after_setup
        )

      assert state_after_execute.context.result == "success"
      assert state_after_execute.context.config == %{execution_config: true}
      # Preserved
      assert state_after_execute.context.setup_called == true
    end

    test "error handling in execution flow" do
      # Skip setup and go straight to execute
      state = %{context: %{}}

      result =
        StepUtils.call_step_function_if_exists(
          ComplexStep,
          :execute,
          [%{}],
          state
        )

      assert result.context.error == "setup not called"
    end

    test "checking for optional callbacks with safe_call" do
      # Check if optional callback exists
      has_callback = StepUtils.safe_call(ComplexStep, :optional_callback, [%{context: %{}}])
      assert has_callback != nil

      # Check for non-existent callback
      no_callback = StepUtils.safe_call(ComplexStep, :teardown, [%{context: %{}}])
      assert no_callback == nil
    end
  end
end
