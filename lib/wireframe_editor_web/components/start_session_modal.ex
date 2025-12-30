defmodule WireframeEditorWeb.StartSessionModal do
  @moduledoc """
  Modal for starting a new chat routine.

  Features:
  - Provider selection (Anthropic, OpenAI, Ollama)
  - Provider-specific configuration:
    - Anthropic/OpenAI: API key input
    - Ollama: automatic server check and model dropdown
  - Generates unique routine_id
  - Navigates to chat page on start
  - Reusable across pages

  ## Usage

  ```heex
  <.live_component
    module={WireframeEditorWeb.StartSessionModal}
    id="start-session-modal"
    show={@show_modal}
  />
  ```

  ## Events

  The parent must handle:
  - `close_modal` - User clicked cancel or clicked away
  """
  use Phoenix.LiveComponent
  alias Koalemos.OllamaClient
  alias Koalemos.DemoCredentialStore
  alias Koalemos.SimpleCredentialManager

  @impl true
  def mount(socket) do
    # Load last used provider and config from credential store
    provider = DemoCredentialStore.get_selected_provider()

    # Load provider configs
    anthropic_config =
      case DemoCredentialStore.get_provider_config("anthropic") do
        {:ok, config} -> config
        _ -> %{"api_key" => "", "model" => "claude-haiku-4-5"}
      end

    openai_config =
      case DemoCredentialStore.get_provider_config("openai") do
        {:ok, config} -> config
        _ -> %{"api_key" => "", "model" => "gpt-4o"}
      end

    ollama_config =
      case DemoCredentialStore.get_provider_config("ollama") do
        {:ok, config} -> config
        _ -> %{"base_url" => "http://localhost:11434", "model" => "llama3.2"}
      end

    # Set current model based on provider
    model =
      case provider do
        "anthropic" -> Map.get(anthropic_config, "model", "claude-haiku-4-5")
        "openai" -> Map.get(openai_config, "model", "gpt-4o")
        "ollama" -> Map.get(ollama_config, "model", "llama3.2")
        _ -> "claude-haiku-4-5"
      end

    # OAuth check deferred to update/2 for faster initial render

    {:ok,
     assign(socket,
       provider: provider,
       model: model,
       anthropic_api_key: Map.get(anthropic_config, "api_key", ""),
       openai_api_key: Map.get(openai_config, "api_key", ""),
       has_oauth: false,
       oauth_checked: false,
       ollama_status: :not_checked,
       ollama_error: nil,
       ollama_models: []
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Initialize all assigns if not already set
    socket =
      socket
      |> assign_new(:provider, fn -> "anthropic" end)
      |> assign_new(:model, fn -> "claude-haiku-4-5" end)
      |> assign_new(:anthropic_api_key, fn -> "" end)
      |> assign_new(:openai_api_key, fn -> "" end)
      |> assign_new(:has_oauth, fn -> false end)
      |> assign_new(:oauth_checked, fn -> false end)
      |> assign_new(:ollama_status, fn -> :not_checked end)
      |> assign_new(:ollama_error, fn -> nil end)
      |> assign_new(:ollama_models, fn -> [] end)

    # Deferred OAuth check - only check once when socket is connected
    # Skip if has_oauth was explicitly passed in assigns (e.g., in tests)
    socket =
      if !socket.assigns.oauth_checked && !Map.has_key?(assigns, :has_oauth) do
        has_oauth = check_oauth_available()
        assign(socket, has_oauth: has_oauth, oauth_checked: true)
      else
        assign(socket, oauth_checked: true)
      end

    # Handle async Ollama connection result
    socket =
      if Map.has_key?(assigns, :ollama_result) do
        apply_ollama_result(socket, assigns.ollama_result)
      else
        socket
      end

    # Start async Ollama check if provider is ollama and not already checked/checking
    socket =
      if socket.assigns.provider == "ollama" && socket.assigns.ollama_status == :not_checked do
        start_async_ollama_check(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @show do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div
            class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8"
            phx-click-away="close_modal"
            phx-target={@myself}
          >
            <h2 class="text-2xl font-bold text-slate-800 mb-4">start new chat</h2>
            <p class="text-slate-600 mb-6">
              ready to begin a new conversation?
            </p>
            
    <!-- Provider Selection -->
            <form phx-change="update_config" phx-target={@myself}>
              <div class="mb-4">
                <label class="block text-sm font-medium text-slate-700 mb-2">
                  AI Provider
                </label>
                <select
                  name="provider"
                  class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="anthropic" selected={@provider == "anthropic"}>Anthropic</option>
                  <option value="openai" selected={@provider == "openai"}>OpenAI</option>
                  <option value="ollama" selected={@provider == "ollama"}>Ollama (Local)</option>
                </select>
              </div>
            </form>
            <!-- Provider-Specific Configuration -->
            <div class="mb-6">
              <%= if @provider == "anthropic" do %>
                <!-- Anthropic API Key -->
                <div>
                  <label class="block text-sm font-medium text-slate-700 mb-2">
                    API Key
                  </label>
                  <form phx-change="update_api_key" phx-target={@myself}>
                    <input type="hidden" name="provider" value="anthropic" />
                    <input
                      type="password"
                      name="api_key"
                      value={@anthropic_api_key}
                      placeholder="sk-ant-..."
                      class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    />
                  </form>
                  <p class="mt-1 text-xs text-slate-500">
                    Enter your Anthropic API key
                  </p>
                </div>
                <!-- Model Selection -->
                <div class="mt-4">
                  <label class="block text-sm font-medium text-slate-700 mb-2">
                    Model
                  </label>
                  <form phx-change="update_config" phx-target={@myself}>
                    <input type="hidden" name="provider" value="anthropic" />
                    <input
                      type="text"
                      name="model"
                      value={@model}
                      placeholder="claude-haiku-4-5"
                      class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    />
                  </form>
                  <p class="mt-1 text-xs text-slate-500">
                    e.g. claude-haiku-4-5, claude-sonnet-4-5
                  </p>
                </div>
              <% end %>
              <%= if @provider == "openai" do %>
                <!-- OpenAI API Key -->
                <div>
                  <label class="block text-sm font-medium text-slate-700 mb-2">
                    API Key
                  </label>
                  <form phx-change="update_api_key" phx-target={@myself}>
                    <input type="hidden" name="provider" value="openai" />
                    <input
                      type="password"
                      name="api_key"
                      value={@openai_api_key}
                      placeholder="sk-..."
                      class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    />
                  </form>
                  <p class="mt-1 text-xs text-slate-500">
                    Enter your OpenAI API key
                  </p>
                </div>
                <!-- Model Selection -->
                <div class="mt-4">
                  <label class="block text-sm font-medium text-slate-700 mb-2">
                    Model
                  </label>
                  <form phx-change="update_config" phx-target={@myself}>
                    <input type="hidden" name="provider" value="openai" />
                    <input
                      type="text"
                      name="model"
                      value={@model}
                      placeholder="gpt-4o"
                      class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    />
                  </form>
                  <p class="mt-1 text-xs text-slate-500">
                    e.g. gpt-4o, gpt-4o-mini
                  </p>
                </div>
              <% end %>
              <%= if @provider == "ollama" do %>
                <!-- Ollama Status -->
                <div class="mb-4">
                  <%= if @ollama_status == :checking do %>
                    <div class="flex items-center gap-2 text-sm text-blue-600 mb-3">
                      <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      <span>Checking Ollama connection...</span>
                    </div>
                  <% end %>
                  <%= if @ollama_status == :connected && length(@ollama_models) > 0 do %>
                    <div class="flex items-center gap-2 text-sm text-green-600 mb-3">
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fill-rule="evenodd"
                          d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      <span>Connected to Ollama</span>
                    </div>
                  <% end %>
                  <%= if @ollama_status == :error do %>
                    <div class="p-3 bg-red-50 border border-red-200 rounded-lg mb-3">
                      <p class="text-sm text-red-700">
                        {@ollama_error}
                      </p>
                    </div>
                  <% end %>
                  <%= if @ollama_error && @ollama_status == :connected do %>
                    <div class="p-3 bg-yellow-50 border border-yellow-200 rounded-lg mb-3">
                      <p class="text-sm text-yellow-700">
                        {@ollama_error}
                      </p>
                    </div>
                  <% end %>
                </div>
                <!-- Model Dropdown -->
                <div>
                  <label class="block text-sm font-medium text-slate-700 mb-2">
                    Model
                  </label>
                  <form phx-change="update_config" phx-target={@myself}>
                    <input type="hidden" name="provider" value="ollama" />
                    <select
                      name="model"
                      disabled={@ollama_status != :connected || length(@ollama_models) == 0}
                      class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-slate-100 disabled:text-slate-400"
                    >
                      <%= if length(@ollama_models) > 0 do %>
                        <%= for model <- @ollama_models do %>
                          <option value={model} selected={@model == model}>{model}</option>
                        <% end %>
                      <% else %>
                        <option value="">No models available</option>
                      <% end %>
                    </select>
                  </form>
                  <p class="mt-1 text-xs text-slate-500">
                    <%= cond do %>
                      <% @ollama_status == :checking -> %>
                        Checking connection...
                      <% @ollama_status == :connected && length(@ollama_models) > 0 -> %>
                        {length(@ollama_models)} model(s) available
                      <% true -> %>
                        Waiting for Ollama connection...
                    <% end %>
                  </p>
                </div>
              <% end %>
            </div>
            <!-- Action Buttons -->
            <div class="flex gap-3">
              <button
                phx-click="close_modal"
                phx-target={@myself}
                class="flex-1 px-4 py-3 bg-slate-100 text-slate-700 rounded-xl hover:bg-slate-200 transition-colors"
              >
                cancel
              </button>
              <button
                phx-click="start_chat"
                phx-target={@myself}
                disabled={!can_start?(assigns)}
                class={[
                  "flex-1 px-4 py-3 rounded-xl transition-all duration-200 shadow-md",
                  if(can_start?(assigns),
                    do:
                      "bg-gradient-to-br from-blue-500 to-indigo-600 text-white hover:from-blue-600 hover:to-indigo-700",
                    else: "bg-slate-200 text-slate-400 cursor-not-allowed"
                  )
                ]}
              >
                start
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), {:close_modal})
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_config", %{"provider" => provider} = params, socket) do
    model = Map.get(params, "model", socket.assigns.model)

    # If provider changed, update to default model and start async Ollama check if needed
    socket =
      if provider != socket.assigns.provider do
        default_model =
          case provider do
            "anthropic" -> "claude-haiku-4-5"
            "openai" -> "gpt-4o"
            "ollama" -> "llama3.2"
            _ -> "claude-haiku-4-5"
          end

        socket
        |> assign(provider: provider, model: default_model, ollama_status: :not_checked)
        |> then(fn s ->
          if provider == "ollama" do
            start_async_ollama_check(s)
          else
            s
          end
        end)
      else
        # Provider didn't change, just update model
        assign(socket, provider: provider, model: model)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_api_key", %{"provider" => provider, "api_key" => api_key}, socket) do
    socket =
      case provider do
        "anthropic" -> assign(socket, anthropic_api_key: api_key)
        "openai" -> assign(socket, openai_api_key: api_key)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_chat", _params, socket) do
    # Save config to credential store
    save_config(socket)

    # Generate truly unique routine ID with timestamp and random component
    routine_id = "routine-#{System.system_time(:millisecond)}-#{:rand.uniform(999_999)}"

    # Navigate with provider and model as query params
    url =
      "/chat/#{routine_id}?provider=#{socket.assigns.provider}&model=#{URI.encode_www_form(socket.assigns.model)}"

    send(self(), {:close_modal})
    {:noreply, push_navigate(socket, to: url)}
  end

  # Save current config to credential store
  defp save_config(socket) do
    provider = socket.assigns.provider
    model = socket.assigns.model

    # Save selected provider
    DemoCredentialStore.set_selected_provider(provider)

    # Save provider-specific config
    case provider do
      "anthropic" ->
        DemoCredentialStore.update_provider("anthropic", %{
          "api_key" => socket.assigns.anthropic_api_key,
          "model" => model
        })

      "openai" ->
        DemoCredentialStore.update_provider("openai", %{
          "api_key" => socket.assigns.openai_api_key,
          "model" => model
        })

      "ollama" ->
        DemoCredentialStore.update_provider("ollama", %{
          "model" => model
        })

      _ ->
        :ok
    end
  end

  # Async Ollama connection check - starts task and returns immediately
  defp start_async_ollama_check(socket) do
    component_id = socket.assigns.id
    parent_pid = self()

    # Start async task to check Ollama connection
    Task.start(fn ->
      result = do_ollama_check()
      # Send result back to parent LiveView which forwards to component
      send(parent_pid, {:ollama_check_complete, component_id, result})
    end)

    # Mark as checking so we don't start multiple tasks
    assign(socket, ollama_status: :checking)
  end

  # Perform the actual Ollama check (called in Task)
  defp do_ollama_check do
    case OllamaClient.check_connection() do
      {:ok, :connected} ->
        case OllamaClient.list_models() do
          {:ok, [_ | _] = models} ->
            {:connected, models}

          {:ok, []} ->
            {:connected_no_models, "No models found. Pull a model using: ollama pull llama3.2"}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Apply Ollama check result to socket (called from update when result arrives)
  defp apply_ollama_result(socket, result) do
    case result do
      {:connected, models} ->
        default_model =
          if socket.assigns.model in models do
            socket.assigns.model
          else
            hd(models)
          end

        assign(socket,
          ollama_status: :connected,
          ollama_error: nil,
          ollama_models: models,
          model: default_model
        )

      {:connected_no_models, message} ->
        assign(socket,
          ollama_status: :connected,
          ollama_error: message,
          ollama_models: []
        )

      {:error, reason} ->
        assign(socket,
          ollama_status: :error,
          ollama_error: reason,
          ollama_models: []
        )
    end
  end

  # Validation helper - check if user can start a chat
  # For Anthropic: Allow if API key entered OR OAuth available
  # For OpenAI: Require API key
  # For Ollama: Require server connection
  defp can_start?(assigns) do
    case assigns.provider do
      "anthropic" -> assigns.anthropic_api_key != "" || assigns.has_oauth
      "openai" -> assigns.openai_api_key != ""
      "ollama" -> assigns.ollama_status == :connected && assigns.model != ""
      _ -> false
    end
  end

  # Check if OAuth credentials are available
  defp check_oauth_available do
    try do
      case SimpleCredentialManager.get_access_token() do
        {:ok, _token} -> true
        {:error, _} -> false
      end
    catch
      :exit, _ -> false
    end
  end
end
