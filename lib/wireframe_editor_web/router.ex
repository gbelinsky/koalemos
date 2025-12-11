defmodule WireframeEditorWeb.Router do
  use WireframeEditorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WireframeEditorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Minimal pipeline for wireframe preview (no Tailwind, no root layout)
  pipeline :wireframe do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WireframeEditorWeb.Layouts, :wireframe}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", WireframeEditorWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/example/login-form", ExampleGuideLive
    live "/chat/:routine_id", RoutineChatLive

    # Test pages
    live "/test", TestIndexLive
    live "/test/sample", SamplesLive
    live "/test/screenshot", ScreenshotTestLive
    live "/test/thinking", ThinkingTestLive
    live "/test/persona", PersonaTestLive
    live "/test/parsing", ParsingTestLive
    live "/test/lens-combinator", LensCombinatorLive

    # Wireframe editor
    live "/wireframe-editor/:routine_id", WireframeEditorLive
    live "/wireframe-editor", WireframeEditorProductionLive
  end

  # Wireframe preview uses minimal layout (no Tailwind)
  scope "/", WireframeEditorWeb do
    pipe_through :wireframe

    live "/wireframe-preview/:routine_id", WireframePreviewLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", WireframeEditorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:koalemos, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WireframeEditorWeb.Telemetry
    end
  end
end
