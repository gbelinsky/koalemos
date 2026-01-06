defmodule WireframeEditorWeb.MessageCards.ErrorCard do
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
      class="bg-gradient-to-br from-red-50/80 to-orange-50/40 p-4 border-l-[5px] border-b-[3px] border-r border-red-400/70 rounded-2xl shadow-[2px_3px_10px_-2px_rgba(239,68,68,0.2)]"
      id={@card_id}
      role="alert"
    >
      <!-- Header with error icon -->
      <div class="flex items-center gap-2 mb-2">
        <span class="text-red-500/80 text-base" aria-hidden="true">⚠</span>
        <div class="text-[0.65rem] font-medium text-red-600/80 tracking-wider">
          well, that's unfortunate
        </div>
      </div>
      <!-- Error message -->
      <div class="text-red-900/80 text-[0.9rem] leading-relaxed">
        {@error_message}
      </div>
    </div>
    """
  end
end
