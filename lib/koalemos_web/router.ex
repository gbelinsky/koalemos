defmodule KoalemosWeb.Router do
  use KoalemosWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KoalemosWeb.Layouts, :root}
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
    plug :put_root_layout, html: {KoalemosWeb.Layouts, :wireframe}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", KoalemosWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/example/login-form", ExampleGuideLive
    live "/wireframe-editor", WireframeEditorLive
    live "/chat/:routine_id", RoutineChatLive

    # Test pages
    live "/test", TestIndexLive
    live "/test/sample", SamplesLive
    live "/test/screenshot", ScreenshotTestLive
    live "/test/thinking", ThinkingTestLive
    live "/test/persona", PersonaTestLive
    live "/test/parsing", ParsingTestLive
    live "/test/wireframe", WireframeTestLive
    live "/test/lens-combinator", LensCombinatorLive
    # V4 test page (POC/debug)
    live "/wireframe-editor-v4/:routine_id", WireframeEditorV4Live
    # V4 production editor
    live "/wireframe-editor-v4-production", WireframeEditorV4ProductionLive

    # Wireframe preview (LiveView in iframe)
    live "/wireframe-preview/:routine_id", WireframePreviewLive
  end

  # V4 preview uses minimal wireframe layout (no Tailwind)
  scope "/", KoalemosWeb do
    pipe_through :wireframe

    live "/wireframe-preview-v4/:routine_id", WireframePreviewV4Live
  end

  # Other scopes may use custom stacks.
  # scope "/api", KoalemosWeb do
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

      live_dashboard "/dashboard", metrics: KoalemosWeb.Telemetry
    end
  end
end
