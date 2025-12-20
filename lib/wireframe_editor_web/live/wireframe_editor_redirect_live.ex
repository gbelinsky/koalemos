defmodule WireframeEditorWeb.WireframeEditorRedirectLive do
  @moduledoc """
  Redirect-only LiveView for /wireframe-editor.

  Generates a unique routine_id and redirects to /wireframe-editor/:routine_id.
  This ensures page reloads don't create new sessions.
  """
  use WireframeEditorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    routine_id = "wireframe-#{:erlang.unique_integer([:positive])}"
    {:ok, push_navigate(socket, to: "/wireframe-editor/#{routine_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-screen">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
    </div>
    """
  end
end
