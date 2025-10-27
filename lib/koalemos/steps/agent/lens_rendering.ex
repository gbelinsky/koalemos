defmodule Koalemos.Steps.Agent.LensRendering do
  @moduledoc """
  LensRendering step queries active lenses for their current context blocks.

  Takes lens configs and calls provide_context/1 on each lens module to get
  the context blocks that should be included in the LLM system prompt.

  ## Input Context
  - lenses: List of lens configs in format:
    - "ModuleName" (string for no config)
    - ["ModuleName", config] (list with config)

  ## Output Context
  - lens_contexts: List of context blocks for LLM system prompt
  """

  def execute(_config, state) do
    lenses_config = state.context[:active_lenses] || state.context[:lenses] || []

    try do
      # Collect all context blocks from all lens modules
      all_context_blocks = collect_context_from_lens_configs(lenses_config, state)

      {:ok, [add_or_update: %{lens_contexts: all_context_blocks}]}
    rescue
      error ->
        {:error, "Lens context rendering failed: #{Exception.message(error)}"}
    end
  end

  # Collect all context blocks directly from lens configs
  defp collect_context_from_lens_configs(lenses_config, state) do
    Enum.flat_map(lenses_config, fn
      # String format: "ModuleName"
      module_name when is_binary(module_name) ->
        get_context_from_module_name(module_name, state)

      # List format: ["ModuleName", config]
      [module_name, _config] when is_binary(module_name) ->
        get_context_from_module_name(module_name, state)
    end)
  end

  # Get context blocks from a module name with proper error checking
  defp get_context_from_module_name(module_name, state) do
    try do
      module = Module.safe_concat([module_name])

      # Check if module exists and is loaded
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          if function_exported?(module, :provide_context, 1) do
            module.provide_context(state)
          else
            # Module exists but doesn't implement provide_context
            []
          end

        {:error, _reason} ->
          raise ArgumentError, "Lens module #{module_name} not found or could not be loaded"
      end
    rescue
      error in ArgumentError ->
        reraise error, __STACKTRACE__
    end
  end
end
