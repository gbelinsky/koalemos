defmodule KoalemosWeb.ErrorDisplay do
  @moduledoc """
  Component for displaying user-friendly error messages.

  Shows formatted errors with:
  - Title and message
  - Actionable steps to resolve
  - Expandable technical details
  """
  use Phoenix.Component

  alias KoalemosWeb.ErrorHelper

  attr :error, :any, required: true, doc: "Error string or formatted error map"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def error_banner(assigns) do
    # Format the error if it's a string
    formatted_error =
      case assigns.error do
        nil -> nil
        error when is_binary(error) -> ErrorHelper.format_error(error)
        error when is_map(error) -> error
        error -> ErrorHelper.format_error(inspect(error))
      end

    assigns = assign(assigns, :formatted_error, formatted_error)

    ~H"""
    <%= if @formatted_error do %>
      <div class={[
        "rounded-lg border-2 p-6 mb-6 animate-in fade-in slide-in-from-top-4 duration-300",
        ErrorHelper.severity_classes(@formatted_error.severity),
        @class
      ]}>
        <!-- Header with Icon and Title -->
        <div class="flex items-start gap-4 mb-4">
          <div class={[
            "flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full",
            @formatted_error.severity == :error && "bg-red-100",
            @formatted_error.severity == :warning && "bg-yellow-100"
          ]}>
            <%= if @formatted_error.severity == :error do %>
              <svg
                class={["w-5 h-5", ErrorHelper.severity_icon_color(@formatted_error.severity)]}
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                  clip-rule="evenodd"
                />
              </svg>
            <% else %>
              <svg
                class={["w-5 h-5", ErrorHelper.severity_icon_color(@formatted_error.severity)]}
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                  clip-rule="evenodd"
                />
              </svg>
            <% end %>
          </div>
          <div class="flex-1">
            <h3 class="text-lg font-semibold mb-1"><%= @formatted_error.title %></h3>
            <p class="text-sm opacity-90"><%= @formatted_error.message %></p>
          </div>
        </div>
        <!-- Actions List -->
        <%= if @formatted_error.actions && length(@formatted_error.actions) > 0 do %>
          <div class="ml-12">
            <p class="text-sm font-medium mb-2">What to try:</p>
            <ul class="space-y-2">
              <%= for action <- @formatted_error.actions do %>
                <li class="flex items-start gap-2 text-sm">
                  <svg
                    class="w-4 h-4 mt-0.5 flex-shrink-0 opacity-70"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <span><%= action %></span>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
        <!-- Technical Details (Expandable) -->
        <%= if @formatted_error.technical_details do %>
          <details class="ml-12 mt-4">
            <summary class="text-xs font-medium cursor-pointer opacity-70 hover:opacity-100 transition-opacity">
              Show technical details
            </summary>
            <pre class="mt-2 text-xs bg-white bg-opacity-50 rounded p-3 overflow-x-auto"><code><%= @formatted_error.technical_details %></code></pre>
          </details>
        <% end %>
      </div>
    <% end %>
    """
  end
end
