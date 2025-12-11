defmodule WireframeEditorWeb.ExampleGuideLive do
  @moduledoc """
  Example guide: Build a login form with the AI wireframe editor.

  This is a hardcoded, always-working example that demonstrates Koalemos capabilities.
  Perfect for first-time users and demos.
  """
  use WireframeEditorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Example: Build a Login Form",
       current_step: 1
     )}
  end

  @impl true
  def handle_event("start_example", _params, socket) do
    # Navigate to wireframe editor with pre-configured settings
    {:noreply,
     push_navigate(socket,
       to:
         "/chat/example-login-#{System.system_time(:millisecond)}?provider=anthropic&model=claude-sonnet-4-5&example=login-form"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-gray-100 py-12">
      <div class="container mx-auto px-4 max-w-4xl">
        <!-- Header -->
        <div class="mb-8">
          <a href="/" class="text-blue-600 hover:text-blue-700 flex items-center gap-2 mb-4">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z"
                clip-rule="evenodd"
              />
            </svg>
            back to home
          </a>
          <h1 class="text-4xl font-bold text-slate-800 mb-2">example: build a login form</h1>
          <p class="text-lg text-slate-600">
            a step-by-step guide to using the AI wireframe editor
          </p>
        </div>
        <!-- Introduction -->
        <div class="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 class="text-2xl font-bold text-slate-800 mb-4">what you'll learn</h2>
          <ul class="space-y-3 text-slate-700">
            <li class="flex items-start">
              <svg
                class="w-6 h-6 text-green-600 mr-3 mt-0.5 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                  clip-rule="evenodd"
                />
              </svg>
              <span>how to start a conversation with the AI agent</span>
            </li>
            <li class="flex items-start">
              <svg
                class="w-6 h-6 text-green-600 mr-3 mt-0.5 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                  clip-rule="evenodd"
                />
              </svg>
              <span>how the agent uses tools to modify HTML, CSS, and JavaScript</span>
            </li>
            <li class="flex items-start">
              <svg
                class="w-6 h-6 text-green-600 mr-3 mt-0.5 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                  clip-rule="evenodd"
                />
              </svg>
              <span>how to iterate on the design through natural conversation</span>
            </li>
            <li class="flex items-start">
              <svg
                class="w-6 h-6 text-green-600 mr-3 mt-0.5 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                  clip-rule="evenodd"
                />
              </svg>
              <span>how to save and export your final wireframe</span>
            </li>
          </ul>
        </div>
        <!-- Step-by-Step Guide -->
        <div class="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 class="text-2xl font-bold text-slate-800 mb-6">step-by-step guide</h2>
          <div class="space-y-6">
            <!-- Step 1 -->
            <div class="border-l-4 border-blue-600 pl-6">
              <h3 class="text-xl font-semibold text-slate-800 mb-2">
                <span class="text-blue-600">step 1:</span>
                start the example
              </h3>
              <p class="text-slate-600 mb-3">
                Click the "start example" button below to launch the wireframe editor with pre-configured settings.
              </p>
              <p class="text-sm text-slate-500">
                this will use Anthropic's Claude Sonnet 4.5 model. make sure you have an API key configured.
              </p>
            </div>
            <!-- Step 2 -->
            <div class="border-l-4 border-blue-600 pl-6">
              <h3 class="text-xl font-semibold text-slate-800 mb-2">
                <span class="text-blue-600">step 2:</span>
                request the login form
              </h3>
              <p class="text-slate-600 mb-3">once the editor loads, type this message:</p>
              <div class="bg-slate-100 rounded-lg p-4 font-mono text-sm text-slate-800 mb-3">
                "Build me a simple login form with username and password fields, plus a submit button. Make it centered on the page with nice styling."
              </div>
              <p class="text-sm text-slate-500">
                watch as the agent breaks down your request and uses tools to build the form.
              </p>
            </div>
            <!-- Step 3 -->
            <div class="border-l-4 border-blue-600 pl-6">
              <h3 class="text-xl font-semibold text-slate-800 mb-2">
                <span class="text-blue-600">step 3:</span>
                iterate on the design
              </h3>
              <p class="text-slate-600 mb-3">try making changes through conversation:</p>
              <ul class="list-disc list-inside text-slate-600 space-y-1 mb-3">
                <li>"Make the button blue with rounded corners"</li>
                <li>"Add a 'Forgot password?' link below the form"</li>
                <li>"Add some hover effects to the input fields"</li>
                <li>"Make the form responsive for mobile"</li>
              </ul>
              <p class="text-sm text-slate-500">
                the agent will modify the DOM, CSS, and JavaScript as needed.
              </p>
            </div>
            <!-- Step 4 -->
            <div class="border-l-4 border-blue-600 pl-6">
              <h3 class="text-xl font-semibold text-slate-800 mb-2">
                <span class="text-blue-600">step 4:</span>
                test interactions
              </h3>
              <p class="text-slate-600 mb-3">ask the agent to add functionality:</p>
              <div class="bg-slate-100 rounded-lg p-4 font-mono text-sm text-slate-800 mb-3">
                "Add form validation that shows an error if the fields are empty when I click submit"
              </div>
              <p class="text-sm text-slate-500">
                the agent can add JavaScript handlers and test them in the live preview.
              </p>
            </div>
            <!-- Step 5 -->
            <div class="border-l-4 border-blue-600 pl-6">
              <h3 class="text-xl font-semibold text-slate-800 mb-2">
                <span class="text-blue-600">step 5:</span>
                save your work
              </h3>
              <p class="text-slate-600 mb-3">when you're happy with the result:</p>
              <ol class="list-decimal list-inside text-slate-600 space-y-1">
                <li>Look for the "Save Page" button in the preview area</li>
                <li>Click it to download the complete HTML file</li>
                <li>Open it in your browser to see the final result</li>
              </ol>
            </div>
          </div>
        </div>
        <!-- What's Happening Behind the Scenes -->
        <div class="bg-blue-50 rounded-2xl p-8 mb-8">
          <h2 class="text-2xl font-bold text-slate-800 mb-4">
            what's happening behind the scenes
          </h2>
          <div class="space-y-4 text-slate-700">
            <div class="flex items-start">
              <span class="font-bold text-blue-600 mr-3 text-lg">1.</span>
              <div>
                <p class="font-semibold">semantic routing</p>
                <p class="text-sm text-slate-600">
                  the system analyzes your request and routes to the appropriate workflow (build, debug, or modify)
                </p>
              </div>
            </div>
            <div class="flex items-start">
              <span class="font-bold text-blue-600 mr-3 text-lg">2.</span>
              <div>
                <p class="font-semibold">tool execution</p>
                <p class="text-sm text-slate-600">
                  the agent uses 9 specialized tools to modify the DOM, add CSS rules, create JavaScript functions, and manage event handlers
                </p>
              </div>
            </div>
            <div class="flex items-start">
              <span class="font-bold text-blue-600 mr-3 text-lg">3.</span>
              <div>
                <p class="font-semibold">feedback loop</p>
                <p class="text-sm text-slate-600">
                  after each change, the agent sees the updated DOM state and console output, allowing it to verify changes and iterate
                </p>
              </div>
            </div>
            <div class="flex items-start">
              <span class="font-bold text-blue-600 mr-3 text-lg">4.</span>
              <div>
                <p class="font-semibold">state management</p>
                <p class="text-sm text-slate-600">
                  all changes are tracked through a lens state system that maintains both the "designed" and "running" versions
                </p>
              </div>
            </div>
          </div>
        </div>
        <!-- CTA -->
        <div class="text-center">
          <button
            phx-click="start_example"
            class="px-10 py-5 bg-gradient-to-br from-blue-500 to-indigo-600 text-white text-xl font-semibold rounded-2xl hover:from-blue-600 hover:to-indigo-700 hover:scale-105 transition-all duration-200 shadow-[2px_2px_12px_-2px_rgba(59,130,246,0.4)] hover:shadow-[3px_3px_16px_-2px_rgba(59,130,246,0.5)] border-r-[3px] border-b-[2px] border-t border-blue-400/30"
          >
            start example now
          </button>
          <p class="text-slate-500 mt-4">
            or go back to <a href="/" class="text-blue-600 hover:text-blue-700 font-medium">
              home page
            </a>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
