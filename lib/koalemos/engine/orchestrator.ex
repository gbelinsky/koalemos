defmodule Koalemos.Engine.Orchestrator do
  @moduledoc """
  Handles step execution lifecycle and routine transitions.

  The Orchestrator is the execution heart of the engine, responsible for:
  - Executing steps (setup, async execution, completion handling)
  - Applying context diffs from step results
  - Evaluating transition conditions
  - Managing sub-routine execution (nested routines)
  - Recording lifecycle events

  ## Architecture Note

  This module is large (~380 lines) but cohesive - it handles the complete
  step execution lifecycle. The original Flo code suggested splitting into
  separate StepExecutor and TransitionManager modules, but we're porting as-is
  for now. See BACKLOG.md "Deferred Improvements" for discussion.

  ## Step Execution Flow

      1. execute_current_step/1
         ↓
      2. Step setup (optional :setup/2 callback)
         ↓
      3. Async step execution (:execute/2 in Task)
         ↓
      4. Step completion message → handle_step_success/2 or handle_step_error/2
         ↓
      5. Apply context diff
         ↓
      6. Check transitions (evaluate conditions)
         ↓
      7. Handle transition (next step, :end, :error, sub-routine)

  ## Sub-Routine Execution

  When a step is itself a routine (has :routine_definition/0), Orchestrator:
  1. Pushes current state onto execution_stack
  2. Loads sub-routine definition
  3. Sets current_routine_module and current_step to sub-routine's start
  4. On sub-routine completion (:end), pops stack and continues parent

  ## Event Recording

  Orchestrator records events at every lifecycle point:
  - step_started, step_setup, context_changed
  - step_completed, error_occurred
  - transition_taken, routine_completed

  These events are broadcast via Observer for UI updates and debugging.
  """

  alias Koalemos.Engine.{ContextManager, EventRecorder, StepUtils}
  require Logger
  require Koalemos.Engine.StepUtils
  require Koalemos.Log
  alias Koalemos.Log

  @type state :: map()
  @type step_result :: {:ok, ContextManager.diff()} | {:error, String.t()}
  @type transition_result :: {:transition, atom()} | {:branch, [atom()]}
  @type genserver_result :: {:noreply, state()} | {:reply, term(), state()}

  @doc """
  Executes the current step in the routine.

  Handles step setup, spawns async execution, and records events.
  If the step is a sub-routine (has :routine_definition/0), enters the sub-routine.
  Otherwise, spawns async execution and waits for completion message.

  ## Parameters

  - `state` - The engine state

  ## Returns

  Updated state after step execution begins

  ## Examples

      state = %{
        routine_id: "routine-123",
        module: MyRoutine,
        current_routine_module: MyRoutine,
        current_step: :init,
        context: %{},
        auto_execute: true,
        # ... other fields
      }

      new_state = Orchestrator.execute_current_step(state)
      # Step is now executing asynchronously
  """
  @spec execute_current_step(state()) :: state()
  def execute_current_step(state) do
    step_config = get_current_step_config(state)

    Log.debug(:engine, fn ->
      "[Engine] Executing step #{state.current_step} in #{state.current_routine_module}"
    end)

    if step_config == nil do
      EventRecorder.record_event(state, "error_occurred", %{
        metadata: %{type: "invalid_step", step: state.current_step}
      })

      send(self(), {:event, :step_complete, {:error, "Invalid step: #{state.current_step}"}})
      state
    else
      step_module = step_config.type

      # Collect config sources instead of merging
      config_sources = %{
        static: step_config[:config] || %{},
        runtime: get_in(state, [:context, :config, state.current_step]) || %{}
      }

      EventRecorder.record_event(state, "step_started", %{
        metadata: %{
          step_module: step_module,
          config_sources: config_sources
        },
        execution_stack: state.execution_stack
      })

      # Ensure module is loaded before checking if it's a sub-routine
      Code.ensure_loaded(step_module)

      # Setup step execution - capture both state and diff
      {state_after_setup, setup_diff} =
        if function_exported?(step_module, :setup, 2) do
          StepUtils.call_step_function_with_diff(step_module, :setup, [config_sources], state)
        else
          {state, []}
        end

      # Record setup and fire context_changed if setup was called and returned a diff
      if function_exported?(step_module, :setup, 2) do
        EventRecorder.record_event(state_after_setup, "step_setup", %{
          metadata: %{step_module: step_module, config_sources: config_sources}
        })

        # Fire context_changed event if setup modified context
        if setup_diff != [] do
          EventRecorder.record_event(state_after_setup, "context_changed", %{
            context_diff: setup_diff
          })
        end
      end

      # Execute step or sub-routine
      routine_pid = self()

      if function_exported?(step_module, :routine_definition, 0) do
        new_state = enter_sub_routine(step_module, state_after_setup)

        if state.auto_execute do
          send(self(), :continue_routine)
        end

        new_state
      else
        # Re-collect config sources (setup may have modified runtime config)
        config_sources_for_execute = %{
          static: config_sources.static,
          runtime:
            get_in(state_after_setup, [:context, :config, state_after_setup.current_step]) || %{}
        }

        # Execute step in supervised task (start_child for fire-and-forget with supervision)
        Task.Supervisor.start_child(Koalemos.StepTaskSupervisor, fn ->
          result =
            try do
              apply(step_module, :execute, [
                config_sources_for_execute,
                state_after_setup
              ])
            rescue
              error ->
                stacktrace = __STACKTRACE__
                Logger.error("[Orchestrator] Step execution failed: #{Exception.message(error)}\n#{Exception.format_stacktrace(stacktrace)}")
                {:error, "Step execution failed: #{Exception.message(error)}"}
            catch
              :exit, reason ->
                Logger.error("[Orchestrator] Step execution process exited: #{inspect(reason)}")
                {:error, "Step execution process exited: #{inspect(reason)}"}
            end

          send(routine_pid, {:event, :step_complete, result})
        end)

        state_after_setup
      end
    end
  end

  @doc """
  Handles successful step completion.

  Applies context diffs, records events, and triggers transition checking.
  This is called when a step's execute/2 returns {:ok, diff}.

  ## Parameters

  - `diff` - The context diff returned by the step
  - `state` - The current engine state

  ## Returns

  GenServer tuple `{:noreply, new_state}` after handling the transition

  ## Examples

      # Called by Engine GenServer
      def handle_info({:event, :step_complete, {:ok, diff}}, state) do
        Orchestrator.handle_step_success(diff, state)
      end
  """
  @spec handle_step_success(ContextManager.diff(), state()) :: genserver_result()
  def handle_step_success(diff, state) do
    EventRecorder.record_event(state, "step_completed", %{
      metadata: %{status: :success, diff: diff}
    })

    # Apply context diff
    case ContextManager.apply_diff(state.context, diff) do
      {:ok, new_context} ->
        new_state = %{state | context: new_context}

        EventRecorder.record_event(new_state, "context_changed", %{
          context_diff: diff
        })

        # Check for LLM routine transition first
        case get_in(new_context, [:lens_state, :workflow_transition]) do
          {target_step, _reason} ->
            case get_in(new_context, [:lens_state, :workflow_transition_module]) do
              target_module when target_module != nil ->
                # Already computed target - check if we're there
                if state.current_routine_module == target_module do
                  # We're at target - apply transition and clean up
                  cleaned_state = clear_workflow_transition(new_state)
                  handle_transitions({:transition, target_step}, cleaned_state)
                else
                  # Not at target yet - keep bubbling up
                  handle_transitions({:transition, :end}, new_state)
                end

              nil ->
                # First time - compute target and go to :end (never same level)
                target_module = find_routine_with_transition(target_step, state)

                updated_state =
                  put_in(
                    new_state.context[:lens_state][:workflow_transition_module],
                    target_module
                  )

                handle_transitions({:transition, :end}, updated_state)
            end

          nil ->
            # Normal transition logic
            result = new_state |> check_transitions() |> handle_transitions(new_state)
            result
        end

      {:error, reason} ->
        EventRecorder.record_event(state, "error_occurred", %{
          metadata: %{type: "context_diff_failed", reason: reason}
        })

        # Handle context diff error
        error_state = %{state | context: Map.put(state.context, :error, reason)}
        {:noreply, error_state}
    end
  end

  @doc """
  Handles step execution failure.

  Records error event and triggers error transition.
  This is called when a step's execute/2 returns {:error, reason}.

  ## Parameters

  - `reason` - The error reason (string or term)
  - `state` - The current engine state

  ## Returns

  GenServer tuple `{:noreply, new_state}` after handling the error transition

  ## Examples

      # Called by Engine GenServer
      def handle_info({:event, :step_complete, {:error, reason}}, state) do
        Orchestrator.handle_step_error(reason, state)
      end
  """
  @spec handle_step_error(term(), state()) :: genserver_result()
  def handle_step_error(reason, state) do
    EventRecorder.record_event(state, "error_occurred", %{
      metadata: %{type: "step_execution_failed", reason: reason}
    })

    # Handle step failure
    error_state = %{state | context: Map.put(state.context, :error, reason)}

    result = handle_transitions({:transition, :error}, error_state)
    result
  end

  @doc """
  Gets the current step configuration from the appropriate routine definition.

  Looks up the step definition in `state.routine_definitions[current_routine_module][current_step]`.

  ## Parameters

  - `state` - The engine state

  ## Returns

  Step configuration map or `nil` if step not found

  ## Examples

      step_config = Orchestrator.get_current_step_config(state)
      # => %{type: MyStep, config: %{...}, transitions: [...]}
  """
  @spec get_current_step_config(state()) :: map() | nil
  def get_current_step_config(state) do
    current_routine_def = state.routine_definitions[state.current_routine_module]
    current_routine_def[state.current_step]
  end

  # Private helper functions

  # Enters a sub-routine by pushing current state onto execution stack
  defp enter_sub_routine(step_module, state) do
    new_stack = [
      %{module: state.current_routine_module, step: state.current_step} | state.execution_stack
    ]

    updated_definitions = ensure_routine_loaded(state.routine_definitions, step_module)

    %{
      state
      | execution_stack: new_stack,
        routine_definitions: updated_definitions,
        current_routine_module: step_module,
        current_step: StepUtils.safe_call(step_module, :start, []) || :start
    }
  end

  # Exits a sub-routine by popping execution stack
  defp exit_sub_routine(state) do
    # Send step completion message
    send(self(), {:event, :step_complete, {:ok, []}})

    # Pop stack and restore parent state
    [%{module: parent_module, step: parent_step} | remaining_stack] = state.execution_stack

    new_state = %{
      state
      | current_routine_module: parent_module,
        current_step: parent_step,
        execution_stack: remaining_stack
    }

    {:noreply, new_state}
  end

  # Checks transitions for the current step
  defp check_transitions(state) do
    step_config = get_current_step_config(state)

    if step_config == nil do
      {:transition, :end}
    else
      transitions = Map.get(step_config, :transitions, [])

      case transitions do
        [] ->
          {:transition, :end}

        transition_list ->
          valid_transitions = find_valid_transitions(transition_list, state)

          case valid_transitions do
            [] ->
              # No valid transitions - go to :end
              # Note: Could be wait-for-event scenario in some cases
              {:transition, :end}

            [single] ->
              {:transition, single}

            [first | _rest] ->
              # Multiple valid transitions - take first one
              # TODO: Implement branching when needed
              {:transition, first}
          end
      end
    end
  end

  # Finds all valid transitions by evaluating their conditions
  defp find_valid_transitions(transitions, state) do
    transitions
    |> Enum.filter(fn {_target, condition} ->
      try do
        apply(state.current_routine_module, :check_condition, [condition, state.context])
      rescue
        # Intentional: String conditions (for semantic transitions) fail here
        # and return false, falling through to :always. This allows mixing
        # code conditions and LLM-display-only string conditions.
        _error -> false
      end
    end)
    |> Enum.map(fn {target, _condition} ->
      target
    end)
  end

  # Handles the transition result
  defp handle_transitions(transition_result, state) do
    case transition_result do
      {:transition, :end} ->
        if Enum.empty?(state.execution_stack) do
          # Root routine completion
          final_state = %{state | routine_status: :completed, current_step: :end}

          EventRecorder.record_event(final_state, "routine_completed", %{
            metadata: %{
              final_context: final_state.context,
              routine_definitions: final_state.routine_definitions
            }
          })

          {:noreply, final_state}
        else
          # Sub-routine completion - simulate step completion
          exit_sub_routine(state)
        end

      {:transition, :error} ->
        error_state = %{state | routine_status: :error, current_step: :error}

        EventRecorder.record_event(error_state, "routine_completed", %{
          metadata: %{final_context: error_state.context}
        })

        {:noreply, error_state}

      {:transition, next_step} ->
        EventRecorder.record_event(state, "transition_taken", %{
          metadata: %{from: state.current_step, to: next_step}
        })

        Log.debug(:engine, fn ->
          "[Engine] Transition: #{state.current_step} -> #{next_step}"
        end)

        updated_state = %{state | current_step: next_step}

        if state.auto_execute do
          send(self(), :continue_routine)
        end

        {:noreply, updated_state}
    end
  end

  # Helper for loading routine definitions
  defp ensure_routine_loaded(routine_definitions, routine_module) do
    if Map.has_key?(routine_definitions, routine_module) do
      routine_definitions
    else
      definition = routine_module.routine_definition()
      Map.put(routine_definitions, routine_module, definition)
    end
  end

  # LLM workflow transition helpers
  # Note: These handle special cross-routine transitions initiated by LLMs
  # See wireframe design workflow for usage examples

  defp clear_workflow_transition(state) do
    lens_state = get_in(state.context, [:lens_state]) || %{}

    cleaned_lens_state =
      lens_state
      |> Map.delete(:workflow_transition)
      |> Map.delete(:workflow_transition_module)

    put_in(state.context[:lens_state], cleaned_lens_state)
  end

  defp find_routine_with_transition(target_step, state) do
    # Walk execution stack - LLM transitions are always for ancestors
    Enum.find_value(state.execution_stack, fn %{module: module, step: step} ->
      routine_has_transition?(module, step, target_step) && module
    end)
  end

  defp routine_has_transition?(routine_module, step, target_step) do
    definition = routine_module.routine_definition()
    step_config = Map.get(definition, step, %{})
    transitions = Map.get(step_config, :transitions, [])

    Enum.any?(transitions, fn {transition_target, _condition} ->
      transition_target == target_step
    end)
  end
end
