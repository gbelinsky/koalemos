defmodule Koalemos.ConfigMerge do
  @moduledoc """
  Utility functions for merging configuration sources with various strategies.

  Steps receive config sources from the Engine in this format:

      %{
        static: %{...},    # From step definition
        runtime: %{...}    # From context[:config][step_name]
      }

  Use these functions to merge according to your step's needs.

  ## Common Patterns

  ### Runtime Priority (Most Common)

      config = ConfigMerge.runtime_priority(config_sources)

  ### Extract Single Key

      action = ConfigMerge.get_key(config_sources, :action, "default_action")

  ### Merge Lenses (Hybrid Pattern)

      base_lenses = state.context[:lenses] || []
      config_lenses = ConfigMerge.get_key(config_sources, :lenses, [])
      active_lenses = ConfigMerge.merge_lenses(base_lenses, config_lenses)
  """

  @doc """
  Runtime overrides static (most common pattern).

  Static config from step definition is used as defaults,
  runtime config from context[:config] overrides it.

  ## Examples

      iex> ConfigMerge.runtime_priority(%{static: %{a: 1, b: 2}, runtime: %{b: 3, c: 4}})
      %{a: 1, b: 3, c: 4}

      iex> ConfigMerge.runtime_priority(%{static: %{timeout: 30}, runtime: %{}})
      %{timeout: 30}
  """
  def runtime_priority(%{static: static, runtime: runtime}) do
    Map.merge(static, runtime)
  end

  @doc """
  Static takes precedence (step definition is source of truth).

  Useful for steps with critical config that shouldn't be overridden at runtime.

  ## Examples

      iex> ConfigMerge.static_priority(%{static: %{a: 1, b: 2}, runtime: %{b: 3}})
      %{a: 1, b: 2}
  """
  def static_priority(%{static: static, runtime: runtime}) do
    Map.merge(runtime, static)
  end

  @doc """
  Extract a single key with fallback chain: runtime → static → default.

  ## Examples

      iex> ConfigMerge.get_key(%{static: %{timeout: 30}, runtime: %{}}, :timeout, 10)
      30

      iex> ConfigMerge.get_key(%{static: %{}, runtime: %{timeout: 60}}, :timeout, 10)
      60

      iex> ConfigMerge.get_key(%{static: %{}, runtime: %{}}, :timeout, 10)
      10
  """
  def get_key(%{static: static, runtime: runtime}, key, default \\ nil) do
    runtime[key] || static[key] || default
  end

  @doc """
  Merge lens lists with override strategy.

  Later sources override earlier sources for the same lens module.
  This implements the hybrid pattern: base lenses + config overrides.

  Lenses can be in two formats:
  - `[module_string, config_map]` - Lens with configuration
  - `module_string` - Lens without configuration

  ## Examples

      iex> base = [["PersonaLens", %{personas: [:professional]}]]
      iex> override = [["PersonaLens", %{personas: [:casual]}]]
      iex> ConfigMerge.merge_lenses(base, override)
      [["PersonaLens", %{personas: [:casual]}]]

      iex> base = [["PersonaLens", %{}], ["Scratchpad", %{}]]
      iex> override = [["FileSystem", %{root: "/tmp"}]]
      iex> ConfigMerge.merge_lenses(base, override)
      [["PersonaLens", %{}], ["Scratchpad", %{}], ["FileSystem", %{root: "/tmp"}]]
  """
  def merge_lenses(base_lenses, config_lenses) do
    # Convert both lists to maps for merging
    base_map = lens_list_to_map(base_lenses)
    config_map = lens_list_to_map(config_lenses)

    # Config overrides base
    merged_map = Map.merge(base_map, config_map)

    # Convert back to list format
    map_to_lens_list(merged_map)
  end

  @doc """
  Runtime only - ignore static config entirely.

  Useful for steps that only care about dynamic runtime config.

  ## Examples

      iex> ConfigMerge.runtime_only(%{static: %{a: 1}, runtime: %{b: 2}})
      %{b: 2}
  """
  def runtime_only(%{runtime: runtime}), do: runtime

  @doc """
  Static only - ignore runtime config entirely.

  Useful for steps with fixed config that never changes.

  ## Examples

      iex> ConfigMerge.static_only(%{static: %{a: 1}, runtime: %{b: 2}})
      %{a: 1}
  """
  def static_only(%{static: static}), do: static

  @doc """
  No merge - return both sources as a tuple for custom handling.

  When you need full control over merge logic.

  ## Examples

      iex> ConfigMerge.both_sources(%{static: %{a: 1}, runtime: %{b: 2}})
      {%{a: 1}, %{b: 2}}
  """
  def both_sources(%{static: static, runtime: runtime}), do: {static, runtime}

  # Private helpers

  defp lens_list_to_map(lenses) do
    Map.new(lenses, fn
      [module, config] when is_binary(module) -> {module, config}
      module when is_binary(module) -> {module, %{}}
    end)
  end

  defp map_to_lens_list(lens_map) do
    Enum.map(lens_map, fn {module, config} -> [module, config] end)
  end
end
