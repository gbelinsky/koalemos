defmodule KoalemosWeb.MessageCards.ErrorCard do
  @moduledoc """
  Displays an error message card.

  Features:
  - Error message with red styling
  - Warning icon
  - Clear visual indication of error state
  """
  use Phoenix.Component
  import Phoenix.Component

  attr :error_message, :string, required: true, doc: "Error message to display"
  attr :card_id, :string, default: nil, doc: "Optional card ID"

  def render(assigns) do
    # Generate card ID if not provided or nil
    card_id = assigns[:card_id] || "error_#{:erlang.phash2(assigns.error_message)}"
    assigns = assign(assigns, :card_id, card_id)

    ~H"""
    <div
      class="bg-red-50 p-3 border-l-4 border-l-red-500 rounded-md shadow-sm"
      id={@card_id}
      role="alert"
    >
      <!-- Header with error icon -->
      <div class="flex items-center gap-2 mb-2">
        <span class="text-red-600 text-lg" aria-hidden="true">⚠️</span>
        <div class="text-xs font-semibold text-red-700 uppercase tracking-wide">
          ERROR
        </div>
      </div>
      <!-- Error message -->
      <div class="text-red-800 text-sm leading-relaxed">
        <%= @error_message %>
      </div>
    </div>
    """
  end
end
