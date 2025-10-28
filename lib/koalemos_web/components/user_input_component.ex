defmodule KoalemosWeb.UserInputComponent do
  @moduledoc """
  A reusable LiveView component that provides a combined text and image input interface.

  ## Features
  - Text input with Enter key support (without Shift)
  - Image upload with drag-and-drop support
  - Automatic image processing and thumbnail display
  - Individual image removal and "clear all" functionality
  - Sends a single consolidated message to parent when submitted

  ## Usage

  In your LiveView template:
  ```heex
  <.live_component
    module={KoalemosWeb.UserInputComponent}
    id="user-input"
    placeholder="Your custom placeholder..."
    current_input={@initial_text}  # optional
  />
  ```

  ## Required Parent Setup

  **IMPORTANT**: Due to technical limitations with LiveView upload event handling,
  the parent LiveView must include this awkward but necessary message handler:

  ```elixir
  @impl true
  def handle_info(:check_uploads, socket) do
    # Forward this to the UserInputComponent
    send_update(KoalemosWeb.UserInputComponent, id: "user-input", check_uploads: true)
    {:noreply, socket}
  end
  ```

  The parent must also handle the component's output message:

  ```elixir
  @impl true
  def handle_info({:user_input_submitted, %{text: text, images: images}}, socket) do
    # Process the input and images
    # text: string
    # images: list of %{base64: string, media_type: string, filename: string, size: integer}
    {:noreply, socket}
  end
  ```

  ## Tech Debt

  This component uses polling to detect upload completion instead of proper LiveView
  upload event handling. This is due to challenges with auto-upload event propagation
  in LiveView components. The polling approach works reliably but should be replaced
  with proper event handling in the future.

  ## Image Format

  Images are automatically processed into this format:
  ```elixir
  %{
    base64: "iVBORw0KGgoAAAANSUhEUgAA...",  # Base64 encoded image data
    media_type: "image/jpeg",                # MIME type
    filename: "my-image.jpg",                # Original filename
    size: 1234567                           # File size in bytes
  }
  ```

  This format is compatible with Anthropic's Claude API content format.
  """
  use Phoenix.LiveComponent
  import Phoenix.LiveView.JS, only: [dispatch: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="user-input-component">
      <.form for={%{}} phx-change="validate_images" phx-target={@myself}>
        <div class="flex flex-col space-y-3">
          <!-- Hidden file input for image upload -->
          <.live_file_input upload={@uploads.image_files} class="hidden" phx-target={@myself} />

          <!-- Upload Progress Indicator -->
          <%= if has_uploads_in_progress?(@uploads.image_files) do %>
            <div class="p-3 bg-gradient-to-br from-blue-50/80 to-indigo-50/40 rounded-2xl border-l-[3px] border-b border-r-2 border-blue-400/70 shadow-[2px_2px_8px_-2px_rgba(59,130,246,0.2)]">
              <div class="flex items-center justify-between mb-2">
                <span class="text-[0.65rem] font-medium text-blue-700/80 tracking-wide">uploading images...</span>
                <span class="text-xs text-blue-600/70"><%= count_in_progress(@uploads.image_files) %> remaining</span>
              </div>
              <%= for entry <- @uploads.image_files.entries do %>
                <%= if !entry.done? do %>
                  <div class="mb-2 last:mb-0">
                    <div class="flex items-center justify-between text-xs text-blue-600/80 mb-1">
                      <span class="truncate max-w-[200px]"><%= entry.client_name %></span>
                      <span><%= entry.progress %>%</span>
                    </div>
                    <div class="w-full bg-blue-200/60 rounded-full h-1.5">
                      <div
                        class="bg-blue-600/90 h-1.5 rounded-full transition-all duration-300"
                        style={"width: #{entry.progress}%"}
                      ></div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>

          <!-- Show uploaded images with thumbnails (or placeholder during upload) -->
          <%= if length(@uploaded_images) > 0 || has_uploads_in_progress?(@uploads.image_files) do %>
            <div class="p-4 bg-gradient-to-br from-slate-50 to-gray-50/30 rounded-2xl border-l-[2px] border-r border-t border-slate-300/50 shadow-[1px_2px_8px_-2px_rgba(148,163,184,0.15)] min-h-[120px]">
              <%= if length(@uploaded_images) > 0 do %>
                <div class="flex items-center justify-between mb-3">
                  <h4 class="text-[0.65rem] font-medium text-slate-700/80 tracking-wide">
                    <%= length(@uploaded_images) %> image(s) selected
                  </h4>
                  <button
                    type="button"
                    phx-click="clear_all_images"
                    phx-target={@myself}
                    class="text-xs text-red-600/80 hover:text-red-800 hover:scale-105 transition-all duration-200"
                  >
                    clear all
                  </button>
                </div>
                <div class="flex flex-wrap gap-3">
                  <%= for {image, index} <- Enum.with_index(@uploaded_images) do %>
                    <div class="relative group">
                      <div class="w-20 h-20 bg-white rounded-xl border-2 border-slate-200/60 overflow-hidden shadow-sm hover:shadow-md hover:scale-105 transition-all duration-200">
                        <img
                          src={"data:#{image.media_type};base64,#{image.base64}"}
                          class="w-full h-full object-cover"
                          alt={image.filename}
                        />
                      </div>
                      <button
                        type="button"
                        phx-click="remove_image"
                        phx-value-index={index}
                        phx-target={@myself}
                        class="absolute -top-2 -right-2 w-6 h-6 bg-red-500/90 text-white rounded-full text-xs hover:bg-red-600 hover:scale-110 opacity-0 group-hover:opacity-100 transition-all duration-200 flex items-center justify-center shadow-md"
                      >
                        ×
                      </button>
                      <div class="absolute bottom-0 left-0 right-0 bg-black/75 text-white text-xs p-1 truncate opacity-0 group-hover:opacity-100 transition-opacity rounded-b-xl">
                        <%= image.filename %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <!-- Placeholder while uploading -->
                <div class="flex items-center justify-center h-20">
                  <span class="text-slate-400 text-sm">processing images...</span>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Text Input -->
          <div class="flex-1">
            <textarea
              name="user_input"
              placeholder={@placeholder || "type your message..."}
              rows="3"
              class="w-full p-3 border-2 border-slate-300/60 rounded-2xl resize-none focus:ring-2 focus:ring-blue-500/40 focus:border-blue-400/70 transition-all duration-200 shadow-[1px_2px_6px_-2px_rgba(148,163,184,0.2)]"
              phx-keydown="handle_keydown"
              phx-key="Enter"
              phx-target={@myself}
            ><%= @current_input %></textarea>
          </div>

          <!-- Action Buttons -->
          <div class="flex items-center space-x-3">
            <!-- Add Images Button -->
            <button
              type="button"
              phx-click={dispatch("click", to: "##{@uploads.image_files.ref}")}
              class="flex items-center space-x-2 px-3 py-2 text-sm text-slate-600/80 hover:text-slate-800 hover:scale-105 transition-all duration-200 bg-gradient-to-br from-slate-50 to-gray-50/30 rounded-xl border-l-[2px] border-r border-t border-slate-300/50 shadow-[1px_1px_4px_-1px_rgba(148,163,184,0.2)] hover:shadow-md"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"></path>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"></path>
              </svg>
              <span class="text-[0.65rem] tracking-wide">add images</span>
            </button>

            <!-- Send Button -->
            <button
              type="button"
              phx-click="send_input"
              phx-target={@myself}
              class="px-4 py-2 bg-gradient-to-br from-blue-500 to-indigo-600 text-white rounded-xl hover:from-blue-600 hover:to-indigo-700 hover:scale-105 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 shadow-[2px_2px_8px_-2px_rgba(59,130,246,0.3)] hover:shadow-[3px_3px_12px_-2px_rgba(59,130,246,0.4)] border-r-[3px] border-b-[2px] border-t border-blue-400/30 text-sm tracking-wide"
              disabled={@current_input == "" and length(@uploaded_images) == 0}
            >
              send
            </button>

            <!-- Sent Feedback -->
            <%= if @just_sent do %>
              <div class="flex items-center text-green-600/80 text-sm animate-fade-in">
                <svg class="w-5 h-5 mr-1" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
                <span class="text-[0.65rem] tracking-wide">sent</span>
              </div>
            <% end %>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:current_input, "")
      |> assign(:uploaded_images, [])
      |> assign(:just_sent, false)
      |> allow_upload(:image_files,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 5,
        max_file_size: 3_750_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # If this update includes check_uploads, process any completed uploads
    socket =
      if Map.get(assigns, :check_uploads) do
        processed_socket = auto_process_new_images(socket)

        # If there are still uploads in progress, schedule another check
        entries = processed_socket.assigns.uploads.image_files.entries
        in_progress = Enum.filter(entries, &(!&1.done?))

        if length(in_progress) > 0 do
          Process.send_after(self(), :check_uploads, 500)
        end

        processed_socket
      else
        socket
      end

    # If this update includes clear_sent_feedback, clear the flag
    socket =
      if Map.get(assigns, :clear_sent_feedback) do
        assign(socket, :just_sent, false)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_images", %{"_target" => ["image_files"]} = params, socket) do
    # This event is triggered when files are selected
    # Update text input if it's in the params
    socket =
      if Map.has_key?(params, "user_input") do
        assign(socket, :current_input, params["user_input"])
      else
        socket
      end

    # TECH DEBT: Using polling to check upload completion instead of proper event handling
    # TODO: Replace with proper LiveView upload event handling (progress, auto-upload events)
    Process.send_after(self(), :check_uploads, 500)

    {:noreply, socket}
  end

  def handle_event("validate_images", %{"user_input" => input} = _params, socket) do
    # This event is triggered when text input changes
    socket = assign(socket, :current_input, input)
    {:noreply, socket}
  end

  def handle_event("validate_images", _params, socket) do
    # Fallback handler for other validate_images events
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image_files, ref)}
  end

  def handle_event("clear_all_images", _params, socket) do
    {:noreply, assign(socket, :uploaded_images, [])}
  end

  def handle_event("remove_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    updated_images = List.delete_at(socket.assigns.uploaded_images, index)
    {:noreply, assign(socket, :uploaded_images, updated_images)}
  end

  def handle_event("auto-upload", params, socket) do
    # This gets triggered when auto-upload completes
    require Logger
    Logger.debug("auto-upload event triggered, params: #{inspect(params)}")
    Logger.debug("Upload entries: #{length(socket.assigns.uploads.image_files.entries)}")
    socket = auto_process_new_images(socket)
    {:noreply, socket}
  end

  def handle_event("progress", params, socket) do
    require Logger
    Logger.debug("progress event triggered, params: #{inspect(params)}")
    Logger.debug("Upload entries: #{length(socket.assigns.uploads.image_files.entries)}")

    # Check if any uploads are done and process them
    socket = auto_process_new_images(socket)
    {:noreply, socket}
  end

  def handle_event("handle_keydown", %{"key" => "Enter", "shiftKey" => false}, socket) do
    send_input_event(socket)
  end

  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("send_input", _params, socket) do
    send_input_event(socket)
  end

  # Update text input
  def handle_event("update_input", %{"user_input" => input}, socket) do
    {:noreply, assign(socket, :current_input, input)}
  end

  defp send_input_event(socket) do
    text = socket.assigns.current_input
    images = socket.assigns.uploaded_images

    if text != "" or length(images) > 0 do
      # Send the input data to the parent LiveView
      send(self(), {:user_input_submitted, %{text: text, images: images}})

      # Schedule clearing the feedback
      Process.send_after(self(), {:clear_sent_feedback, socket.assigns.id}, 2000)

      # Reset the component state and show feedback
      socket =
        socket
        |> assign(:current_input, "")
        |> assign(:uploaded_images, [])
        |> assign(:just_sent, true)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp auto_process_new_images(socket) do
    # Check if there are any entries to process
    entries = socket.assigns.uploads.image_files.entries
    completed_entries = Enum.filter(entries, & &1.done?)
    in_progress_entries = Enum.filter(entries, &(!&1.done?))

    # Only process if ALL entries are done (no entries in progress)
    if length(completed_entries) > 0 and length(in_progress_entries) == 0 do
      try do
        uploaded_images =
          consume_uploaded_entries(socket, :image_files, fn %{path: path}, entry ->
            case File.read(path) do
              {:ok, binary} ->
                base64_data = Base.encode64(binary)
                media_type = get_image_media_type(entry.client_type || "image/jpeg")

                {:ok,
                 %{
                   base64: base64_data,
                   media_type: media_type,
                   filename: entry.client_name,
                   size: entry.client_size
                 }}

              {:error, _reason} ->
                {:ok, nil}
            end
          end)
          |> Enum.filter(&is_map/1)

        new_images = socket.assigns.uploaded_images ++ uploaded_images

        assign(socket, :uploaded_images, new_images)
      rescue
        _e ->
          socket
      end
    else
      socket
    end
  end

  # Made public for testing
  def get_image_media_type("image/" <> _ = media_type), do: media_type
  def get_image_media_type(_), do: "image/jpeg"

  defp has_uploads_in_progress?(upload) do
    Enum.any?(upload.entries, fn entry -> !entry.done? end)
  end

  defp count_in_progress(upload) do
    Enum.count(upload.entries, fn entry -> !entry.done? end)
  end
end
