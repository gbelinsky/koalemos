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
  require Koalemos.Log
  alias Koalemos.Log

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

                # Get lens contexts (both text and images) and step system prompt
                lens_contexts = %{
                  text: Map.get(state.context, :lens_text_contexts, []),
                  images: Map.get(state.context, :lens_image_contexts, []),
                  step_prompt: Map.get(state.context, :step_system_prompt)
                }

                # Build config map from context
                config = %{
                  model: Map.get(state.context, :llm_model),
                  max_tokens: Map.get(state.context, :max_tokens, 16384),
                  temperature: Map.get(state.context, :temperature, 0.1),
                  base_url: Map.get(state.context, :llm_base_url)
                }

                # Delegate to provider (context already logged by LensRendering step)
                Log.debug(:llm, "[LLMRequest] Routing to #{provider_name}, #{length(tool_descriptions)} tools, #{length(messages)} messages")

                result = provider_module.call(
                  messages,
                  credentials,
                  tool_descriptions,
                  lens_contexts,
                  config,
                  state.routine_id
                )

                # Log request/response when enabled
                if state.context[:enable_llm_logging] do
                  log_llm_request(state, provider_name, config, lens_contexts, messages, tool_descriptions, result)
                end

                result

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
          base_url = Map.get(context, :llm_base_url, "https://api.anthropic.com/v1")

          {:ok,
           %{
             provider: :anthropic,
             api_key: api_key,
             base_url: base_url,
             auth_type: :api_key
           }}
        else
          # No API key, fall back to OAuth
          get_oauth_credentials()
        end

      {:error, reason} ->
        # Credential store failed, try OAuth fallback
        Logger.warning(
          "LLMRequest: DemoCredentialStore failed (#{inspect(reason)}), falling back to OAuth"
        )

        get_oauth_credentials()
    end
  end

  defp get_credentials("openai", _context) do
    case Koalemos.DemoCredentialStore.get_provider_config("openai") do
      {:ok, config} when is_map(config) ->
        api_key = Map.get(config, "api_key", "")

        if api_key != "" do

          {:ok,
           %{
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
        base_url = Map.get(config, "base_url", "http://localhost:11434")
        model = Map.get(config, "model", "llama2")

        {:ok,
         %{
           provider: :ollama,
           api_key: nil,
           base_url: base_url,
           model: model
         }}

      {:error, reason} ->
        # Ollama can fall back to default config (reasonable for local server)
        Logger.warning(
          "LLMRequest: DemoCredentialStore failed (#{inspect(reason)}), using default Ollama config"
        )

        {:ok,
         %{
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

          {:ok,
           %{
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

  # Log LLM request/response via event system
  defp log_llm_request(state, provider_name, config, lens_contexts, messages, tool_descriptions, result) do
    # Build system prompt blocks from lens contexts
    system_blocks = build_system_blocks(lens_contexts)

    # Extract response data from the diff format returned by providers
    # Provider returns {:ok, [{:add_or_update, %{llm_response: body}}]}
    {response_data, usage} = case result do
      {:ok, diff} when is_list(diff) ->
        llm_response = extract_llm_response_from_diff(diff)
        {summarize_response(llm_response), extract_usage(llm_response)}
      {:error, reason} ->
        {%{error: inspect(reason)}, nil}
      _ ->
        {%{error: "Unexpected result format"}, nil}
    end

    # Summarize tools
    tools = Enum.map(tool_descriptions || [], fn tool ->
      %{
        name: Map.get(tool, :name) || Map.get(tool, "name"),
        description: truncate_text(Map.get(tool, :description) || Map.get(tool, "description") || "", 100)
      }
    end)

    Koalemos.Engine.EventRecorder.record_event(state, "llm_request_complete", %{
      provider: provider_name,
      model: config[:model],
      request: %{
        system_blocks: system_blocks,
        messages: messages,
        tools: tools
      },
      response: response_data,
      usage: usage
    })
  end

  defp build_system_blocks(lens_contexts) do
    text_blocks = lens_contexts[:text] || []
    step_prompt = lens_contexts[:step_prompt]

    blocks = Enum.map(text_blocks, fn
      %{text: text} -> %{type: "lens_context", text: text}
      text when is_binary(text) -> %{type: "lens_context", text: text}
      other -> %{type: "lens_context", text: inspect(other)}
    end)

    if step_prompt do
      [%{type: "step_prompt", text: step_prompt} | blocks]
    else
      blocks
    end
  end

  defp truncate_text(text, max) when is_binary(text) and byte_size(text) > max do
    String.slice(text, 0, max) <> "..."
  end
  defp truncate_text(text, _) when is_binary(text), do: text
  defp truncate_text(_, _), do: ""

  # Extract llm_response from the diff list returned by providers
  defp extract_llm_response_from_diff(diff) when is_list(diff) do
    Enum.find_value(diff, %{}, fn
      {:add_or_update, %{llm_response: response}} -> response
      [:add_or_update, %{llm_response: response}] -> response
      _ -> nil
    end)
  end

  defp summarize_response(response) when is_map(response) do
    # Extract key parts without the full raw response
    # Handle both string and atom keys
    content = Map.get(response, "content") || Map.get(response, :content) || []

    %{
      content: content,
      stop_reason: Map.get(response, "stop_reason") || Map.get(response, :stop_reason),
      model: Map.get(response, "model") || Map.get(response, :model)
    }
  end

  defp summarize_response(_), do: %{content: [], stop_reason: nil, model: nil}

  defp extract_usage(response) when is_map(response) do
    usage = Map.get(response, "usage") || Map.get(response, :usage)

    case usage do
      nil -> nil
      u when is_map(u) -> %{
        input_tokens: Map.get(u, "input_tokens") || Map.get(u, :input_tokens),
        output_tokens: Map.get(u, "output_tokens") || Map.get(u, :output_tokens)
      }
      _ -> nil
    end
  end

  defp extract_usage(_), do: nil
end
