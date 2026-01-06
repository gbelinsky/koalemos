defmodule WireframeEditorWeb.HomeLive do
  @moduledoc """
  Landing page for Koalemos.

  Simple home page with a "Start Chat Session" button that opens a modal
  to begin a new chat routine.
  """
  use WireframeEditorWeb, :live_view

  alias WireframeEditorWeb.StartSessionModal

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Koalemos",
       show_modal: false
     )}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_info({:close_modal}, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_info({:start_chat, _routine_id}, socket) do
    # Modal handles navigation, just close modal state
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_info({:ollama_check_complete, component_id, result}, socket) do
    # Forward async Ollama check result to the modal component
    send_update(StartSessionModal, id: component_id, ollama_result: result)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50">
      <.site_nav current_page={:home} />

      <div class="container mx-auto px-4 py-12 max-w-6xl">
        <!-- Hero Section -->
        <div class="text-center mb-12">
          <div class="inline-flex items-center gap-2 px-4 py-2 bg-green-100 text-green-800 rounded-full text-sm font-medium mb-4">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                clip-rule="evenodd"
              />
            </svg>
            <span>koalemos is running</span>
          </div>
          <h1 class="text-6xl font-bold text-slate-800 mb-4">welcome to koalemos</h1>
          <p class="text-2xl text-slate-600 mb-6">
            a developer framework for building conversational AI applications
          </p>
          <p class="text-lg text-slate-500 max-w-3xl mx-auto">
            you're now running the interactive wireframe editor demo. try building UI components through conversation with an AI agent.
          </p>
        </div>

        <!-- Wireframe Editor Card -->
        <a
          href="/wireframe-editor"
          class="block bg-white rounded-2xl shadow-lg p-8 mb-12 hover:shadow-xl transition-shadow border-2 border-blue-500"
        >
          <div class="flex items-center gap-6">
            <div class="w-16 h-16 bg-blue-500 rounded-xl flex items-center justify-center flex-shrink-0">
              <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
              </svg>
            </div>
            <div class="flex-1">
              <h2 class="text-2xl font-bold text-slate-800 mb-2">Wireframe Editor</h2>
              <p class="text-slate-600">
                Build and modify web pages through conversation. Watch as the AI makes changes in real-time.
              </p>
            </div>
            <svg class="w-6 h-6 text-blue-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </div>
        </a>

        <!-- Try These -->
        <div class="bg-white rounded-2xl shadow-lg p-8 mb-12">
          <h2 class="text-lg font-semibold text-slate-800 mb-4">try asking for...</h2>
          <div class="flex flex-wrap gap-3">
            <span class="px-4 py-2 bg-slate-100 text-slate-700 rounded-lg text-sm">"Let's play tic tac toe"</span>
            <span class="px-4 py-2 bg-slate-100 text-slate-700 rounded-lg text-sm">"Build a calculator"</span>
            <span class="px-4 py-2 bg-slate-100 text-slate-700 rounded-lg text-sm">"Create a todo list app"</span>
            <span class="px-4 py-2 bg-slate-100 text-slate-700 rounded-lg text-sm">"Make a color picker"</span>
            <span class="px-4 py-2 bg-slate-100 text-slate-700 rounded-lg text-sm">"Design a login form"</span>
          </div>
        </div>
        <!-- What This Demo Shows -->
        <div class="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl p-8 mb-12">
          <h2 class="text-2xl font-bold text-slate-800 mb-4 text-center">
            what this demo showcases
          </h2>
          <div class="grid md:grid-cols-2 gap-6">
            <div>
              <h3 class="text-lg font-semibold text-slate-700 mb-3 flex items-center gap-2">
                <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z"
                    clip-rule="evenodd"
                  />
                </svg>
                <span>features in action</span>
              </h3>
              <ul class="space-y-2 text-sm text-slate-600">
                <li class="flex items-start">
                  <span class="text-blue-600 mr-2">▸</span>
                  <span>conversational UI building</span>
                </li>
                <li class="flex items-start">
                  <span class="text-blue-600 mr-2">▸</span>
                  <span>AI agent with 9 specialized tools</span>
                </li>
                <li class="flex items-start">
                  <span class="text-blue-600 mr-2">▸</span>
                  <span>real-time preview and iteration</span>
                </li>
                <li class="flex items-start">
                  <span class="text-blue-600 mr-2">▸</span>
                  <span>export to standalone HTML</span>
                </li>
              </ul>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-slate-700 mb-3 flex items-center gap-2">
                <svg class="w-5 h-5 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z"
                    clip-rule="evenodd"
                  />
                </svg>
                <span>framework concepts</span>
              </h3>
              <ul class="space-y-2 text-sm text-slate-600">
                <li class="flex items-start">
                  <span class="text-purple-600 mr-2">▸</span>
                  <span>routines (state machine workflows)</span>
                </li>
                <li class="flex items-start">
                  <span class="text-purple-600 mr-2">▸</span>
                  <span>lenses (pluggable capabilities)</span>
                </li>
                <li class="flex items-start">
                  <span class="text-purple-600 mr-2">▸</span>
                  <span>semantic routing (intelligent flow)</span>
                </li>
                <li class="flex items-start">
                  <span class="text-purple-600 mr-2">▸</span>
                  <span>feedback loops (agent sees results)</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
        <!-- Next Steps -->
        <div class="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 class="text-2xl font-bold text-slate-800 mb-4 text-center">next steps</h2>
          <div class="grid md:grid-cols-2 gap-6 text-sm">
            <div>
              <h3 class="font-semibold text-slate-700 mb-2">for users</h3>
              <ul class="space-y-2 text-slate-600">
                <li class="flex items-start">
                  <span class="text-green-600 mr-2">✓</span>
                  <span>configure your preferred LLM provider (Anthropic, OpenAI, or Ollama)</span>
                </li>
                <li class="flex items-start">
                  <span class="text-green-600 mr-2">✓</span>
                  <span>explore the wireframe editor and build some UIs</span>
                </li>
                <li class="flex items-start">
                  <span class="text-green-600 mr-2">✓</span>
                  <span>check out the test pages to see other capabilities</span>
                </li>
              </ul>
            </div>
            <div>
              <h3 class="font-semibold text-slate-700 mb-2">for developers</h3>
              <ul class="space-y-2 text-slate-600">
                <li class="flex items-start">
                  <span class="text-blue-600 mr-2">→</span>
                  <span>
                    read the
                    <a
                      href="https://github.com/gbelinsky/koalemos/blob/main/README.md"
                      class="text-blue-600 hover:underline"
                    >
                      README
                    </a>
                    to understand the architecture
                  </span>
                </li>
                <li class="flex items-start">
                  <span class="text-blue-600 mr-2">→</span>
                  <span>create your own lenses to add new capabilities</span>
                </li>
                <li class="flex items-start">
                  <span class="text-blue-600 mr-2">→</span>
                  <span>build custom routines for your specific workflows</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
        <!-- Footer -->
        <div class="text-center text-sm text-slate-500">
          <p>
            koalemos is open source. built with Elixir, Phoenix LiveView, and Claude.
          </p>
        </div>
      </div>
      <!-- Start Session Modal -->
      <.live_component
        module={StartSessionModal}
        id="start-session-modal"
        show={@show_modal}
      />
    </div>
    """
  end
end
