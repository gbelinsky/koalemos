defmodule Koalemos.DemoCredentialStore do
  @moduledoc """
  Simple file-based credential storage for demo purposes.

  Stores provider credentials in .koalemos/.credentials.json for persistence
  across Docker container restarts. Maintains backward compatibility with
  existing OAuth credentials.

  File format:
  ```json
  {
    "claudeAiOauth": {...},  // Existing OAuth section (preserved)
    "providers": {
      "anthropic": {"api_key": "...", "model": "..."},
      "openai": {"api_key": "...", "model": "..."},
      "ollama": {"base_url": "...", "model": "..."}
    },
    "selected_provider": "anthropic"
  }
  ```

  Note: This is NOT production-ready. No encryption, simple file locking,
  last-write-wins concurrency model. Perfect for Docker demo.
  """

  require Logger

  @default_path ".koalemos/.credentials.json"
  @lock_timeout 5000

  @doc """
  Load the entire credentials file.
  Creates file with defaults if it doesn't exist.
  """
  def load do
    path = get_credentials_path()

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            # Ensure providers section exists
            data = ensure_providers_section(data)
            {:ok, data}

          {:error, reason} ->
            Logger.error("Failed to parse credentials JSON: #{inspect(reason)}")
            backup_and_recreate(path)
        end

      {:error, :enoent} ->
        # File doesn't exist, create with defaults
        Logger.info("Credentials file not found, creating with defaults at #{path}")
        create_default_file(path)

      {:error, reason} ->
        Logger.error("Failed to read credentials file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get configuration for a specific provider.
  Returns default config if provider not found.
  """
  def get_provider_config(provider) do
    case load() do
      {:ok, data} ->
        config = get_in(data, ["providers", provider]) || default_provider_config(provider)
        {:ok, config}

      error ->
        error
    end
  end

  @doc """
  Update a specific provider's configuration.
  Merges updates with existing config.
  """
  def update_provider(provider, updates) when is_map(updates) do
    with_lock(fn ->
      case load() do
        {:ok, data} ->
          # Get current provider config
          current = get_in(data, ["providers", provider]) || default_provider_config(provider)

          # Merge updates
          updated_config = Map.merge(current, updates)

          # Update data structure
          updated_data = put_in(data, ["providers", provider], updated_config)

          # Write back to file
          write_file(updated_data)

        error ->
          error
      end
    end)
  end

  @doc """
  Get the currently selected provider.
  Returns "anthropic" if not set.
  """
  def get_selected_provider do
    case load() do
      {:ok, data} ->
        Map.get(data, "selected_provider", "anthropic")

      {:error, _} ->
        "anthropic"
    end
  end

  @doc """
  Set the currently selected provider.
  """
  def set_selected_provider(provider) when provider in ["anthropic", "openai", "ollama"] do
    with_lock(fn ->
      case load() do
        {:ok, data} ->
          updated_data = Map.put(data, "selected_provider", provider)
          write_file(updated_data)

        error ->
          error
      end
    end)
  end

  def set_selected_provider(provider) do
    {:error, "Invalid provider: #{provider}. Must be anthropic, openai, or ollama"}
  end

  @doc """
  Get all provider API keys (without other config like models).
  Returns empty strings for missing keys.
  """
  def get_all_api_keys do
    case load() do
      {:ok, data} ->
        %{
          "anthropic" => get_in(data, ["providers", "anthropic", "api_key"]) || "",
          "openai" => get_in(data, ["providers", "openai", "api_key"]) || ""
        }

      _ ->
        %{"anthropic" => "", "openai" => ""}
    end
  end

  @doc """
  Update API keys for multiple providers.
  Only updates API keys, preserves other settings like models and base URLs.
  Does not affect OAuth section.
  """
  def update_api_keys(keys) when is_map(keys) do
    with_lock(fn ->
      case load() do
        {:ok, data} ->
          # Update each provider's API key while preserving other fields
          updated_data =
            Enum.reduce(keys, data, fn {provider, key}, acc ->
              # Get current provider config (or default)
              current = get_in(acc, ["providers", provider]) || default_provider_config(provider)

              # Update only the api_key field
              updated_provider = Map.put(current, "api_key", key)

              # Put back into data structure
              put_in(acc, ["providers", provider], updated_provider)
            end)

          write_file(updated_data)

        error ->
          error
      end
    end)
  end

  ## Private Functions

  defp get_credentials_path do
    System.get_env("KOALEMOS_CREDENTIALS_PATH") || @default_path
  end

  defp ensure_providers_section(data) do
    providers = Map.get(data, "providers", %{})

    # Ensure each provider has a config
    providers =
      providers
      |> Map.put_new("anthropic", default_provider_config("anthropic"))
      |> Map.put_new("openai", default_provider_config("openai"))
      |> Map.put_new("ollama", default_provider_config("ollama"))

    data
    |> Map.put("providers", providers)
    |> Map.put_new("selected_provider", "anthropic")
  end

  defp default_provider_config("anthropic") do
    %{
      "api_key" => "",
      "model" => "claude-3-5-sonnet-20241022"
    }
  end

  defp default_provider_config("openai") do
    %{
      "api_key" => "",
      "model" => "gpt-4"
    }
  end

  defp default_provider_config("ollama") do
    %{
      "base_url" => "http://localhost:11434",
      "model" => "llama2"
    }
  end

  defp create_default_file(path) do
    # Ensure directory exists
    path
    |> Path.dirname()
    |> File.mkdir_p()

    default_data = %{
      "providers" => %{
        "anthropic" => default_provider_config("anthropic"),
        "openai" => default_provider_config("openai"),
        "ollama" => default_provider_config("ollama")
      },
      "selected_provider" => "anthropic"
    }

    case write_file(default_data) do
      :ok ->
        Logger.info("Created default credentials file at #{path}")
        {:ok, default_data}

      error ->
        error
    end
  end

  defp backup_and_recreate(path) do
    # Backup corrupted file
    backup_path = "#{path}.backup.#{System.system_time(:second)}"

    case File.rename(path, backup_path) do
      :ok ->
        Logger.warning("Backed up corrupted credentials to #{backup_path}")
        create_default_file(path)

      {:error, reason} ->
        Logger.error("Failed to backup corrupted file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp write_file(data) do
    path = get_credentials_path()
    temp_path = "#{path}.tmp"

    # Encode as pretty JSON
    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        # Write to temp file first
        case File.write(temp_path, json) do
          :ok ->
            # Atomic rename
            case File.rename(temp_path, path) do
              :ok ->
                # Set restrictive permissions (owner read/write only)
                File.chmod(path, 0o600)
                Logger.debug("Wrote credentials to #{path}")
                :ok

              {:error, reason} ->
                Logger.error("Failed to rename temp file: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, reason} ->
            Logger.error("Failed to write temp file: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to encode JSON: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp with_lock(fun) do
    # Simple file-based locking
    lock_path = "#{get_credentials_path()}.lock"

    # Try to acquire lock
    case acquire_lock(lock_path) do
      :ok ->
        try do
          fun.()
        after
          release_lock(lock_path)
        end

      {:error, :timeout} ->
        Logger.error("Failed to acquire lock after #{@lock_timeout}ms")
        {:error, :lock_timeout}
    end
  end

  defp acquire_lock(lock_path) do
    start_time = System.monotonic_time(:millisecond)
    acquire_lock_retry(lock_path, start_time)
  end

  defp acquire_lock_retry(lock_path, start_time) do
    # Ensure directory exists for lock file
    lock_path
    |> Path.dirname()
    |> File.mkdir_p()

    # Try to create lock file exclusively
    case File.open(lock_path, [:write, :exclusive]) do
      {:ok, file} ->
        File.close(file)
        :ok

      {:error, :eexist} ->
        # Lock exists, check if it's stale
        elapsed = System.monotonic_time(:millisecond) - start_time

        if elapsed > @lock_timeout do
          # Timeout, remove stale lock
          Logger.warning("Removing stale lock file")
          File.rm(lock_path)
          {:error, :timeout}
        else
          # Wait and retry
          :timer.sleep(50)
          acquire_lock_retry(lock_path, start_time)
        end

      {:error, reason} ->
        Logger.error("Failed to acquire lock: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp release_lock(lock_path) do
    File.rm(lock_path)
  end
end
