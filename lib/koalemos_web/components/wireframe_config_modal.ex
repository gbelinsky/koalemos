defmodule KoalemosWeb.WireframeConfigModal do
  @moduledoc """
  Modal for configuring wireframe editor.

  Features:
  - Provider selection (Anthropic, OpenAI, Ollama)
  - API key management (no OAuth)
  - Model selection
  - Wireframe sample selection or HTML upload
  - Ephemeral storage warning for Docker
  - Integration with ConfigStore and DemoCredentialStore

  ## Usage

  ```heex
  <.live_component
    module={KoalemosWeb.WireframeConfigModal}
    id="wireframe-config-modal"
    show={@show_modal}
  />
  ```

  ## Events

  The parent must handle:
  - `close_modal` - User clicked cancel or clicked away
  - `config_complete` - User completed configuration, includes provider/model/wireframe
  """
  use Phoenix.LiveComponent
  alias Koalemos.OllamaClient
  alias Koalemos.DemoCredentialStore
  alias Koalemos.ConfigStore
  alias Koalemos.SimpleCredentialManager

  @impl true
  def mount(socket) do
    # Load from ConfigStore (merges env, file, localStorage, defaults)
    config = ConfigStore.load_wireframe_config()

    provider = Map.get(config, "provider", "ollama")

    # Load API keys from DemoCredentialStore
    api_keys = DemoCredentialStore.get_all_api_keys()

    # Get models for each provider
    anthropic_model = ConfigStore.get_model_for_provider("anthropic")
    openai_model = ConfigStore.get_model_for_provider("openai")
    ollama_model = ConfigStore.get_model_for_provider("ollama")

    # Set current model based on provider
    model = ConfigStore.get_model_for_provider(provider)

    # Check for ephemeral storage
    is_ephemeral = ConfigStore.is_ephemeral_storage?()

    # Check if OAuth credentials are available for Anthropic (hidden from UI)
    has_oauth = check_oauth_available()

    {:ok,
     assign(socket,
       provider: provider,
       model: model,
       anthropic_model: anthropic_model,
       openai_model: openai_model,
       ollama_model: ollama_model,
       anthropic_api_key: Map.get(api_keys, "anthropic", ""),
       openai_api_key: Map.get(api_keys, "openai", ""),
       has_oauth: has_oauth,
       ollama_status: :not_checked,
       ollama_error: nil,
       ollama_models: [],
       is_ephemeral: is_ephemeral,
       selected_sample: "blank",
       show_upload: false
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Initialize all assigns if not already set
    socket =
      socket
      |> assign_new(:provider, fn -> "ollama" end)
      |> assign_new(:model, fn -> "qwen2.5:7b" end)
      |> assign_new(:anthropic_model, fn -> "claude-sonnet-4-5" end)
      |> assign_new(:openai_model, fn -> "gpt-4o" end)
      |> assign_new(:ollama_model, fn -> "qwen2.5:7b" end)
      |> assign_new(:anthropic_api_key, fn -> "" end)
      |> assign_new(:openai_api_key, fn -> "" end)
      |> assign_new(:has_oauth, fn -> check_oauth_available() end)
      |> assign_new(:ollama_status, fn -> :not_checked end)
      |> assign_new(:ollama_error, fn -> nil end)
      |> assign_new(:ollama_models, fn -> [] end)
      |> assign_new(:is_ephemeral, fn -> ConfigStore.is_ephemeral_storage?() end)
      |> assign_new(:selected_sample, fn -> "blank" end)
      |> assign_new(:show_upload, fn -> false end)

    # Check Ollama connection if provider is ollama and not already checked
    socket =
      if socket.assigns.provider == "ollama" && socket.assigns.ollama_status == :not_checked do
        check_ollama_connection(socket)
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
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div
            class="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-8 my-8"
            phx-click-away="close_modal"
            phx-target={@myself}
          >
            <h2 class="text-2xl font-bold text-slate-800 mb-2">wireframe editor</h2>
            <p class="text-slate-600 mb-6">
              configure your AI provider and choose a starting wireframe
            </p>

            <%= if @is_ephemeral do %>
              <div class="mb-6 p-4 bg-amber-50 border-l-4 border-amber-400 rounded-lg">
                <div class="flex items-start gap-3">
                  <svg
                    class="w-5 h-5 text-amber-600 mt-0.5 flex-shrink-0"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <div>
                    <p class="text-sm font-medium text-amber-800 mb-1">
                      Running in ephemeral storage mode
                    </p>
                    <p class="text-xs text-amber-700">
                      Credentials and config won't persist across container restarts. To save permanently, mount a volume at <code class="bg-amber-100 px-1 rounded">/app/.koalemos</code>
                      or set environment variables.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>

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
                  <option value="ollama" selected={@provider == "ollama"}>
                    Ollama (Local, No API Key)
                  </option>
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
                    Get your key at <a
                      href="https://console.anthropic.com"
                      target="_blank"
                      class="text-blue-600 hover:underline"
                    >console.anthropic.com</a>
                  </p>
                </div>
                <!-- Model Selection -->
                <div class="mt-4">
                  <label class="block text-sm font-medium text-slate-700 mb-2">
                    Model
                  </label>
                  <form phx-change="update_model" phx-target={@myself}>
                    <input type="hidden" name="provider" value="anthropic" />
                    <input
                      type="text"
                      name="model"
                      value={@anthropic_model}
                      placeholder="claude-sonnet-4-5"
                      class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    />
                  </form>
                  <p class="mt-1 text-xs text-slate-500">
                    e.g. claude-sonnet-4-5, claude-haiku-4-5
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
                    Get your key at <a
                      href="https://platform.openai.com/api-keys"
                      target="_blank"
                      class="text-blue-600 hover:underline"
                    >platform.openai.com</a>
                  </p>
                </div>
                <!-- Model Selection -->
                <div class="mt-4">
                  <label class="block text-sm font-medium text-slate-700 mb-2">
                    Model
                  </label>
                  <form phx-change="update_model" phx-target={@myself}>
                    <input type="hidden" name="provider" value="openai" />
                    <input
                      type="text"
                      name="model"
                      value={@openai_model}
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
                      <p class="text-xs text-red-600 mt-2">
                        Make sure Ollama is running: <code class="bg-red-100 px-1 rounded">ollama serve</code>
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
                  <form phx-change="update_model" phx-target={@myself}>
                    <input type="hidden" name="provider" value="ollama" />
                    <select
                      name="model"
                      disabled={@ollama_status != :connected || length(@ollama_models) == 0}
                      class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-slate-100 disabled:text-slate-400"
                    >
                      <%= if length(@ollama_models) > 0 do %>
                        <%= for model <- @ollama_models do %>
                          <option value={model} selected={@ollama_model == model}>{model}</option>
                        <% end %>
                      <% else %>
                        <option value="">No models available</option>
                      <% end %>
                    </select>
                  </form>
                  <p class="mt-1 text-xs text-slate-500">
                    <%= if @ollama_status == :connected && length(@ollama_models) > 0 do %>
                      {length(@ollama_models)} model(s) available
                    <% else %>
                      Waiting for Ollama connection...
                    <% end %>
                  </p>
                </div>
              <% end %>
            </div>
            <!-- Wireframe Selection -->
            <div class="mb-6">
              <label class="block text-sm font-medium text-slate-700 mb-2">
                Starting Wireframe
              </label>
              <form phx-change="update_sample" phx-target={@myself}>
                <select
                  name="sample"
                  class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="blank" selected={@selected_sample == "blank"}>
                    Blank Page (Start from scratch)
                  </option>
                  <option value="login" selected={@selected_sample == "login"}>
                    Login Form Example
                  </option>
                  <option value="dashboard" selected={@selected_sample == "dashboard"}>
                    Dashboard Layout Example
                  </option>
                  <option value="upload" selected={@selected_sample == "upload"}>
                    Upload HTML File...
                  </option>
                </select>
              </form>
              <%= if @selected_sample == "upload" do %>
                <div class="mt-3 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                  <p class="text-sm text-blue-700">
                    File upload will be available in the next phase. For now, please select a sample or start with a blank page.
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
                phx-click="start_editor"
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
  def handle_event("update_config", %{"provider" => provider}, socket) do
    # If provider changed, update to saved model and check Ollama if needed
    socket =
      if provider != socket.assigns.provider do
        model = ConfigStore.get_model_for_provider(provider)

        socket
        |> assign(provider: provider, model: model)
        |> then(fn s ->
          if provider == "ollama" do
            check_ollama_connection(s)
          else
            s
          end
        end)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_model", %{"provider" => provider, "model" => model}, socket) do
    # Update the provider-specific model
    socket =
      case provider do
        "anthropic" -> assign(socket, anthropic_model: model, model: model)
        "openai" -> assign(socket, openai_model: model, model: model)
        "ollama" -> assign(socket, ollama_model: model, model: model)
        _ -> socket
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
  def handle_event("update_sample", %{"sample" => sample}, socket) do
    {:noreply, assign(socket, selected_sample: sample)}
  end

  @impl true
  def handle_event("start_editor", _params, socket) do
    # Save config (credentials and non-sensitive config)
    save_config(socket)

    # Send config_complete event to parent with selected configuration
    send(self(), {
      :config_complete,
      %{
        provider: socket.assigns.provider,
        model: socket.assigns.model,
        wireframe_sample: socket.assigns.selected_sample
      }
    })

    send(self(), {:close_modal})
    {:noreply, socket}
  end

  # Save current config to both ConfigStore and DemoCredentialStore
  defp save_config(socket) do
    provider = socket.assigns.provider

    # Save API keys to DemoCredentialStore (credentials.json)
    api_keys = %{
      "anthropic" => socket.assigns.anthropic_api_key,
      "openai" => socket.assigns.openai_api_key
    }

    DemoCredentialStore.update_api_keys(api_keys)

    # Save non-sensitive config to ConfigStore (.config.json)
    config = %{
      "provider" => provider,
      "anthropic_model" => socket.assigns.anthropic_model,
      "openai_model" => socket.assigns.openai_model,
      "ollama_model" => socket.assigns.ollama_model
    }

    ConfigStore.save_wireframe_config(config)

    # Also push to localStorage via ConfigStorage hook
    send(self(), {:save_config_to_localstorage, config})
  end

  # Helper functions for Ollama connection check
  defp check_ollama_connection(socket) do
    case OllamaClient.check_connection() do
      {:ok, :connected} ->
        # Connection successful, fetch available models
        case OllamaClient.list_models() do
          {:ok, [_ | _] = models} ->
            # Set saved model as default if in list, otherwise use first model
            default_model =
              if socket.assigns.ollama_model in models do
                socket.assigns.ollama_model
              else
                hd(models)
              end

            assign(socket,
              ollama_status: :connected,
              ollama_error: nil,
              ollama_models: models,
              ollama_model: default_model,
              model: default_model
            )

          {:ok, []} ->
            assign(socket,
              ollama_status: :connected,
              ollama_error: "No models found. Pull a model using: ollama pull qwen2.5:7b",
              ollama_models: []
            )

          {:error, reason} ->
            assign(socket,
              ollama_status: :error,
              ollama_error: reason,
              ollama_models: []
            )
        end

      {:error, reason} ->
        assign(socket,
          ollama_status: :error,
          ollama_error: reason,
          ollama_models: []
        )
    end
  end

  # Validation helper - check if user can start the editor
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
