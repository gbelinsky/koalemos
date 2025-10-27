defmodule Koalemos.Steps.Agent.ToolSchema do
  @moduledoc """
  ToolSchema step collects tools from active lenses and builds schemas for LLM.

  Queries each lens module for its available tools, then builds:
  - tool_descriptions: Array of tool schemas for LLM API
  - tool_map: Map of tool_name → {module, tool_atom} for execution lookup

  ## Context Input
  - active_lenses (or lenses): List of lens configurations

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
  def execute(_config, state) do
    lenses_config = state.context[:active_lenses] || state.context[:lenses] || []

    try do
      # Collect all tools from all lens modules
      all_tools = collect_tools_from_lens_configs(lenses_config)

      # Build tool descriptions with context
      tool_descriptions = build_tool_descriptions(all_tools, state.context)

      # Build tool name → {module, tool_atom} mapping
      tool_map = build_tool_map(all_tools)

      {:ok, [
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
        get_tools_from_module_name(module_name)

      # List format: ["ModuleName", config]
      [module_name, _config] when is_binary(module_name) ->
        get_tools_from_module_name(module_name)
    end)
  end

  # Get tools from a module name with proper error checking
  defp get_tools_from_module_name(module_name) do
    try do
      module = Module.safe_concat([module_name])

      # Check if module exists and is loaded
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          if function_exported?(module, :tools, 0) do
            module.tools()
          else
            # Module exists but doesn't implement lens interface
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

  # Build tool description schemas for LLM API
  defp build_tool_descriptions(all_tools, context) do
    Enum.map(all_tools, fn {module, tool_atom} ->
      # Check for context-aware info/2, fall back to info/1
      if function_exported?(module, :info, 2) do
        module.info(tool_atom, context)
      else
        module.info(tool_atom)
      end
    end)
  end

  # Build map from tool name to {module, tool_atom} for execution lookup
  defp build_tool_map(all_tools) do
    Enum.reduce(all_tools, %{}, fn {module, tool_atom}, acc ->
      # Use info/2 with empty context if available, otherwise info/1
      tool_info = if function_exported?(module, :info, 2) do
        module.info(tool_atom, %{})
      else
        module.info(tool_atom)
      end

      tool_name = tool_info.name
      Map.put(acc, tool_name, {module, tool_atom})
    end)
  end
end
