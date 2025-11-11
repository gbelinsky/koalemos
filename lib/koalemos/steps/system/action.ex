defmodule Koalemos.Steps.System.Action do
  @moduledoc """
  System.Action step executes routine actions via handle_action/2.

  This step delegates to the current routine module's `handle_action/2` function,
  allowing routines to define custom actions that can modify context.

  ## Usage

  ```elixir
  perform_action: %{
    type: Koalemos.Steps.System.Action,
    config: %{action: :initialize_defaults},
    transitions: [{:next_step, :always}]
  }
  ```

  The routine module must implement:

  ```elixir
  def handle_action(:initialize_defaults, state) do
    {:ok, [add: %{defaults_loaded: true, value: 42}]}
  end
  ```

  ## Error Handling

  If the action is not defined or fails, returns an error tuple.
  """

  alias Koalemos.ConfigMerge

  def execute(config_sources, state) do
    # Extract action from config sources (runtime overrides static)
    action = ConfigMerge.get_key(config_sources, :action)
    routine_module = state.current_routine_module

    if action == nil do
      {:error, "No action specified in config"}
    else
      try do
        apply(routine_module, :handle_action, [action, state])
      rescue
        UndefinedFunctionError ->
          {:error, "Action #{action} not defined in #{routine_module}"}

        FunctionClauseError ->
          {:error, "Action #{action} has invalid arguments in #{routine_module}"}

        error ->
          {:error, "Action #{action} failed: #{Exception.message(error)}"}
      end
    end
  end
end
