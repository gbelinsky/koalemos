defmodule WireframeEditorWeb.StartSessionModalTest do
  use WireframeEditorWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias WireframeEditorWeb.StartSessionModal

  setup do
    # Credential manager already running globally from application.ex
    :ok
  end

  describe "rendering" do
    test "renders modal when show is true", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true
        )

      assert html =~ "start new chat"
      assert html =~ "AI Provider"
    end

    test "does not render modal when show is false", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: false
        )

      refute html =~ "start new chat"
    end

    test "renders provider selection", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true
        )

      assert html =~ "Anthropic"
      assert html =~ "OpenAI"
      assert html =~ "Ollama"
    end

    test "renders Anthropic API key input when provider is anthropic", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "anthropic"
        )

      assert html =~ "API Key"
      assert html =~ "sk-ant-"
    end

    test "renders OpenAI API key input when provider is openai", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "openai"
        )

      assert html =~ "API Key"
      assert html =~ ~s(placeholder="sk-...)
    end

    test "renders Ollama connection status when provider is ollama", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "ollama"
        )

      # Should have model selection
      assert html =~ "Model"
    end
  end

  describe "start button validation" do
    test "start button disabled for anthropic without credentials", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "anthropic",
          anthropic_api_key: "",
          has_oauth: false
        )

      # Button should be disabled (has disabled attribute)
      assert html =~ "disabled"
    end

    test "start button enabled for anthropic with API key", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "anthropic",
          anthropic_api_key: "sk-ant-test",
          has_oauth: false
        )

      # Button should NOT be disabled
      refute html =~ ~r/disabled[^=]/
    end

    test "start button disabled for openai without API key", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "openai",
          openai_api_key: ""
        )

      assert html =~ "disabled"
    end

    test "start button disabled for ollama when not connected", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "ollama",
          ollama_status: :error,
          ollama_models: []
        )

      assert html =~ "disabled"
    end
  end

  describe "Ollama integration" do
    @tag :external
    test "displays error message when ollama is not available", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "ollama",
          ollama_status: :error,
          ollama_error: "Connection refused - is Ollama running?"
        )

      assert html =~ "Connection refused"
    end

    @tag :external
    test "displays model list when ollama is connected", %{conn: _conn} do
      html =
        render_component(StartSessionModal,
          id: "test-modal",
          show: true,
          provider: "ollama",
          ollama_status: :connected,
          ollama_models: ["llama3.2", "mistral"]
        )

      assert html =~ "llama3.2"
      assert html =~ "mistral"
      assert html =~ "Connected to Ollama"
    end
  end
end
