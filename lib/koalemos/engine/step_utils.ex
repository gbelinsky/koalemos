defmodule Koalemos.Engine.StepUtils do
  @moduledoc """
  Shared utilities for working with routine steps.

  Provides helper functions for calling step functions with automatic
  context diff application and error handling. Steps return diffs that
  describe changes to the routine context, and these utilities apply
  those diffs automatically.

  ## Step Function Protocol

  Steps should implement functions that return `{:ok, diff}` or `{:error, reason}`:

      def setup(config, state) do
        {:ok, [{:add, %{initialized: true}}]}
      end

      def execute(config, state) do
        {:ok, [{:add_or_update, %{result: "completed"}}]}
      end

      def handle_event(event_type, data, state) do
        {:ok, [{:append_to, %{events: {event_type, data}}}]}
      end

  """

  alias Koalemos.Engine.ContextManager

  @doc """
  Calls a step function if it exists, applying context diffs and handling errors.

  If the function exists and returns `{:ok, diff}`, applies the diff to the
  state's context. If the function doesn't exist, returns the state unchanged.
  If the function returns `{:error, reason}`, adds the error to the context.

  ## Parameters

  - `step_module` - The step module (e.g., `Steps.Core.Config`)
  - `step_function` - The function name (e.g., `:setup`, `:execute`)
  - `args` - List of arguments (state will be appended)
  - `state` - The current engine state

  ## Returns

  The updated state with the diff applied.

  ## Examples

      # Function exists and succeeds
      state = %{context: %{}, other: :data}
      new_state = StepUtils.call_step_function_if_exists(
        MyStep,
        :setup,
        [%{config: :value}],
        state
      )
      # new_state.context will have changes from the diff

      # Function doesn't exist
      state = %{context: %{}, other: :data}
      new_state = StepUtils.call_step_function_if_exists(
        MyStep,
        :missing_function,
        [],
        state
      )
      # new_state == state (unchanged)

      # Function returns error
      state = %{context: %{}, other: :data}
      new_state = StepUtils.call_step_function_if_exists(
        MyStep,
        :failing_function,
        [],
        state
      )
      # new_state.context.error will contain the error reason

  """
  @spec call_step_function_if_exists(module(), atom(), list(), map()) :: map()
  def call_step_function_if_exists(step_module, step_function, args, state) do
    with true <- function_exported?(step_module, step_function, length(args) + 1),
         {:ok, diff} <- apply(step_module, step_function, args ++ [state]),
         new_state <- ContextManager.apply_context_diff!(state, diff) do
      new_state
    else
      false -> state
      {:error, reason} -> %{state | context: Map.put(state.context, :error, reason)}
    end
  end

  @doc """
  Calls a step function if it exists, returning both the updated state and the diff.

  Similar to `call_step_function_if_exists/4`, but returns `{state, diff}` so
  the diff can be used for event recording or other purposes.

  ## Parameters

  - `step_module` - The step module
  - `step_function` - The function name
  - `args` - List of arguments (state will be appended)
  - `state` - The current engine state

  ## Returns

  A tuple of `{updated_state, diff}`. If the function doesn't exist or returns
  an error, the diff will be an empty list `[]`.

  ## Examples

      # Function exists and succeeds
      {new_state, diff} = StepUtils.call_step_function_with_diff(
        MyStep,
        :execute,
        [%{param: :value}],
        state
      )
      # diff will be [{:add, %{...}}, ...] (the actual diff)
      # new_state.context will have the diff applied

      # Function doesn't exist
      {new_state, diff} = StepUtils.call_step_function_with_diff(
        MyStep,
        :missing,
        [],
        state
      )
      # diff == []
      # new_state == state (unchanged)

  """
  @spec call_step_function_with_diff(module(), atom(), list(), map()) :: {map(), list()}
  def call_step_function_with_diff(step_module, step_function, args, state) do
    with true <- function_exported?(step_module, step_function, length(args) + 1),
         {:ok, diff} <- apply(step_module, step_function, args ++ [state]),
         new_state <- ContextManager.apply_context_diff!(state, diff) do
      {new_state, diff}
    else
      false -> {state, []}
      {:error, reason} -> {%{state | context: Map.put(state.context, :error, reason)}, []}
    end
  end

  @doc """
  Safely calls a module function, returning `nil` if it doesn't exist or errors.

  This is a macro that generates code to check if a module and function exist
  before calling them, with full error handling. Useful for optional callbacks
  or module introspection.

  ## Parameters

  - `module` - The module to call (can be a variable or literal)
  - `function` - The function atom
  - `args` - The arguments (defaults to `[]`)

  ## Returns

  - The function result if it exists and succeeds
  - `nil` if the function doesn't exist or raises/throws

  ## Examples

      # Call a function that exists
      result = StepUtils.safe_call(MyModule, :start, [])
      # result will be whatever MyModule.start() returns

      # Call a function that doesn't exist
      result = StepUtils.safe_call(MyModule, :missing_function, [])
      # result == nil

      # Call with a module variable
      module_var = determine_module()
      result = StepUtils.safe_call(module_var, :callback, [arg1, arg2])

  """
  defmacro safe_call(module, function, args \\ []) do
    quote do
      module_var = unquote(module)

      try do
        if Code.ensure_loaded?(module_var) and
             function_exported?(module_var, unquote(function), length(unquote(args))) do
          apply(module_var, unquote(function), unquote(args))
        else
          nil
        end
      rescue
        _ -> nil
      catch
        _ -> nil
      end
    end
  end
end
