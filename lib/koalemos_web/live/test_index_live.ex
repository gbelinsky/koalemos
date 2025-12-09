defmodule KoalemosWeb.TestIndexLive do
  @moduledoc """
  Index page for all manual test pages.

  Lists available test pages with descriptions.
  """
  use KoalemosWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Test Pages")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50">
      <div class="max-w-4xl mx-auto px-4 py-12">
        <!-- Header -->
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-slate-800 mb-3">
            koalemos test pages
          </h1>
          <p class="text-lg text-slate-600">
            Manual testing and demonstration pages
          </p>
        </div>

    <!-- Test Pages List -->
        <div class="space-y-4">
          <!-- Screenshot Test Page -->
          <a
            href="/test/screenshot"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border border-slate-200 hover:border-indigo-300"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-indigo-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
              </div>
              <div class="flex-1">
                <h2 class="text-xl font-semibold text-slate-800 mb-2">
                  Screenshot Integration
                </h2>
                <p class="text-slate-600 mb-3">
                  Interactive chat with AI that can capture screenshots. Test the full M3 Sprint 3 screenshot flow with real JavaScript execution.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-indigo-100 text-indigo-700 rounded">
                    Chat
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Screenshots
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded">
                    TestLens
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Sequential Thinking Test Page -->
          <a
            href="/test/thinking"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border border-slate-200 hover:border-indigo-300"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-teal-100 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-teal-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
                  />
                </svg>
              </div>
              <div class="flex-1">
                <h2 class="text-xl font-semibold text-slate-800 mb-2">
                  Sequential Thinking Test
                </h2>
                <p class="text-slate-600 mb-3">
                  Test step-by-step reasoning with the SequentialThinking lens. Try complex problems and watch the AI break down its thought process. Supports revision and branching.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-teal-100 text-teal-700 rounded">
                    Chat
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    SequentialThinking
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Step-by-step
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Persona Test Page -->
          <a
            href="/test/persona"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border border-slate-200 hover:border-indigo-300"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-purple-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                  />
                </svg>
              </div>
              <div class="flex-1">
                <h2 class="text-xl font-semibold text-slate-800 mb-2">
                  Persona Lens Test
                </h2>
                <p class="text-slate-600 mb-3">
                  Experiment with dimensional persona configurations. Select tone, expertise areas, and communication style to see how AI responses change with different personas.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Chat
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-pink-100 text-pink-700 rounded">
                    PersonaLens
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    Dimensional Config
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Wireframe Editor (Production) -->
          <a
            href="/wireframe-editor"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border-2 border-blue-500"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-blue-500 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-white"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
                </svg>
              </div>
              <div class="flex-1">
                <div class="flex items-center gap-2 mb-2">
                  <h2 class="text-xl font-semibold text-slate-800">
                    Wireframe Editor
                  </h2>
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    Production
                  </span>
                </div>
                <p class="text-slate-600 mb-3">
                  Build and modify web pages through conversation with AI. Production-ready interface with sample selection, real-time preview, and save functionality. Clean UX without debug UI.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    M6 Demo
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded">
                    WireframeDesignRoutine
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Live Preview
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-blue-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Wireframe Editor V4 (Simplified Architecture) -->
          <a
            href={"/wireframe-editor-v4/v4-demo-#{:erlang.unique_integer([:positive])}"}
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border-2 border-emerald-500"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-emerald-500 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-white"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
                </svg>
              </div>
              <div class="flex-1">
                <div class="flex items-center gap-2 mb-2">
                  <h2 class="text-xl font-semibold text-slate-800">
                    Wireframe Editor V4
                  </h2>
                  <span class="px-2 py-1 text-xs font-medium bg-emerald-100 text-emerald-700 rounded">
                    Simplified
                  </span>
                </div>
                <p class="text-slate-600 mb-3">
                  V4 architecture: No PubSub, direct process communication via Registry. Blocking capture_state/execute_interaction. Two-state preview model (nil or pid). Simpler than V3.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-emerald-100 text-emerald-700 rounded">
                    V4 Architecture
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded">
                    No PubSub
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Direct Registry
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    Blocking Ops
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-emerald-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Wireframe Test Page -->
          <a
            href="/test/wireframe"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border border-slate-200 hover:border-indigo-300"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-blue-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
                  />
                </svg>
              </div>
              <div class="flex-1">
                <h2 class="text-xl font-semibold text-slate-800 mb-2">
                  Wireframe Test Environment
                </h2>
                <p class="text-slate-600 mb-3">
                  Test infrastructure for M4 WireframeEditor lens. Load and preview sample HTML wireframes (simple, medium, complex). Foundation for future DOM/JavaScript/CSS manipulation tools.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    M4 Sprint 1
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Wireframe Preview
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded">
                    Test Infrastructure
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Lens Combinator Test Page -->
          <a
            href="/test/lens-combinator"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border border-slate-200 hover:border-indigo-300"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-amber-100 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-amber-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
                  />
                </svg>
              </div>
              <div class="flex-1">
                <h2 class="text-xl font-semibold text-slate-800 mb-2">
                  Multi-Lens Testing Interface
                </h2>
                <p class="text-slate-600 mb-3">
                  Sprint 8: Test lens combinations. Select multiple lenses (PersonaLens, SequentialThinking, WireframeEditor), configure options, and validate they work together without conflicts.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-amber-100 text-amber-700 rounded">
                    Sprint 8
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Multi-Lens
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    Integration Testing
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Parsing Integration Test Page -->
          <a
            href="/test/parsing"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border border-slate-200 hover:border-indigo-300"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-green-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
                  />
                </svg>
              </div>
              <div class="flex-1">
                <h2 class="text-xl font-semibold text-slate-800 mb-2">
                  Parsing Integration
                </h2>
                <p class="text-slate-600 mb-3">
                  Test HTML/JavaScript parsing pipeline. Upload or paste HTML wireframes to see DOM extraction, variable parsing, function detection, and event handler mapping. Sprint 6 & 7 integration demo.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded">
                    HTMLParser
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                    JavaScriptParser
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded">
                    Caches
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-700 rounded">
                    Handlers
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>

    <!-- Sample Page -->
          <a
            href="/test/sample"
            class="block bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-200 p-6 border border-slate-200 hover:border-indigo-300"
          >
            <div class="flex items-start gap-4">
              <div class="flex-shrink-0 w-12 h-12 bg-slate-100 rounded-lg flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-slate-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
              </div>
              <div class="flex-1">
                <h2 class="text-xl font-semibold text-slate-800 mb-2">
                  Sample Components
                </h2>
                <p class="text-slate-600 mb-3">
                  Basic LiveView component examples and UI patterns.
                </p>
                <div class="flex flex-wrap gap-2">
                  <span class="px-2 py-1 text-xs font-medium bg-slate-100 text-slate-700 rounded">
                    Components
                  </span>
                  <span class="px-2 py-1 text-xs font-medium bg-slate-100 text-slate-700 rounded">
                    Examples
                  </span>
                </div>
              </div>
              <div class="flex-shrink-0">
                <svg
                  class="w-6 h-6 text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </a>
        </div>

    <!-- Back to Home -->
        <div class="mt-12 text-center">
          <a
            href="/"
            class="inline-flex items-center gap-2 text-slate-600 hover:text-slate-800 transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10 19l-7-7m0 0l7-7m-7 7h18"
              />
            </svg>
            Back to Home
          </a>
        </div>
      </div>
    </div>
    """
  end
end
