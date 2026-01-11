defmodule KoalemosInspectorWeb.Router do
  use KoalemosInspectorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KoalemosInspectorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", KoalemosInspectorWeb do
    pipe_through :browser

    live "/", InspectorLive
  end
end
