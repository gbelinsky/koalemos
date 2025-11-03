defmodule Koalemos.Steps.Agent.LensRendering do
  @moduledoc """
  LensRendering step queries active lenses for their current context blocks.

  Takes lens configs and calls provide_context/1 on each lens module to get
  the context blocks. Lenses can return both text and image blocks.

  ## Hybrid Lens Configuration

  This step implements the hybrid config pattern:
  - Base lenses from `context[:lenses]` (set at routine initialization)
  - Config lenses from `config_sources` (per-step overrides/additions)
  - Merged locally for this step only (doesn't modify context)

  ## Input Context
  - lenses: List of lens configs in format:
    - "ModuleName" (string for no config)
    - ["ModuleName", config] (list with config)

  ## Input Config
  - lenses: Optional list of lenses to add or override for this step

  ## Output Context
  - lens_text_contexts: List of text blocks for LLM system prompt
  - lens_image_contexts: List of image blocks to prepend as user messages

  ## Lens Context Format

  Lenses return a list of blocks:
  - Text: `%{type: "text", text: "..."}`
  - Image: `%{type: "image", source: %{type: "base64", media_type: "image/png", data: "..."}}`

  Text blocks are combined into the system message, while image blocks are
  prepended to the messages array as user messages (not saved to history).
  """

  alias Koalemos.ConfigMerge

  def execute(config_sources, state) do
    # Hybrid pattern: base lenses from context + config lenses
    base_lenses = state.context[:lenses] || []
    config_lenses = ConfigMerge.get_key(config_sources, :lenses, [])

    # Merge lenses (config overrides base for same module)
    active_lenses = ConfigMerge.merge_lenses(base_lenses, config_lenses)

    try do
      # Collect all context blocks from all lens modules
      all_context_blocks = collect_context_from_lens_configs(active_lenses, state)

      # Separate text and image blocks
      {text_blocks, image_blocks} = separate_context_blocks(all_context_blocks)

      {:ok, [add_or_update: %{
        lens_text_contexts: text_blocks,
        lens_image_contexts: image_blocks
      }]}
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

  # Separate context blocks into text and image blocks
  defp separate_context_blocks(blocks) do
    Enum.split_with(blocks, fn block ->
      cond do
        # Plain string - treat as text
        is_binary(block) ->
          true

        # Map with type field
        is_map(block) ->
          type = block["type"] || block[:type]
          type == "text"

        # Anything else - treat as text for safety
        true ->
          true
      end
    end)
  end
end
