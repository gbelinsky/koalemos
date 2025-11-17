defmodule Koalemos.OllamaClient do
  @moduledoc """
  HTTP client for Ollama API.

  Provides functions to check server availability and list available models.
  """

  require Logger

  @doc """
  Check if Ollama server is reachable.

  Returns `{:ok, :connected}` if server responds, `{:error, reason}` otherwise.

  ## Examples

      iex> OllamaClient.check_connection()
      {:ok, :connected}

      iex> OllamaClient.check_connection("http://localhost:99999")
      {:error, "Connection refused"}
  """
  def check_connection(base_url \\ nil) do
    # Allow configuring Ollama URL via environment variable (useful for Docker)
    # Compute at runtime, not compile time
    base_url = base_url || System.get_env("OLLAMA_BASE_URL") || "http://localhost:11434"
    url = "#{base_url}/api/tags"

    try do
      case Req.get(url, retry: false, connect_options: [timeout: 2000]) do
        {:ok, %{status: 200}} ->
          {:ok, :connected}

        {:ok, %{status: status}} ->
          {:error, "Server returned status #{status}"}

        {:error, %Req.TransportError{reason: :econnrefused}} ->
          {:error, "Connection refused - is Ollama running at #{base_url}?"}

        {:error, %Req.TransportError{reason: :timeout}} ->
          {:error, "Connection timeout"}

        {:error, error} ->
          {:error, "Connection failed: #{inspect(error)}"}
      end
    catch
      kind, error ->
        Logger.debug("[OllamaClient] Connection error (#{kind}): #{inspect(error)}")
        {:error, "Connection failed"}
    end
  end

  @doc """
  List available models from Ollama server.

  Returns `{:ok, models}` where models is a list of model names,
  or `{:error, reason}` if the request fails.

  ## Examples

      iex> OllamaClient.list_models()
      {:ok, ["llama3.2", "mistral", "codellama"]}

      iex> OllamaClient.list_models("http://localhost:99999")
      {:error, "Connection refused - is Ollama running at http://localhost:99999?"}
  """
  def list_models(base_url \\ nil) do
    # Allow configuring Ollama URL via environment variable (useful for Docker)
    # Compute at runtime, not compile time
    base_url = base_url || System.get_env("OLLAMA_BASE_URL") || "http://localhost:11434"
    url = "#{base_url}/api/tags"

    try do
      case Req.get(url, retry: false, connect_options: [timeout: 5000]) do
        {:ok, %{status: 200, body: body}} ->
          models = extract_model_names(body)
          {:ok, models}

        {:ok, %{status: status}} ->
          Logger.warning("[OllamaClient] Server returned status #{status}")
          {:error, "Server returned status #{status}"}

        {:error, %Req.TransportError{reason: :econnrefused}} ->
          Logger.info("[OllamaClient] Connection refused to #{base_url}")
          {:error, "Connection refused - is Ollama running at #{base_url}?"}

        {:error, %Req.TransportError{reason: :timeout}} ->
          Logger.warning("[OllamaClient] Connection timeout to #{base_url}")
          {:error, "Connection timeout"}

        {:error, error} ->
          Logger.error("[OllamaClient] Request failed: #{inspect(error)}")
          {:error, "Connection failed: #{inspect(error)}"}
      end
    catch
      kind, error ->
        Logger.debug("[OllamaClient] List models error (#{kind}): #{inspect(error)}")
        {:error, "Connection failed"}
    end
  end

  # Extract model names from Ollama API response
  defp extract_model_names(%{"models" => models}) when is_list(models) do
    Enum.map(models, fn model ->
      case model do
        %{"name" => name} -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  defp extract_model_names(_), do: []
end
