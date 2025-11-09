defmodule Koalemos.Steps.Agent.LLMRequest do
  @moduledoc """
  LLMRequest step routes to appropriate LLM provider plugin.

  This step acts as a router that:
  1. Determines which provider to use (from context `:llm_provider`)
  2. Resolves credentials for that provider
  3. Delegates to the provider module (implements `Koalemos.LLMProvider` behavior)
  4. Returns the llm_response in context for ResponseParsing step

  ## Context Input
  - messages: Conversation history (required)
  - tool_descriptions: Tool schemas from ToolSchema step
  - lens_contexts: Context blocks from LensRendering step
  - llm_provider: Provider name ("anthropic", "openai", "ollama"), default: "anthropic"
  - llm_model: Model name (provider-specific), uses provider default if not set
  - max_tokens: Maximum tokens to generate, default: 16384
  - temperature: Sampling temperature, default: 0.1
  - llm_base_url: Override base URL (optional, for testing/proxies)

  ## Context Output
  - llm_response: Raw API response (for ResponseParsing step)

  ## Provider Modules

  - `Koalemos.LLMProviders.Anthropic` - Anthropic Claude API
  - `Koalemos.LLMProviders.OpenAI` - OpenAI API
  - `Koalemos.LLMProviders.Ollama` - Local Ollama server

  ## Example

  ```elixir
  llm_request: %{
    type: Koalemos.Steps.Agent.LLMRequest,
    transitions: [
      {:parse_response, :always}
    ]
  }
  ```
  """

  require Logger

  @doc """
  Route to appropriate provider and make LLM request.
  """
  def execute(_config, state) do
    messages = Map.get(state.context, :messages, [])

    case messages do
      [] ->
        {:error, "No messages found in context"}

      _ ->
        # Get provider configuration
        provider_name = Map.get(state.context, :llm_provider, "anthropic")

        # Resolve provider module
        case resolve_provider(provider_name) do
          {:ok, provider_module} ->
            # Get credentials for this provider
            case get_credentials(provider_name, state.context) do
              {:ok, credentials} ->
                # Prepare inputs for provider
                tool_descriptions = Map.get(state.context, :tool_descriptions, [])

                # Get lens contexts (both text and images)
                lens_contexts = %{
                  text: Map.get(state.context, :lens_text_contexts, []),
                  images: Map.get(state.context, :lens_image_contexts, [])
                }

                # Build config map from context
                config = %{
                  model: Map.get(state.context, :llm_model),
                  max_tokens: Map.get(state.context, :max_tokens, 16384),
                  temperature: Map.get(state.context, :temperature, 0.1),
                  base_url: Map.get(state.context, :llm_base_url)
                }

                # Log lens contexts for debugging
                text_contexts = lens_contexts.text || []
                if length(text_contexts) > 0 do
                  full_text = Enum.map_join(text_contexts, "\n---\n", fn ctx ->
                    ctx.text || ""
                  end)

                  has_live_dom = String.contains?(full_text, "LIVE DOM STATE")
                  has_design_dom = String.contains?(full_text, "DESIGN DOM STRUCTURE")

                  Logger.info("[LLMRequest] Lens context sections present:")
                  Logger.info("  - DESIGN DOM STRUCTURE: #{has_design_dom}")
                  Logger.info("  - LIVE DOM STATE: #{has_live_dom}")
                  Logger.info("  - Total context length: #{String.length(full_text)} chars")

                  # Show first 1000 chars for preview
                  preview = if String.length(full_text) > 1000 do
                    String.slice(full_text, 0, 1000) <> "\n... (#{String.length(full_text) - 1000} more chars)"
                  else
                    full_text
                  end
                  Logger.debug("[LLMRequest] Context preview:\n#{preview}")
                end

                # Delegate to provider
                Logger.info("LLMRequest: Routing to #{provider_name} provider")
                Logger.debug("LLMRequest: #{length(tool_descriptions)} tools available, #{length(messages)} messages")
                provider_module.call(
                  messages,
                  credentials,
                  tool_descriptions,
                  lens_contexts,
                  config,
                  state.routine_id
                )

              {:error, reason} ->
                {:error, "Failed to get credentials: #{inspect(reason)}"}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # Resolve provider name to module
  defp resolve_provider("anthropic"), do: {:ok, Koalemos.LLMProviders.Anthropic}
  defp resolve_provider("openai"), do: {:ok, Koalemos.LLMProviders.OpenAI}
  defp resolve_provider("ollama"), do: {:ok, Koalemos.LLMProviders.Ollama}
  defp resolve_provider(unknown), do: {:error, "Unknown provider: #{unknown}"}

  # Get credentials for provider
  defp get_credentials("anthropic", context) do
    # Try API key from DemoCredentialStore first
    case Koalemos.DemoCredentialStore.get_provider_config("anthropic") do
      {:ok, config} when is_map(config) ->
        api_key = Map.get(config, "api_key", "")

        if api_key != "" do
          # Use API key from settings
          Logger.info("LLMRequest: Using Anthropic API key from DemoCredentialStore")
          base_url = Map.get(context, :llm_base_url, "https://api.anthropic.com/v1")
          {:ok, %{
            provider: :anthropic,
            api_key: api_key,
            base_url: base_url,
            auth_type: :api_key
          }}
        else
          # No API key, fall back to OAuth
          Logger.info("LLMRequest: No API key in settings, falling back to OAuth")
          get_oauth_credentials()
        end

      {:error, reason} ->
        # Credential store failed, try OAuth fallback
        Logger.warning("LLMRequest: DemoCredentialStore failed (#{inspect(reason)}), falling back to OAuth")
        get_oauth_credentials()
    end
  end

  defp get_credentials("openai", _context) do
    case Koalemos.DemoCredentialStore.get_provider_config("openai") do
      {:ok, config} when is_map(config) ->
        api_key = Map.get(config, "api_key", "")

        if api_key != "" do
          Logger.info("LLMRequest: Using OpenAI API key from DemoCredentialStore")
          {:ok, %{
            provider: :openai,
            api_key: api_key,
            base_url: "https://api.openai.com/v1"
          }}
        else
          {:error, "OpenAI API key not configured"}
        end

      {:error, reason} ->
        {:error, "Failed to get OpenAI credentials: #{inspect(reason)}"}
    end
  end

  defp get_credentials("ollama", _context) do
    # Ollama doesn't need API keys, just base URL and model
    case Koalemos.DemoCredentialStore.get_provider_config("ollama") do
      {:ok, config} when is_map(config) ->
        Logger.info("LLMRequest: Using Ollama from DemoCredentialStore")
        base_url = Map.get(config, "base_url", "http://localhost:11434")
        model = Map.get(config, "model", "llama2")

        {:ok, %{
          provider: :ollama,
          api_key: nil,
          base_url: base_url,
          model: model
        }}

      {:error, reason} ->
        # Ollama can fall back to default config (reasonable for local server)
        Logger.warning("LLMRequest: DemoCredentialStore failed (#{inspect(reason)}), using default Ollama config")
        {:ok, %{
          provider: :ollama,
          api_key: nil,
          base_url: "http://localhost:11434",
          model: "llama2"
        }}
    end
  end

  defp get_credentials(unknown, _context) do
    {:error, "Unknown provider: #{unknown}"}
  end

  # Get OAuth credentials from SimpleCredentialManager
  defp get_oauth_credentials do
    try do
      case Koalemos.SimpleCredentialManager.get_access_token() do
        {:ok, access_token} ->
          Logger.info("LLMRequest: Using OAuth token from SimpleCredentialManager")
          {:ok, %{
            provider: :anthropic,
            api_key: access_token,
            base_url: "https://api.anthropic.com/v1",
            auth_type: :oauth
          }}

        {:error, reason} ->
          {:error, "OAuth fallback failed: #{inspect(reason)}"}
      end
    catch
      :exit, {:noproc, _} ->
        {:error, "SimpleCredentialManager not available (OAuth not configured)"}
      :exit, reason ->
        {:error, "OAuth fallback failed: #{inspect(reason)}"}
    end
  end
end
