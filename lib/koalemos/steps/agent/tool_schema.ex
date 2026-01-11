defmodule Koalemos.Steps.Agent.ToolSchema do
  @moduledoc """
  ToolSchema step collects tools from active lenses and builds schemas for LLM.

  Queries each lens module for its available tools, then builds:
  - tool_descriptions: Array of tool schemas for LLM API
  - tool_map: Map of tool_name → {module, tool_atom} for execution lookup

  ## Lens Configuration

  This step reads lenses from context - it does NOT merge or override them.
  Lens configuration is the responsibility of the routine/sub-routine that manages scope.

  ## Context Input
  - lenses: List of lens configurations (set by routine or sub-routine setup)

  ## Context Output
  - tool_descriptions: List of tool schemas for LLM
  - tool_map: Map for tool name → {module, atom} lookup

  ## Example

  ```elixir
  setup_tools: %{
    type: Koalemos.Steps.Agent.ToolSchema,
    transitions: [{:next_step, :always}]
  }
  ```
  """

  require Logger

  @doc """
  Collects tools from lenses and builds tool schemas.
  """
  def execute(_config_sources, state) do
    # Use lenses from context - lens config is managed by routine/sub-routine
    active_lenses = state.context[:lenses] || []

    try do
      # Collect all tools from all lens modules
      all_tools = collect_tools_from_lens_configs(active_lenses)

      # Build tool descriptions with context
      tool_descriptions = build_tool_descriptions(all_tools, state.context)

      # Build tool name → {module, tool_atom} mapping
      tool_map = build_tool_map(all_tools)

      {:ok,
       [
         add_or_update: %{
           tool_descriptions: tool_descriptions,
           tool_map: tool_map
         }
       ]}
    rescue
      error ->
        {:error, "Tool schema extraction failed: #{Exception.message(error)}"}
    end
  end

  # Collect all {module, tool_atom} tuples from lens configs
  defp collect_tools_from_lens_configs(lenses_config) do
    Enum.flat_map(lenses_config, fn
      # String format: "ModuleName"
      module_name when is_binary(module_name) ->
        get_tools_from_module_name(module_name, %{})

      # List format: ["ModuleName", config]
      [module_name, config] when is_binary(module_name) ->
        get_tools_from_module_name(module_name, config)
    end)
  end

  # Get tools from a module name with proper error checking
  # Passes config to tools/1 if available (for conditional tool exposure like readonly mode)
  # Returns tuples of {module, tool_atom, config} to preserve config for info/2
  defp get_tools_from_module_name(module_name, config) do
    try do
      module = Module.safe_concat([module_name])

      # Check if module exists and is loaded
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          tools =
            cond do
              # Prefer tools/1 for config-aware lenses (e.g., readonly mode)
              function_exported?(module, :tools, 1) ->
                module.tools(config)

              # Fall back to tools/0 for backward compatibility
              function_exported?(module, :tools, 0) ->
                module.tools()

              true ->
                # Module exists but doesn't implement lens interface
                []
            end

          # Attach config to each tool tuple for use in info/2
          Enum.map(tools, fn {mod, atom} -> {mod, atom, config} end)

        {:error, _reason} ->
          raise ArgumentError, "Lens module #{module_name} not found or could not be loaded"
      end
    rescue
      error in ArgumentError ->
        reraise error, __STACKTRACE__
    end
  end

  # Build tool description schemas for LLM API
  # Passes lens config via :current_lens_config in context
  defp build_tool_descriptions(all_tools, context) do
    Enum.map(all_tools, fn {module, tool_atom, lens_config} ->
      # Merge lens config into context for info/2
      enhanced_context = Map.put(context, :current_lens_config, lens_config)

      # Check for context-aware info/2, fall back to info/1
      if function_exported?(module, :info, 2) do
        module.info(tool_atom, enhanced_context)
      else
        module.info(tool_atom)
      end
    end)
  end

  # Build map from tool name to {module, tool_atom} for execution lookup
  # Also uses lens config to get correct tool names (for configurable tool names)
  defp build_tool_map(all_tools) do
    Enum.reduce(all_tools, %{}, fn {module, tool_atom, lens_config}, acc ->
      # Pass lens config for lenses with configurable tool names
      enhanced_context = %{current_lens_config: lens_config}

      tool_info =
        if function_exported?(module, :info, 2) do
          module.info(tool_atom, enhanced_context)
        else
          module.info(tool_atom)
        end

      tool_name = tool_info.name
      Map.put(acc, tool_name, {module, tool_atom})
    end)
  end
end
