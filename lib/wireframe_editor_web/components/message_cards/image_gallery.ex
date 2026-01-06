defmodule WireframeEditorWeb.MessageCards.ImageGallery do
  @moduledoc """
  Reusable image gallery component for displaying images in message cards.

  Supports two modes:
  - Collapsed: Shows small thumbnails
  - Expanded: Shows full-size images
  """
  use Phoenix.Component

  attr :images, :list, required: true, doc: "List of image items with source data"
  attr :card_id, :string, required: true, doc: "Unique ID for this card"
  attr :expanded, :boolean, default: false, doc: "Whether images are expanded"
  attr :on_expand, :string, default: "expand_image", doc: "Event name for expand action"
  attr :on_collapse, :string, default: "collapse_image", doc: "Event name for collapse action"
  attr :target, :any, default: nil, doc: "Event target (for LiveComponent)"

  def render(assigns) do
    ~H"""
    <%= if @expanded do %>
      <!-- Expanded state: full width images -->
      <div class="space-y-2">
        <%= for {image_item, idx} <- Enum.with_index(@images) do %>
          <% source = Map.get(image_item, :source) || Map.get(image_item, "source") %>
          <% data = Map.get(source, :data) || Map.get(source, "data") %>
          <% media_type = Map.get(source, :media_type) || Map.get(source, "media_type") || "image/png" %>
          <%= if data do %>
            <div class="w-full">
              <img
                src={"data:#{media_type};base64,#{data}"}
                class="w-full h-auto rounded-xl border-2 border-slate-200/60 shadow-md"
                alt={"Image #{idx + 1}"}
              />
            </div>
          <% end %>
        <% end %>
      </div>
    <% else %>
      <!-- Collapsed state: thumbnails -->
      <div class="flex items-center gap-2">
        <%= for {image_item, idx} <- Enum.with_index(@images) |> Enum.take(3) do %>
          <% source = Map.get(image_item, :source) || Map.get(image_item, "source") %>
          <% data = Map.get(source, :data) || Map.get(source, "data") %>
          <% media_type = Map.get(source, :media_type) || Map.get(source, "media_type") || "image/png" %>
          <%= if data do %>
            <img
              src={"data:#{media_type};base64,#{data}"}
              class="h-12 w-auto rounded-lg border-2 border-slate-300/50 cursor-pointer hover:opacity-80 hover:scale-105 transition-all duration-200 shadow-sm"
              phx-click={@on_expand}
              phx-value-card={@card_id}
              phx-target={@target}
              alt={"Thumbnail #{idx + 1}"}
            />
          <% end %>
        <% end %>
        <%= if length(@images) > 3 do %>
          <span class="text-gray-400 text-xs">+{length(@images) - 3} more</span>
        <% end %>
      </div>
    <% end %>
    """
  end
end
