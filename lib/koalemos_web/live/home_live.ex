defmodule KoalemosWeb.HomeLive do
  @moduledoc """
  Landing page for Koalemos.

  Simple home page with a "Start Chat Session" button that opens a modal
  to begin a new chat routine.
  """
  use KoalemosWeb, :live_view

  alias KoalemosWeb.StartSessionModal

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
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-gray-100">
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
        <!-- What to Try -->
        <div class="grid md:grid-cols-3 gap-6 mb-12">
          <!-- Option 1: Tutorial -->
          <div class="bg-white rounded-2xl shadow-lg p-6 hover:shadow-xl transition-shadow">
            <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-4">
              <svg class="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                <path d="M9 4.804A7.968 7.968 0 005.5 4c-1.255 0-2.443.29-3.5.804v10A7.969 7.969 0 015.5 14c1.669 0 3.218.51 4.5 1.385A7.962 7.962 0 0114.5 14c1.255 0 2.443.29 3.5.804v-10A7.968 7.968 0 0014.5 4c-1.255 0-2.443.29-3.5.804V12a1 1 0 11-2 0V4.804z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-slate-800 mb-2">start with a tutorial</h3>
            <p class="text-slate-600 mb-4 text-sm">
              new here? follow our step-by-step guide to build a login form and learn the basics.
            </p>
            <a
              href="/example/login-form"
              class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-700 font-medium text-sm"
            >
              <span>open tutorial</span>
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </a>
          </div>
          <!-- Option 2: Wireframe Editor -->
          <div class="bg-white rounded-2xl shadow-lg p-6 hover:shadow-xl transition-shadow border-2 border-blue-500">
            <div class="w-12 h-12 bg-blue-500 rounded-lg flex items-center justify-center mb-4">
              <svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
              </svg>
            </div>
            <div class="flex items-center gap-2 mb-2">
              <h3 class="text-xl font-bold text-slate-800">wireframe editor</h3>
              <span class="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-medium rounded">
                recommended
              </span>
            </div>
            <p class="text-slate-600 mb-4 text-sm">
              build and modify web pages through conversation. watch as the AI makes changes in real-time.
            </p>
            <a
              href="/wireframe-editor"
              class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-700 font-medium text-sm"
            >
              <span>open editor</span>
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </a>
          </div>
          <!-- Option 3: Explore -->
          <div class="bg-white rounded-2xl shadow-lg p-6 hover:shadow-xl transition-shadow">
            <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-4">
              <svg class="w-6 h-6 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10.394 2.08a1 1 0 00-.788 0l-7 3a1 1 0 000 1.84L5.25 8.051a.999.999 0 01.356-.257l4-1.714a1 1 0 11.788 1.838L7.667 9.088l1.94.831a1 1 0 00.787 0l7-3a1 1 0 000-1.838l-7-3zM3.31 9.397L5 10.12v4.102a8.969 8.969 0 00-1.05-.174 1 1 0 01-.89-.89 11.115 11.115 0 01.25-3.762zM9.3 16.573A9.026 9.026 0 007 14.935v-3.957l1.818.78a3 3 0 002.364 0l5.508-2.361a11.026 11.026 0 01.25 3.762 1 1 0 01-.89.89 8.968 8.968 0 00-5.35 2.524 1 1 0 01-1.4 0zM6 18a1 1 0 001-1v-2.065a8.935 8.935 0 00-2-.712V17a1 1 0 001 1z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-slate-800 mb-2">explore test pages</h3>
            <p class="text-slate-600 mb-4 text-sm">
              check out the interactive test pages to see different lenses and features.
            </p>
            <a
              href="/test"
              class="inline-flex items-center gap-2 text-purple-600 hover:text-purple-700 font-medium text-sm"
            >
              <span>view test pages</span>
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </a>
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
                      href="https://github.com/yourusername/koalemos/blob/main/README.md"
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
        <!-- Footer Links -->
        <div class="text-center text-sm text-slate-500">
          <p class="mb-2">
            koalemos is open source. built with Elixir, Phoenix LiveView, and Claude.
          </p>
          <div class="flex justify-center gap-4">
            <a
              href="https://github.com/yourusername/koalemos"
              class="hover:text-slate-700 transition-colors"
            >
              GitHub
            </a>
            <span>•</span>
            <a href="/test" class="hover:text-slate-700 transition-colors">test pages</a>
            <span>•</span>
            <a
              href="https://github.com/yourusername/koalemos/blob/main/docs"
              class="hover:text-slate-700 transition-colors"
            >
              documentation
            </a>
          </div>
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
