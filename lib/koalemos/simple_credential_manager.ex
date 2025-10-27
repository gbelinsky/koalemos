defmodule Koalemos.SimpleCredentialManager do
  @moduledoc """
  Simple OAuth credential manager for Anthropic API.

  Handles automatic token refresh with race condition protection.
  Multiple routines can safely request tokens simultaneously.
  """

  use GenServer
  require Logger

  @client_id "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
  @oauth_url "https://console.anthropic.com/v1/oauth/token"
  @refresh_buffer_ms 5 * 60 * 1000  # Refresh 5 minutes before expiry

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Load credentials from file.
  """
  def load_credentials_from_file(file_path) do
    GenServer.call(__MODULE__, {:load_from_file, file_path})
  end

  @doc """
  Get a valid access token. Automatically refreshes if needed.
  Multiple simultaneous calls are safe - only one refresh happens.
  """
  def get_access_token() do
    GenServer.call(__MODULE__, :get_access_token, 30_000)
  end

  ## GenServer Implementation

  @impl true
  def init(_opts) do
    state = %{
      credentials: nil,
      file_path: nil,
      refreshing: false,        # Prevent multiple simultaneous refreshes
      waiting_callers: []       # Queue callers during refresh
    }

    # Auto-load credentials if file path is configured
    case get_credentials_file_path() do
      nil ->
        Logger.warning("No credentials file configured. Use KOALEMOS_CREDENTIALS_PATH env var or config :koalemos, :credentials_file")
        {:ok, state}

      file_path ->
        case load_oauth_file(file_path) do
          {:ok, credentials} ->
            Logger.info("Auto-loaded OAuth credentials from #{file_path}")
            {:ok, %{state | credentials: credentials, file_path: file_path}}

          {:error, reason} ->
            Logger.error("Failed to auto-load credentials from #{file_path}: #{reason}")
            {:ok, state}
        end
    end
  end

  @impl true
  def handle_call({:load_from_file, file_path}, _from, state) do
    case load_oauth_file(file_path) do
      {:ok, credentials} ->
        new_state = %{state |
          credentials: credentials,
          file_path: file_path
        }

        Logger.info("Loaded OAuth credentials from #{file_path}")
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Failed to load credentials from #{file_path}: #{reason}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_access_token, from, state) do
    case state.credentials do
      nil ->
        {:reply, {:error, :no_credentials}, state}

      creds ->
        if token_needs_refresh?(creds) do
          if state.refreshing do
            # Another refresh is in progress, queue this caller
            new_waiting = [from | state.waiting_callers]
            {:noreply, %{state | waiting_callers: new_waiting}}
          else
            # Start refresh process
            send(self(), :do_refresh)
            new_waiting = [from | state.waiting_callers]
            {:noreply, %{state | refreshing: true, waiting_callers: new_waiting}}
          end
        else
          # Token is still valid
          {:reply, {:ok, creds.access_token}, state}
        end
    end
  end

  @impl true
  def handle_info(:do_refresh, state) do
    case refresh_token(state.credentials) do
      {:ok, new_credentials} ->
        # Save to file
        case save_credentials_to_file(new_credentials, state.file_path) do
          :ok ->
            # Reply to all waiting callers with the new token
            Enum.each(state.waiting_callers, fn caller ->
              GenServer.reply(caller, {:ok, new_credentials.access_token})
            end)

            new_state = %{state |
              credentials: new_credentials,
              refreshing: false,
              waiting_callers: []
            }

            Logger.info("Successfully refreshed and saved OAuth token")
            {:noreply, new_state}

          {:error, reason} ->
            Logger.error("Failed to save refreshed credentials: #{reason}")
            # Still reply with the token even if save failed
            Enum.each(state.waiting_callers, fn caller ->
              GenServer.reply(caller, {:ok, new_credentials.access_token})
            end)

            new_state = %{state |
              credentials: new_credentials,
              refreshing: false,
              waiting_callers: []
            }

            {:noreply, new_state}
        end

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{reason}")

        # Reply to all waiting callers with error
        Enum.each(state.waiting_callers, fn caller ->
          GenServer.reply(caller, {:error, reason})
        end)

        new_state = %{state |
          refreshing: false,
          waiting_callers: []
        }

        {:noreply, new_state}
    end
  end

  ## Private Functions

  defp get_credentials_file_path() do
    System.get_env("KOALEMOS_CREDENTIALS_PATH") ||
    Application.get_env(:koalemos, :credentials_file) ||
    ".koalemos/.credentials.json"
  end

  defp load_oauth_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, data} <- Jason.decode(content),
         %{"claudeAiOauth" => oauth_data} <- data do

      credentials = %{
        access_token: oauth_data["accessToken"],
        refresh_token: oauth_data["refreshToken"],
        expires_at: oauth_data["expiresAt"],
        scopes: oauth_data["scopes"] || [],
        subscription_type: oauth_data["subscriptionType"]
      }

      {:ok, credentials}
    else
      {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
      error -> {:error, "Invalid credentials format: #{inspect(error)}"}
    end
  end

  defp token_needs_refresh?(credentials) do
    current_time_ms = System.system_time(:millisecond)
    expires_at = credentials.expires_at

    current_time_ms >= (expires_at - @refresh_buffer_ms)
  end

  defp refresh_token(credentials) do
    body = Jason.encode!(%{
      "grant_type" => "refresh_token",
      "refresh_token" => credentials.refresh_token,
      "client_id" => @client_id
    })

    headers = [
      {"Content-Type", "application/json"}
    ]

    case Req.post(@oauth_url,
      headers: headers,
      body: body,
      receive_timeout: 30_000
    ) do
      {:ok, %{status: 200, body: data}} ->
        # Calculate expires_at from expires_in (like the JS version)
        expires_at = System.system_time(:millisecond) + (data["expires_in"] * 1000)

        new_credentials = %{credentials |
          access_token: data["access_token"],
          refresh_token: data["refresh_token"],
          expires_at: expires_at,
          scopes: String.split(data["scope"] || "", " ", trim: true)
        }

        {:ok, new_credentials}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp save_credentials_to_file(credentials, file_path) do
    # Read existing file to preserve providers section (if present)
    existing_data = case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          _ -> %{}
        end
      _ -> %{}
    end

    # Recreate the OAuth section
    oauth_data = %{
      "accessToken" => credentials.access_token,
      "refreshToken" => credentials.refresh_token,
      "expiresAt" => credentials.expires_at,
      "scopes" => credentials.scopes,
      "subscriptionType" => credentials.subscription_type
    }

    # Merge with existing data to preserve providers section
    file_content = Map.merge(existing_data, %{
      "claudeAiOauth" => oauth_data
    })

    case Jason.encode(file_content) do
      {:ok, json_string} ->
        File.write(file_path, json_string)

      {:error, reason} ->
        {:error, "JSON encode error: #{reason}"}
    end
  end
end
