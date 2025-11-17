defmodule KoalemosWeb.ErrorHelper do
  @moduledoc """
  Converts technical error messages into user-friendly messages with actionable steps.

  Handles common errors:
  - Missing/invalid API keys
  - Ollama connectivity issues
  - Network problems
  - Model availability
  """

  @doc """
  Converts a technical error message into a user-friendly struct with:
  - title: Short user-facing title
  - message: Detailed explanation
  - actions: List of suggested actions to fix the issue
  - technical_details: Original error (for debugging)
  """
  def format_error(error_string) when is_binary(error_string) do
    cond do
      # Anthropic API key errors
      String.contains?(error_string, "invalid x-api-key") ||
      String.contains?(error_string, "Invalid bearer token") ->
        %{
          title: "Invalid API Key",
          message: "Your Anthropic API key is invalid or has expired.",
          actions: [
            "Check that your API key is correct in the provider settings",
            "Make sure you copied the entire key (starts with 'sk-ant-')",
            "Verify your API key is active at https://console.anthropic.com",
            "Try generating a new API key if needed"
          ],
          severity: :error,
          technical_details: error_string
        }

      # OpenAI API key errors
      String.contains?(error_string, "Incorrect API key provided") ->
        %{
          title: "Invalid OpenAI API Key",
          message: "Your OpenAI API key is invalid or has expired.",
          actions: [
            "Check that your API key is correct in the provider settings",
            "Make sure you copied the entire key (starts with 'sk-')",
            "Verify your API key at https://platform.openai.com/account/api-keys",
            "Try creating a new API key if needed"
          ],
          severity: :error,
          technical_details: error_string
        }

      # Ollama not running
      String.contains?(error_string, "Connection refused") &&
      String.contains?(error_string, "Ollama") ->
        # Extract the URL if present
        url = extract_url(error_string) || "http://localhost:11434"

        %{
          title: "Can't Connect to Ollama",
          message: "Koalemos can't reach your Ollama server at #{url}.",
          actions: [
            "Make sure Ollama is installed: https://ollama.com",
            "Start Ollama: run 'ollama serve' in a terminal",
            "Check if Ollama is running: try 'ollama list' in a terminal",
            "If using Docker, ensure OLLAMA_BASE_URL is set correctly",
            "For Docker, use 'http://host.docker.internal:11434' to reach host Ollama"
          ],
          severity: :error,
          technical_details: error_string
        }

      # Ollama model not found
      String.contains?(error_string, "model") && String.contains?(error_string, "not found") ->
        model = extract_model_name(error_string) || "the requested model"

        %{
          title: "Model Not Available",
          message: "The model '#{model}' is not available in your Ollama installation.",
          actions: [
            "Pull the model: run 'ollama pull #{model}' in a terminal",
            "Check available models: run 'ollama list'",
            "Try a different model (e.g., llama3.2, qwen2.5, mistral)",
            "See available models at https://ollama.com/library"
          ],
          severity: :warning,
          technical_details: error_string
        }

      # Generic connection errors
      String.contains?(error_string, "Connection refused") ->
        %{
          title: "Connection Failed",
          message: "Can't connect to the AI service.",
          actions: [
            "Check your internet connection",
            "Verify the service URL is correct",
            "If using a local service, make sure it's running",
            "Check firewall settings if applicable"
          ],
          severity: :error,
          technical_details: error_string
        }

      # API quota/rate limit errors
      String.contains?(error_string, "rate limit") || String.contains?(error_string, "429") ->
        %{
          title: "Rate Limit Exceeded",
          message: "You've made too many requests. The API is temporarily blocking new requests.",
          actions: [
            "Wait a few minutes before trying again",
            "Check your API usage at your provider's dashboard",
            "Consider upgrading your API plan for higher limits",
            "For heavy usage, implement request throttling"
          ],
          severity: :warning,
          technical_details: error_string
        }

      # Timeout errors
      String.contains?(error_string, "timeout") || String.contains?(error_string, "timed out") ->
        %{
          title: "Request Timed Out",
          message: "The AI service took too long to respond.",
          actions: [
            "Try again - this might be a temporary network issue",
            "If using Ollama, ensure your model is loaded (first request is slow)",
            "Check your network connection",
            "For complex requests, try breaking them into smaller parts"
          ],
          severity: :warning,
          technical_details: error_string
        }

      # Invalid request/format errors
      String.contains?(error_string, "Invalid request") ||
      String.contains?(error_string, "Bad request") ->
        %{
          title: "Invalid Request",
          message: "The request sent to the AI service was not formatted correctly.",
          actions: [
            "This is likely a bug in Koalemos - please report it",
            "Try restarting your chat session",
            "Check the console for more details if you're a developer"
          ],
          severity: :error,
          technical_details: error_string
        }

      # Generic error
      true ->
        %{
          title: "Something Went Wrong",
          message: "An unexpected error occurred.",
          actions: [
            "Try refreshing the page",
            "Check your internet connection",
            "If the problem persists, check the technical details below"
          ],
          severity: :error,
          technical_details: error_string
        }
    end
  end

  def format_error(nil), do: nil
  def format_error(error) when is_map(error), do: error
  def format_error(error), do: format_error(inspect(error))

  # Extract URL from error message like "Connection refused - is Ollama running at http://localhost:11434?"
  defp extract_url(error_string) do
    case Regex.run(~r/https?:\/\/[^\s\?]+/, error_string) do
      [url] -> url
      _ -> nil
    end
  end

  # Extract model name from error message like "model 'llama2' not found"
  defp extract_model_name(error_string) do
    case Regex.run(~r/model [''"]([^''"]+)[''"]/, error_string) do
      [_, model] -> model
      _ -> nil
    end
  end

  @doc """
  Returns CSS classes for error severity styling.
  """
  def severity_classes(:error), do: "bg-red-50 border-red-200 text-red-800"
  def severity_classes(:warning), do: "bg-yellow-50 border-yellow-200 text-yellow-800"
  def severity_classes(:info), do: "bg-blue-50 border-blue-200 text-blue-800"
  def severity_classes(_), do: "bg-gray-50 border-gray-200 text-gray-800"

  @doc """
  Returns icon color classes for error severity.
  """
  def severity_icon_color(:error), do: "text-red-600"
  def severity_icon_color(:warning), do: "text-yellow-600"
  def severity_icon_color(:info), do: "text-blue-600"
  def severity_icon_color(_), do: "text-gray-600"
end
