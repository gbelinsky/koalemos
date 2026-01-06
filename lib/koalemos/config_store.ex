defmodule Koalemos.ConfigStore do
  @moduledoc """
  Non-sensitive configuration storage.

  Stores last-used settings in .koalemos/.config.json (separate from credentials).
  Never stores API keys or tokens here.

  Configuration hierarchy (priority order):
  1. Environment variables (LLM_PROVIDER, ANTHROPIC_MODEL, etc.)
  2. File storage (.koalemos/.config.json or ~/.koalemos/.config.json)
  3. Browser localStorage (handled by LiveView/JavaScript hooks)
  4. Hardcoded defaults

  ## File Format

  ```json
  {
    "provider": "anthropic",
    "anthropic_model": "claude-sonnet-4-5",
    "openai_model": "gpt-4o",
    "ollama_model": "qwen2.5:7b",
    "ollama_base_url": "http://localhost:11434",
    "last_updated": "2025-01-15T10:30:00Z"
  }
  ```
  """

  require Logger

  @config_file ".koalemos/.config.json"
  @user_config_file "~/.koalemos/.config.json"

  @doc """
  Load configuration for wireframe editor.

  Merges config from multiple sources with env vars taking precedence:
  1. Environment variables
  2. Project config (.koalemos/.config.json)
  3. User config (~/.koalemos/.config.json)
  4. Defaults
  """
  def load_wireframe_config do
    # Start with defaults
    defaults = %{
      "provider" => "ollama",
      "anthropic_model" => "claude-sonnet-4-5",
      "openai_model" => "gpt-4o",
      "ollama_model" => "qwen2.5:7b",
      "ollama_base_url" => "http://localhost:11434"
    }

    # Load from user config (lowest priority file)
    user_config = load_from_file(expand_path(@user_config_file))

    # Load from project config (higher priority file)
    project_config = load_from_file(@config_file)

    # Load from environment variables (highest priority)
    env_config = load_from_env()

    # Merge in order: defaults < user < project < env
    defaults
    |> Map.merge(user_config)
    |> Map.merge(project_config)
    |> Map.merge(env_config)
  end

  @doc """
  Save wireframe configuration to file.

  Only saves if environment variables aren't controlling the config.
  Saves to project directory (.koalemos/.config.json) by default.
  """
  def save_wireframe_config(config) when is_map(config) do
    # Don't save if env vars are set (they take precedence anyway)
    if System.get_env("LLM_PROVIDER") do
      Logger.info("[ConfigStore] Not saving - LLM_PROVIDER env var is set (takes precedence)")
      {:ok, :skipped}
    else
      config_with_timestamp = Map.put(config, "last_updated", DateTime.utc_now() |> DateTime.to_iso8601())

      path = @config_file
      dir = Path.dirname(path)

      with :ok <- File.mkdir_p(dir),
           json <- Jason.encode!(config_with_timestamp, pretty: true),
           :ok <- File.write(path, json),
           :ok <- File.chmod(path, 0o644) do
        {:ok, path}
      else
        error ->
          Logger.error("[ConfigStore] Failed to save config: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  @doc """
  Get the active provider with fallback logic.

  Returns the provider name from the hierarchy, with intelligent fallback:
  - If Ollama is running, prefer it (no credentials needed)
  - Otherwise use last-saved provider
  - Default to "ollama" in ephemeral environments
  """
  def get_active_provider do
    config = load_wireframe_config()
    provider = config["provider"]

    # In ephemeral environments, default to Ollama for better UX
    if is_ephemeral_storage?() && provider not in ["anthropic", "openai"] do
      "ollama"
    else
      provider || "ollama"
    end
  end

  @doc """
  Get the model for a specific provider.

  Checks environment variables first, then config file, then defaults.
  """
  def get_model_for_provider(provider) do
    config = load_wireframe_config()

    case provider do
      "anthropic" -> config["anthropic_model"] || "claude-sonnet-4-5"
      "openai" -> config["openai_model"] || "gpt-4o"
      "ollama" -> config["ollama_model"] || "qwen2.5:7b"
      _ -> nil
    end
  end

  @doc """
  Check if storage is ephemeral (Docker without volume mount).

  Returns true if KOALEMOS_EPHEMERAL_STORAGE env var is "true".
  """
  def is_ephemeral_storage? do
    System.get_env("KOALEMOS_EPHEMERAL_STORAGE") == "true"
  end

  @doc """
  Check if a config key is controlled by environment variable.

  Returns true if the corresponding env var is set.
  """
  def env_controlled?(key) do
    case key do
      "provider" -> System.get_env("LLM_PROVIDER") != nil
      "anthropic_model" -> System.get_env("ANTHROPIC_MODEL") != nil
      "openai_model" -> System.get_env("OPENAI_MODEL") != nil
      "ollama_model" -> System.get_env("OLLAMA_MODEL") != nil
      "ollama_base_url" -> System.get_env("OLLAMA_BASE_URL") != nil
      _ -> false
    end
  end

  # Private Functions

  defp load_from_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          {:error, reason} ->
            Logger.warning("[ConfigStore] Failed to parse #{path}: #{inspect(reason)}")
            %{}
        end

      {:error, :enoent} ->
        %{}

      {:error, reason} ->
        Logger.warning("[ConfigStore] Failed to read #{path}: #{inspect(reason)}")
        %{}
    end
  end

  defp load_from_env do
    %{
      "provider" => System.get_env("LLM_PROVIDER"),
      "anthropic_model" => System.get_env("ANTHROPIC_MODEL"),
      "openai_model" => System.get_env("OPENAI_MODEL"),
      "ollama_model" => System.get_env("OLLAMA_MODEL"),
      "ollama_base_url" => System.get_env("OLLAMA_BASE_URL")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp expand_path(path) do
    Path.expand(path)
  end
end
