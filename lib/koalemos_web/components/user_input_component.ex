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

  The parent LiveView must handle the component's output message:

  ```elixir
  @impl true
  def handle_info({:user_input_submitted, %{text: text, images: images, include_screenshot: include_screenshot}}, socket) do
    # Process the input, images, and screenshot flag
    # text: string
    # images: list of %{base64: string, media_type: string, filename: string, size: integer}
    # include_screenshot: boolean
    {:noreply, socket}
  end
  ```

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
          
    <!-- Images Drawer: Always visible -->
          <div class="rounded-2xl border-l-[2px] border-r border-t border-slate-300/50 shadow-[1px_2px_8px_-2px_rgba(148,163,184,0.15)] overflow-hidden">
            <!-- Clickable Drawer Header -->
            <button
              type="button"
              phx-click="toggle_images_drawer"
              phx-target={@myself}
              class="w-full px-3 py-2 bg-gradient-to-br from-slate-100 to-gray-100/40 hover:from-slate-200 hover:to-gray-200/40 transition-colors flex items-center justify-between group"
            >
              <h4 class="text-[0.65rem] font-medium text-slate-700/80 tracking-wide flex items-center gap-1">
                <%= if has_uploads_in_progress?(@uploads.image_files) do %>
                  <svg
                    class="w-3 h-3 animate-spin text-blue-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                    />
                  </svg>
                  <span class="text-blue-700/80">
                    uploading {count_in_progress(@uploads.image_files)}...
                  </span>
                <% else %>
                  <svg
                    class="w-3 h-3 text-slate-500"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                    />
                  </svg>
                  <%= if length(@uploaded_images) > 0 do %>
                    <span class="text-slate-600/80">
                      images <span class="text-green-700/80">({length(@uploaded_images)} ready)</span>
                    </span>
                  <% else %>
                    <span class="text-slate-600/80">images</span>
                  <% end %>
                <% end %>
              </h4>
              <!-- Toggle indicator -->
              <svg
                class={"w-4 h-4 text-slate-500 transition-transform duration-200 #{if @images_drawer_open, do: "rotate-180", else: ""}"}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                >
                </path>
              </svg>
            </button>
            
    <!-- Collapsible Images Content -->
            <%= if @images_drawer_open do %>
              <div class="p-3 bg-gradient-to-br from-slate-50 to-gray-50/30">
                <!-- Thumbnails Grid: Add button + Completed images + Upload placeholders + Clear all -->
                <div class="flex flex-wrap gap-3">
                  <!-- Add More Images Button -->
                  <button
                    type="button"
                    phx-click={
                      if @disabled,
                        do: nil,
                        else: dispatch("click", to: "##{@uploads.image_files.ref}")
                    }
                    disabled={@disabled}
                    class={"w-20 h-20 bg-gradient-to-br from-slate-50 to-gray-50/30 rounded-xl border-2 border-dashed border-slate-300/60 flex flex-col items-center justify-center hover:border-slate-400 hover:bg-slate-100/50 transition-all duration-200 #{if @disabled, do: "opacity-50 cursor-not-allowed", else: ""}"}
                  >
                    <svg
                      class="w-6 h-6 text-slate-400"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 4v16m8-8H4"
                      >
                      </path>
                    </svg>
                    <span class="text-xs text-slate-500 mt-1">add</span>
                  </button>
                  <!-- Completed Images -->
                  <%= for {image, index} <- Enum.with_index(@uploaded_images) do %>
                    <div class="relative group">
                      <div class="w-20 h-20 bg-white rounded-xl border-2 border-green-200/60 overflow-hidden shadow-sm hover:shadow-md hover:scale-105 transition-transform duration-200">
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
                        disabled={@disabled}
                        class={"absolute -top-2 -right-2 w-6 h-6 bg-red-500/90 text-white rounded-full text-xs hover:bg-red-600 hover:scale-110 opacity-0 group-hover:opacity-100 transition-all duration-200 flex items-center justify-center shadow-md #{if @disabled, do: "cursor-not-allowed", else: ""}"}
                      >
                        ×
                      </button>
                      <div class="absolute bottom-0 left-0 right-0 bg-black/75 text-white text-xs p-1 truncate opacity-0 group-hover:opacity-100 transition-opacity rounded-b-xl">
                        {image.filename}
                      </div>
                    </div>
                  <% end %>
                  <!-- Upload Placeholders (uploading or processing) -->
                  <%= for entry <- @uploads.image_files.entries do %>
                    <div class="relative w-20 h-20">
                      <%= if entry.done? do %>
                        <!-- Processing placeholder (done uploading, waiting for consumption) -->
                        <div class="w-full h-full bg-green-50 rounded-xl border-2 border-green-200/60 overflow-hidden shadow-sm flex flex-col items-center justify-center p-2">
                          <svg
                            class="w-6 h-6 text-green-500 animate-pulse"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          <span class="text-xs text-green-600 font-medium">done</span>
                        </div>
                      <% else %>
                        <!-- Uploading placeholder -->
                        <div class="w-full h-full bg-blue-50 rounded-xl border-2 border-blue-200/60 overflow-hidden shadow-sm flex flex-col items-center justify-center p-2">
                          <svg
                            class="w-6 h-6 text-blue-400 mb-1"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                            />
                          </svg>
                          <span class="text-xs text-blue-600 font-medium">{entry.progress}%</span>
                        </div>
                        <!-- Progress bar at bottom -->
                        <div class="absolute bottom-1 left-1 right-1 h-1 bg-blue-200/60 rounded-full overflow-hidden">
                          <div
                            class="h-full bg-blue-600 transition-all duration-300"
                            style={"width: #{entry.progress}%"}
                          >
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                  <!-- Clear All Button (as last item in grid when images exist) -->
                  <%= if length(@uploaded_images) > 0 do %>
                    <button
                      type="button"
                      phx-click="clear_all_images"
                      phx-target={@myself}
                      disabled={@disabled}
                      class={"w-20 h-20 bg-red-50 rounded-xl border-2 border-dashed border-red-300/60 flex flex-col items-center justify-center hover:border-red-400 hover:bg-red-100/50 transition-all duration-200 #{if @disabled, do: "opacity-50 cursor-not-allowed", else: ""}"}
                    >
                      <svg
                        class="w-6 h-6 text-red-500"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                        >
                        </path>
                      </svg>
                      <span class="text-xs text-red-600 mt-1">clear all</span>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Text Input with send controls -->
          <div class="flex items-end gap-2 relative">
            <!-- Text Input -->
            <div class="flex-1">
              <textarea
                id={"#{@id}-textarea"}
                name="user_input"
                placeholder={@placeholder || "type your message..."}
                rows="3"
                class={"w-full p-3 border-2 border-slate-300/60 rounded-2xl resize-none focus:ring-2 focus:ring-blue-500/40 focus:border-blue-400/70 transition-all duration-200 shadow-[1px_2px_6px_-2px_rgba(148,163,184,0.2)] #{if @disabled, do: "bg-slate-100 text-slate-500 cursor-not-allowed", else: ""}"}
                phx-change="update_input"
                phx-target={@myself}
                phx-hook="AutoFocus"
                disabled={@disabled}
              ><%= @current_input %></textarea>
            </div>
            
    <!-- Right side: Preview screenshot (optional) or Screenshot checkbox and Send button stacked -->
            <div class="flex flex-col gap-2">
              <!-- Screenshot Preview (conditional) -->
              <%= if assigns[:screenshot_data] do %>
                <div class="flex justify-end">
                  <img
                    src={"data:image/png;base64,#{@screenshot_data}"}
                    alt="Preview screenshot"
                    class="w-32 max-h-24 object-contain rounded-lg border-2 border-slate-300 shadow-sm"
                  />
                </div>
              <% end %>

              <!-- Screenshot Checkbox (conditional, only when no preview screenshot) -->
              <%= if @show_screenshot_checkbox && !assigns[:screenshot_data] do %>
                <div class="flex justify-end">
                  <label class={"flex items-center gap-2 px-3 py-1.5 bg-slate-50 rounded-lg border border-slate-200 hover:bg-slate-100 transition-colors #{if @disabled, do: "opacity-50 cursor-not-allowed", else: "cursor-pointer"}"}>
                    <input
                      type="checkbox"
                      checked={@include_screenshot}
                      phx-click="toggle_screenshot"
                      phx-target={@myself}
                      disabled={@disabled}
                      class="w-4 h-4 text-blue-600 border-slate-300 rounded focus:ring-blue-500 focus:ring-2"
                    />
                    <span class="text-xs text-slate-600 flex items-center gap-1">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                        />
                      </svg>
                      screenshot
                    </span>
                  </label>
                </div>
              <% end %>
              
    <!-- Send Button -->
              <div class="flex items-center relative">
                <button
                  type="button"
                  id={"#{@id}-send-button"}
                  phx-click="send_input"
                  phx-target={@myself}
                  class="px-4 py-2 bg-gradient-to-br from-blue-500 to-indigo-600 text-white rounded-xl hover:from-blue-600 hover:to-indigo-700 hover:scale-105 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 shadow-[2px_2px_8px_-2px_rgba(59,130,246,0.3)] hover:shadow-[3px_3px_12px_-2px_rgba(59,130,246,0.4)] border-r-[3px] border-b-[2px] border-t border-blue-400/30 text-sm tracking-wide"
                  disabled={
                    @disabled or
                      (@current_input == "" and length(@uploaded_images) == 0 and
                         not @include_screenshot)
                  }
                  title="Send message"
                >
                  send
                </button>
                <!-- Sent Feedback (absolute positioned over button area) -->
                <%= if @just_sent do %>
                  <div class="absolute inset-0 flex items-center justify-center bg-green-500 rounded-xl pointer-events-none">
                    <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path
                        fill-rule="evenodd"
                        d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                <% end %>
              </div>
            </div>
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
      |> assign(:images_drawer_open, false)
      |> assign(:include_screenshot, false)
      |> assign(:show_screenshot_checkbox, false)
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
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:disabled, fn -> false end)

    # If this update includes check_uploads, process any completed uploads
    socket =
      if Map.get(assigns, :check_uploads) do
        processed_socket = auto_process_new_images(socket)

        # If there are still uploads in progress, schedule another check
        entries = processed_socket.assigns.uploads.image_files.entries
        in_progress = Enum.filter(entries, &(!&1.done?))

        if length(in_progress) > 0 do
          send_update_after(__MODULE__, [id: socket.assigns.id, check_uploads: true], 500)
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

    # Open the drawer when files are selected
    socket = assign(socket, :images_drawer_open, true)

    # Schedule self-update to check upload completion
    send_update_after(__MODULE__, [id: socket.assigns.id, check_uploads: true], 500)

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

  def handle_event("toggle_images_drawer", _params, socket) do
    {:noreply, assign(socket, :images_drawer_open, !socket.assigns.images_drawer_open)}
  end

  def handle_event("toggle_screenshot", _params, socket) do
    {:noreply, assign(socket, :include_screenshot, !socket.assigns.include_screenshot)}
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
    include_screenshot = socket.assigns.include_screenshot

    if text != "" or length(images) > 0 or include_screenshot do
      # Send the input data to the parent LiveView
      send(
        self(),
        {:user_input_submitted,
         %{text: text, images: images, include_screenshot: include_screenshot}}
      )

      # Schedule clearing the feedback
      Process.send_after(self(), {:clear_sent_feedback, socket.assigns.id}, 2000)

      # Reset the component state and show feedback
      socket =
        socket
        |> assign(:current_input, "")
        |> assign(:uploaded_images, [])
        |> assign(:include_screenshot, false)
        |> assign(:just_sent, true)
        |> push_event("clear-input", %{id: "#{socket.assigns.id}-textarea"})

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
      require Logger
      Logger.debug("Processing #{length(completed_entries)} completed uploads")

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

              {:error, reason} ->
                Logger.error("Failed to read uploaded file: #{inspect(reason)}")
                {:ok, nil}
            end
          end)
          |> Enum.filter(&is_map/1)

        new_images = socket.assigns.uploaded_images ++ uploaded_images
        Logger.debug("Added #{length(uploaded_images)} images. Total: #{length(new_images)}")

        assign(socket, :uploaded_images, new_images)
      rescue
        e ->
          Logger.error("Error processing uploads: #{inspect(e)}")
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
