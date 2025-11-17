# Sprint 7: WireframeEditor Feedback Loop & Integration

**Branch:** `feature/m4-7-feedback-loop`
**Started:** November 8, 2025
**Goal:** Complete WireframeEditor with all 9 tools working and full feedback integration (console, screenshots, current state tracking)
**Estimated Timeline:** 4-5 days
**Estimated Lines:** ~1,000 lines (code + tests)

---

## Overview

Sprint 7 completes the WireframeEditor lens by implementing the critical feedback loop that allows the agent to see the current state of the wireframe preview, including user interactions, JavaScript mutations, console output, and visual state via screenshots.

**Key Philosophy:** The lens system provides context when appropriate and keeps it current. The agent doesn't request screenshots - the system provides them automatically when the state changes.

**End Goal:** An agent can build a tic-tac-toe game, then play it with the user by seeing their moves and responding with its own moves using the available tools.

---

## Current State (After Sprint 6)

**What Works:**
- ✅ 8 of 9 tools functional (trigger_interaction is a stub)
- ✅ JavaScript rendering in preview (variables, functions, handlers, init scripts)
- ✅ Dynamic updates via JavaScriptUpdater hook
- ✅ 945 of 947 tests passing

**What's Missing:**
- ❌ trigger_interaction tool (needs client-side infrastructure)
- ❌ Current state tracking (agent only sees designed state)
- ❌ Console integration (ConsoleCache exists but not connected)
- ❌ Screenshot integration (ScreenshotCache exists but not in workflow)
- ❌ Feedback loop (agent can't see results of interactions)

---

## Architecture: Two-State Model

### Designed State (`lens_state.designed`)
- **Purpose:** Source of truth being edited
- **Storage:** WireframeStateCache (ETS)
- **Lifecycle:** Persists across sessions, gets exported
- **Contains:**
  - `dom_tree` - HTML structure
  - `custom_css` - CSS rules
  - `custom_functions` - JavaScript functions
  - `custom_variables` - Global variables
  - `init_scripts` - Initialization code
  - `handlers` - Event handlers

### Current/Running State (`lens_state.running`)
- **Purpose:** Live runtime state from preview iframe
- **Storage:** Captured on-demand before each LLM request
- **Lifecycle:** Ephemeral - recaptured each time
- **Contains:**
  - `dom_tree` - Actual DOM (may differ from designed)
  - `console_output` - Recent console messages
  - `screenshot` - Visual state (base64 PNG)
  - `captured_at` - Snapshot timestamp
  - `differs_from_designed` - Boolean flag

### Why Two States?

1. **Designed** = What we save/export (permanent changes)
2. **Current** = What's actually running (includes testing interactions)
3. **Agent sees both** = Can test interactions without losing work
4. **Clear separation** = Agent knows which tools make permanent vs ephemeral changes

---

## State Capture Flow

```
Before Every LLM Request (provide_context):
┌─────────────────────────────────────────────────────────────┐
│ 1. Lens: Broadcast {:snapshot_request, routine_id}         │
├─────────────────────────────────────────────────────────────┤
│ 2. Preview LiveView: Push "capture_state" to client        │
├─────────────────────────────────────────────────────────────┤
│ 3. JavaScript Hook:                                         │
│    - Serialize current DOM to map                           │
│    - Capture screenshot (html2canvas)                       │
│    - Gather console messages since last snapshot            │
│    - Push "state_snapshot" back to server                   │
├─────────────────────────────────────────────────────────────┤
│ 4. Preview LiveView: Receive snapshot data                  │
│    - Store DOM in DOMStateCache                             │
│    - Store console in ConsoleCache (if any)                 │
│    - Store screenshot in ScreenshotCache                    │
│    - Broadcast {:snapshot_ready, routine_id}                │
├─────────────────────────────────────────────────────────────┤
│ 5. Lens: Receive snapshot_ready                             │
│    - Retrieve from caches                                   │
│    - Build lens_state.running                               │
│    - Generate context showing both designed + running       │
└─────────────────────────────────────────────────────────────┘

Timeout: 5 seconds (if preview doesn't respond, use stale data)
```

---

## Tool Execution Flow (trigger_interaction)

```
Agent calls trigger_interaction:
┌─────────────────────────────────────────────────────────────┐
│ 1. Tool: Broadcast {:execute_interaction, args}             │
├─────────────────────────────────────────────────────────────┤
│ 2. Preview LiveView: Push "execute_interaction" to client   │
├─────────────────────────────────────────────────────────────┤
│ 3. JavaScript Hook:                                          │
│    - Pause DOM observation (prevent loops)                   │
│    - Execute interaction (click, fill, submit, js)           │
│    - Capture screenshot of result                            │
│    - Resume DOM observation                                  │
│    - Push "interaction_complete" back                        │
├─────────────────────────────────────────────────────────────┤
│ 4. Preview LiveView: Broadcast {:interaction_complete}       │
├─────────────────────────────────────────────────────────────┤
│ 5. Tool: Return success message                             │
│    "Triggered [action] on [element]. Check LIVE DOM STATE   │
│     in next context to see the result."                      │
└─────────────────────────────────────────────────────────────┘

Next LLM request will capture the new state and agent sees changes
```

---

## PHASE 1: Documentation First ✅

**Goal:** Clear all documentation debt before writing any code
**Timeline:** Day 1 morning (~4 hours)

### Tasks:

1. ✅ **Create Sprint 7 Plan** - This document
2. **Update M4.md** - Add Sprint 7 entry, update progress (7 of 8 sprints)
3. **Update BACKLOG.md** - Mark Sprint 7 in progress
4. **Architecture Documentation** - Document feedback loop architecture

### Success Criteria:
- [ ] All documentation current and accurate
- [ ] Sprint 7 plan is clear and actionable
- [ ] Team understands what we're building

### Files:
- `docs/sprints/sprint-7-plan.md` (this file)
- `docs/milestones/M4.md`
- `docs/BACKLOG.md`

---

## PHASE 2: State Snapshot Infrastructure

**Goal:** Capture current DOM + console + screenshot before every LLM request
**Timeline:** Day 1 afternoon - Day 2 morning
**Estimated:** ~200 lines

### Implementation:

#### 1. State Capture Orchestration (~100 lines)
**Location:** `lib/koalemos/lenses/wireframe_editor/core.ex`

**New Function:**
```elixir
@doc """
Capture current state from preview iframe.

Requests DOM snapshot, screenshot, and console messages via PubSub,
waits for response with timeout, and returns complete running state.

## Options
- `:timeout` - Max wait time in ms (default: 5000)
- `:skip_screenshot` - Skip screenshot capture (default: false)

## Returns
- `{:ok, running_state}` - Complete state captured
- `{:error, :timeout}` - Preview didn't respond in time
- `{:error, :no_preview}` - Preview not running
"""
@spec capture_current_state(String.t(), keyword()) ::
  {:ok, map()} | {:error, atom()}
def capture_current_state(routine_id, opts \\ [])
```

**Implementation:**
1. Subscribe to `"snapshot:response:#{routine_id}"` temporarily
2. Broadcast `{:snapshot_request, routine_id}` to preview
3. Wait for `{:snapshot_ready, data}` with timeout
4. Fetch from caches (DOMStateCache, ConsoleCache, ScreenshotCache)
5. Build and return `running` state map
6. Unsubscribe and cleanup

#### 2. Preview State Broadcaster (~50 lines)
**Location:** `lib/koalemos_web/live/wireframe_preview_live.ex`

**New Handler:**
```elixir
def handle_info({:snapshot_request, requested_id}, socket) do
  if socket.assigns.routine_id == requested_id do
    Logger.debug("[WireframePreviewLive] Snapshot requested, triggering client capture")
    {:noreply, push_event(socket, "capture_state", %{})}
  else
    {:noreply, socket}
  end
end

def handle_event("state_snapshot", snapshot_data, socket) do
  routine_id = socket.assigns.routine_id

  # Store DOM
  if dom_tree = snapshot_data["dom_tree"] do
    DOMStateCache.add_dom_state(routine_id, %{
      live_dom_tree: dom_tree,
      change_type: "snapshot",
      timestamp: System.system_time(:millisecond)
    })
  end

  # Store console (if any new messages)
  if console_messages = snapshot_data["console_messages"] do
    Enum.each(console_messages, fn msg ->
      ConsoleCache.add_message(routine_id, msg)
    end)
  end

  # Store screenshot
  if screenshot_data = snapshot_data["screenshot"] do
    ScreenshotCache.put(routine_id, screenshot_data)
  end

  # Broadcast ready
  Phoenix.PubSub.broadcast(
    Koalemos.PubSub,
    "snapshot:response:#{routine_id}",
    {:snapshot_ready, %{routine_id: routine_id, captured_at: DateTime.utc_now()}}
  )

  {:noreply, socket}
end
```

#### 3. Client-Side State Capture (~50 lines)
**Location:** `assets/js/wireframe_hooks.js`

**Extend JavaScriptUpdater Hook:**
```javascript
// In JavaScriptUpdater hook
this.handleEvent("capture_state", () => {
  this.captureCompleteState()
})

async captureCompleteState() {
  console.log("[StateCapture] Capturing complete state...")

  const dom_tree = this.serializeDOM(document.body)
  const console_messages = this.getConsoleSinceLastSnapshot()
  const screenshot = await this.captureScreenshotBlocking()

  this.pushEvent("state_snapshot", {
    dom_tree: dom_tree,
    console_messages: console_messages,
    screenshot: screenshot,
    timestamp: Date.now()
  })

  this.lastSnapshotTime = Date.now()
}

serializeDOM(element) {
  // Convert DOM element to map structure
  return {
    tag: element.tagName.toLowerCase(),
    id: element.id || null,
    classes: Array.from(element.classList),
    attributes: Object.fromEntries(
      Array.from(element.attributes).map(attr => [attr.name, attr.value])
    ),
    content: element.childNodes.length === 1 &&
             element.childNodes[0].nodeType === 3
      ? element.textContent
      : null,
    children: Array.from(element.children).map(child =>
      this.serializeDOM(child)
    )
  }
}
```

### Success Criteria:
- [ ] Can capture complete current state on demand
- [ ] Snapshot includes DOM + console + screenshot
- [ ] Timeout protection (doesn't hang if preview unresponsive)
- [ ] Performance acceptable (<2s for capture)

### Files:
- `lib/koalemos/lenses/wireframe_editor/core.ex` (+100)
- `lib/koalemos_web/live/wireframe_preview_live.ex` (+50)
- `assets/js/wireframe_hooks.js` (+50)

---

## PHASE 3: trigger_interaction Implementation

**Goal:** All 9 tools fully functional, agent can interact with preview
**Timeline:** Day 2
**Estimated:** ~150 lines

### Tool Schema (Already Exists)

```json
{
  "name": "trigger_interaction",
  "description": "Trigger an interaction with the wireframe preview...",
  "input_schema": {
    "type": "object",
    "properties": {
      "action": {
        "type": "string",
        "enum": ["click", "fill_input", "submit_form", "execute_js"]
      },
      "element_id": {"type": "string"},
      "value": {"type": "string"},
      "javascript": {"type": "string"}
    },
    "required": ["action"]
  }
}
```

### Implementation:

#### 1. Server-Side Tool (~20 lines)
**Location:** `lib/koalemos/lenses/wireframe_editor/dom_handler.ex:462-476`

**Update Implementation:**
```elixir
def trigger_interaction(_lens_state, args, context) do
  routine_id = Map.get(context, :routine_id)
  action = Map.get(args, "action")
  element_id = Map.get(args, "element_id")

  # Broadcast interaction request to preview
  Phoenix.PubSub.broadcast(
    Koalemos.PubSub,
    "routine:#{routine_id}",
    {:execute_interaction, args}
  )

  # Return guidance message
  """
  Triggered #{action}#{if element_id, do: " on element '#{element_id}'", else: ""}.

  NOTE: This is a TESTING tool - changes are EPHEMERAL and won't persist to design.
  The preview state has been modified. In your NEXT context, check the LIVE DOM STATE
  section to see what happened.

  For PERMANENT changes, use design tools (modify_elements, manage_handlers, etc.).
  """
  |> then(&{&1, []})
end
```

#### 2. Preview Interaction Handler (~30 lines)
**Location:** `lib/koalemos_web/live/wireframe_preview_live.ex`

**New Handler:**
```elixir
def handle_info({:execute_interaction, args}, socket) do
  Logger.debug("[WireframePreviewLive] Executing interaction: #{inspect(args)}")
  {:noreply, push_event(socket, "execute_interaction", args)}
end

def handle_event("interaction_complete", result, socket) do
  routine_id = socket.assigns.routine_id

  Logger.info("[WireframePreviewLive] Interaction completed: #{inspect(result)}")

  Phoenix.PubSub.broadcast(
    Koalemos.PubSub,
    "routine:#{routine_id}",
    {:interaction_complete, result}
  )

  {:noreply, socket}
end
```

#### 3. Client-Side Execution (~100 lines)
**Location:** `assets/js/wireframe_hooks.js`

**New Methods in JavaScriptUpdater:**
```javascript
// Listen for interaction execution requests
this.handleEvent("execute_interaction", (args) => {
  this.executeInteraction(args)
})

executeInteraction(command) {
  console.log("[Interaction] Executing:", command)

  // Pause DOM observation during interactions
  const wasObserving = this.isObservingChanges
  if (wasObserving) {
    this.stopDOMObservation()
  }

  try {
    switch(command.action) {
      case "click":
        this.triggerClick(command.element_id)
        break
      case "fill_input":
        this.fillInput(command.element_id, command.value)
        break
      case "submit_form":
        this.submitForm(command.element_id)
        break
      case "execute_js":
        this.executeJavaScript(command.javascript)
        break
      default:
        throw new Error(`Unknown interaction action: ${command.action}`)
    }

    // Capture screenshot after interaction
    setTimeout(() => {
      this.captureScreenshot()
      this.pushEvent("interaction_complete", {success: true, action: command.action})

      if (wasObserving) {
        setTimeout(() => this.startDOMObservation(), 500)
      }
    }, 300)

  } catch (error) {
    console.error("[Interaction] Failed:", error)
    this.pushEvent("interaction_complete", {success: false, error: error.message})

    if (wasObserving) {
      this.startDOMObservation()
    }
  }
}

triggerClick(elementId) {
  const el = document.getElementById(elementId)
  if (!el) throw new Error(`Element not found: ${elementId}`)
  el.click()
}

fillInput(elementId, value) {
  const el = document.getElementById(elementId)
  if (!el) throw new Error(`Element not found: ${elementId}`)
  el.value = value
  el.dispatchEvent(new Event('input', { bubbles: true }))
  el.dispatchEvent(new Event('change', { bubbles: true }))
}

submitForm(elementId) {
  const el = document.getElementById(elementId)
  if (!el) throw new Error(`Element not found: ${elementId}`)
  el.dispatchEvent(new Event('submit', { bubbles: true }))
}

executeJavaScript(code) {
  // Execute in global scope
  (new Function(code))()
}
```

### Success Criteria:
- [ ] Can click buttons programmatically
- [ ] Can fill form inputs
- [ ] Can submit forms
- [ ] Can execute custom JavaScript
- [ ] State captured after interaction
- [ ] Screenshot shows interaction result

### Files:
- `lib/koalemos/lenses/wireframe_editor/dom_handler.ex` (+20)
- `lib/koalemos_web/live/wireframe_preview_live.ex` (+30)
- `assets/js/wireframe_hooks.js` (+100)

---

## PHASE 4: Console Integration

**Goal:** Agent sees JavaScript errors and console output in context
**Timeline:** Day 2-3
**Estimated:** ~150 lines

### Implementation:

#### 1. Console Interception (~80 lines)
**Location:** `assets/js/wireframe_hooks.js`

**New Console Management:**
```javascript
// In JavaScriptUpdater hook mounted()
this.consoleBuffer = []
this.lastSnapshotTime = Date.now()
this.originalConsole = {
  log: console.log,
  error: console.error,
  warn: console.warn
}

this.interceptConsole()

// Console interception
interceptConsole() {
  const self = this

  console.log = function(...args) {
    self.originalConsole.log(...args)
    self.bufferConsoleMessage('log', args)
  }

  console.error = function(...args) {
    self.originalConsole.error(...args)
    self.bufferConsoleMessage('error', args)
  }

  console.warn = function(...args) {
    self.originalConsole.warn(...args)
    self.bufferConsoleMessage('warn', args)
  }
}

bufferConsoleMessage(level, args) {
  const message = args.map(arg =>
    typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
  ).join(' ')

  this.consoleBuffer.push({
    level: level,
    message: message,
    timestamp: Date.now()
  })

  // Keep buffer reasonable size
  if (this.consoleBuffer.length > 100) {
    this.consoleBuffer.shift()
  }
}

getConsoleSinceLastSnapshot() {
  return this.consoleBuffer.filter(msg =>
    msg.timestamp > this.lastSnapshotTime
  )
}
```

#### 2. Console Handler (~30 lines)
**Location:** `lib/koalemos_web/live/wireframe_preview_live.ex`

**Already receives console in state_snapshot, just ensure it's stored:**
```elixir
# In handle_event("state_snapshot", ...) - already implemented in Phase 2
if console_messages = snapshot_data["console_messages"] do
  Enum.each(console_messages, fn msg ->
    ConsoleCache.add_message(routine_id, msg)
  end)
end
```

#### 3. Console Snapshot Integration (~40 lines)
**Location:** `lib/koalemos/lenses/wireframe_editor/core.ex`

**Update capture_current_state:**
```elixir
def capture_current_state(routine_id, opts \\ []) do
  # ... existing snapshot capture ...

  # Fetch console messages
  console_messages = ConsoleCache.get_messages(routine_id,
    since: DateTime.add(DateTime.utc_now(), -60, :second),
    limit: 50
  )

  running_state = %{
    dom_tree: dom_tree,
    console_output: console_messages,
    screenshot: screenshot_data,
    captured_at: DateTime.utc_now()
  }

  {:ok, running_state}
end
```

### Success Criteria:
- [ ] console.log appears in agent context
- [ ] console.error appears in agent context
- [ ] Rate limiting works (no infinite loop crashes)
- [ ] Agent can see and fix JavaScript errors
- [ ] Only new messages since last snapshot included

### Files:
- `assets/js/wireframe_hooks.js` (+80)
- `lib/koalemos_web/live/wireframe_preview_live.ex` (already done in Phase 2)
- `lib/koalemos/lenses/wireframe_editor/core.ex` (+40)

---

## PHASE 5: Screenshot Integration

**Goal:** Screenshots automatically included in context, system-driven
**Timeline:** Day 3
**Estimated:** ~100 lines

### Implementation:

#### 1. Blocking Screenshot Capture (~50 lines)
**Location:** `assets/js/wireframe_hooks.js`

**New Method:**
```javascript
async captureScreenshotBlocking() {
  if (!this.html2canvasReady) {
    console.warn("[Screenshot] html2canvas not ready")
    return null
  }

  try {
    const canvas = await window.html2canvas(document.body, {
      backgroundColor: '#ffffff',
      scale: 1,
      useCORS: true,
      allowTaint: false,
      removeContainer: true,
      logging: false
    })

    const dataUrl = canvas.toDataURL('image/png')
    return dataUrl.split(',')[1] // Return base64 data only

  } catch (error) {
    console.error("[Screenshot] Capture failed:", error)
    return null
  }
}
```

#### 2. Screenshot in State (~30 lines)
**Location:** `lib/koalemos/lenses/wireframe_editor/core.ex`

**Already integrated in capture_current_state, just ensure retrieval:**
```elixir
def capture_current_state(routine_id, opts \\ []) do
  # ... existing code ...

  # Fetch screenshot
  screenshot_data = unless opts[:skip_screenshot] do
    case ScreenshotCache.get(routine_id) do
      {:ok, data} -> data
      _ -> nil
    end
  end

  running_state = %{
    # ...
    screenshot: screenshot_data,
    # ...
  }
end
```

#### 3. Screenshot Context Rendering (~20 lines)
**Location:** `lib/koalemos/lenses/wireframe_editor/core.ex`

**New Context Section:**
```elixir
defp build_screenshot_section(%{screenshot: screenshot_data}) when not is_nil(screenshot_data) do
  # Return image block for LLM
  [%{
    type: "image",
    source: %{
      type: "base64",
      media_type: "image/png",
      data: screenshot_data
    }
  }]
end

defp build_screenshot_section(_), do: []
```

### Success Criteria:
- [ ] Screenshots captured synchronously
- [ ] Screenshots included in every context
- [ ] Agent can see visual state
- [ ] No screenshot spam (reasonable cooldown)

### Files:
- `assets/js/wireframe_hooks.js` (+50)
- `lib/koalemos/lenses/wireframe_editor/core.ex` (+50)

---

## PHASE 6: provide_context Integration

**Goal:** Context always shows current state, highlights differences from designed
**Timeline:** Day 3-4
**Estimated:** ~200 lines

### Implementation:

#### 1. State Capture Before Context (~50 lines)
**Location:** `lib/koalemos/lenses/wireframe_editor/core.ex`

**Update provide_context:**
```elixir
def provide_context(state, config \\ %{}) do
  routine_id = get_in(state, [:context, :routine_id])
  lens_state = get_in(state, [:context, :lens_state]) || %{}

  # CAPTURE CURRENT STATE FIRST (blocking)
  running_state = case capture_current_state(routine_id) do
    {:ok, state} -> state
    {:error, reason} ->
      Logger.warn("[WireframeEditor] Failed to capture state: #{inspect(reason)}")
      %{}  # Use empty running state if capture fails
  end

  # Update lens_state with running state
  lens_state = Map.put(lens_state, :running, running_state)

  designed = Map.get(lens_state, :designed, %{})

  # Build context sections
  context_parts = [
    build_design_dom_section(designed),
    build_live_dom_section(designed, running_state),
    build_functions_section(designed),
    build_variables_section(designed, running_state),
    build_css_section(designed),
    build_init_scripts_section(designed),
    build_console_section(running_state),
    build_tools_guide()
  ]

  # Add screenshot if available
  screenshot_blocks = build_screenshot_section(running_state)

  text_context = Enum.join(Enum.reject(context_parts, &is_nil/1), "\n\n")

  # Return text + screenshot
  [%{type: "text", text: text_context}] ++ screenshot_blocks
end
```

#### 2. Enhanced Context Sections (~150 lines)

**Update build_live_dom_section:**
```elixir
defp build_live_dom_section(designed, running) do
  designed_tree = Map.get(designed, :dom_tree)
  running_tree = Map.get(running, :dom_tree)
  captured_at = Map.get(running, :captured_at)

  cond do
    is_nil(running_tree) ->
      """
      === LIVE DOM STATE ===

      Status: NOT CAPTURED (preview may not be running)
      """

    running_tree == designed_tree ->
      age = format_timestamp_age(captured_at)
      """
      === LIVE DOM STATE (captured #{age}) ===

      Status: MATCHES DESIGN ✓

      The preview is showing exactly what you've designed. No runtime changes.
      """

    true ->
      age = format_timestamp_age(captured_at)
      diff = compute_dom_diff(designed_tree, running_tree)

      """
      === LIVE DOM STATE (captured #{age}) ===

      Status: DIFFERS FROM DESIGN ⚠️

      Changes from designed state:
      #{format_dom_diff(diff)}

      NOTE: These changes are EPHEMERAL (from JavaScript or interactions).
      Use design tools to make them PERMANENT if desired.

      Complete Current DOM:
      #{format_dom_tree(running_tree, 0, %{})}
      """
  end
end

defp compute_dom_diff(designed, running) do
  # Simple diff algorithm:
  # - Compare IDs to find added/removed/modified elements
  # - Track attribute changes
  # - Track content changes
  %{
    added: find_added_elements(designed, running),
    removed: find_removed_elements(designed, running),
    modified: find_modified_elements(designed, running)
  }
end

defp format_dom_diff(diff) do
  parts = []

  if length(diff.added) > 0 do
    parts = parts ++ [
      "Added:",
      Enum.map_join(diff.added, "\n", fn el ->
        "  + Element ##{el.id} <#{el.tag}>"
      end)
    ]
  end

  if length(diff.removed) > 0 do
    parts = parts ++ [
      "Removed:",
      Enum.map_join(diff.removed, "\n", fn el ->
        "  - Element ##{el.id} <#{el.tag}>"
      end)
    ]
  end

  if length(diff.modified) > 0 do
    parts = parts ++ [
      "Modified:",
      Enum.map_join(diff.modified, "\n", fn change ->
        "  ~ Element ##{change.id}: #{change.description}"
      end)
    ]
  end

  Enum.join(parts, "\n\n")
end
```

**Update build_console_section:**
```elixir
defp build_console_section(%{console_output: logs}) when length(logs) > 0 do
  recent_logs = Enum.take(logs, -20)  # Last 20 messages

  errors = Enum.filter(recent_logs, &(&1.level == "error"))
  warnings = Enum.filter(recent_logs, &(&1.level == "warn"))

  header = if length(errors) > 0 do
    "=== CONSOLE OUTPUT (#{length(errors)} ERRORS) ⚠️ ==="
  else
    "=== CONSOLE OUTPUT (last #{length(recent_logs)} messages) ==="
  end

  log_list = Enum.map_join(recent_logs, "\n", fn log ->
    level = String.upcase(Map.get(log, :level, "log"))
    message = Map.get(log, :message, "")
    timestamp = format_timestamp_age(Map.get(log, :timestamp))

    icon = case level do
      "ERROR" -> "❌"
      "WARN" -> "⚠️"
      _ -> "ℹ️"
    end

    "#{icon} [#{level}] (#{timestamp}) #{message}"
  end)

  """
  #{header}

  #{log_list}

  #{if length(errors) > 0, do: "NOTE: JavaScript errors detected! Check the error messages above.", else: ""}
  """
end

defp build_console_section(_), do: nil
```

### Success Criteria:
- [ ] Context always shows current state
- [ ] Differences highlighted clearly
- [ ] Console output visible with error highlighting
- [ ] Screenshot included
- [ ] Agent understands designed vs current
- [ ] Performance acceptable (<2s for full context)

### Files:
- `lib/koalemos/lenses/wireframe_editor/core.ex` (+200)

---

## PHASE 7: Integration Testing

**Goal:** Validate complete feedback loop with real scenarios
**Timeline:** Day 4-5
**Estimated:** ~200 lines

### Test Scenarios:

#### 1. Tic-Tac-Toe Test (Gold Standard)
**File:** `test/koalemos/lenses/wireframe_editor/tic_tac_toe_test.exs`

```elixir
defmodule Koalemos.Lenses.WireframeEditor.TicTacToeTest do
  use ExUnit.Case
  alias Koalemos.Lenses.WireframeEditor

  test "agent can play tic-tac-toe game it built" do
    # 1. Agent builds game
    # 2. Agent triggers click on position 0 (top-left)
    # 3. Verify agent sees:
    #    - Updated DOM (cell has X)
    #    - Console log about move
    #    - Screenshot showing X
    # 4. Agent makes O move
    # 5. Verify state updated
    # 6. Continue until win/draw
  end
end
```

#### 2. Form Interaction Test
**File:** `test/koalemos/lenses/wireframe_editor/form_interaction_test.exs`

```elixir
test "agent sees form validation errors and fixes them" do
  # 1. Agent builds login form with validation
  # 2. Agent triggers fill_input with invalid data
  # 3. Verify agent sees:
  #    - Error message in DOM
  #    - Console error about validation
  #    - Screenshot showing error state
  # 4. Agent fixes validation logic
  # 5. Agent retests with valid data
  # 6. Verify success state
end
```

#### 3. Error Recovery Test
**File:** `test/koalemos/lenses/wireframe_editor/error_recovery_test.exs`

```elixir
test "agent sees JavaScript errors and fixes them" do
  # 1. Agent adds function with typo
  # 2. Agent triggers interaction that calls function
  # 3. Verify agent sees console error
  # 4. Agent fixes the typo
  # 5. Agent retries interaction
  # 6. Verify success (no error)
end
```

#### 4. Complex Interaction Chain Test
**File:** `test/koalemos/lenses/wireframe_editor/integration_chain_test.exs`

```elixir
test "complete tool chain works end-to-end" do
  # 1. Agent adds button (modify_elements)
  # 2. Agent adds click handler (manage_handlers)
  # 3. Agent adds function handler calls (manage_functions)
  # 4. Agent adds variable function modifies (manage_variables)
  # 5. Agent tests with trigger_interaction
  # 6. Verify all changes visible in context
end
```

### Success Criteria:
- [ ] Tic-tac-toe test passes
- [ ] Form interaction test passes
- [ ] Error recovery test passes
- [ ] Complex chain test passes
- [ ] All 950+ tests still passing
- [ ] No regressions

### Files:
- `test/koalemos/lenses/wireframe_editor/tic_tac_toe_test.exs` (NEW, +50)
- `test/koalemos/lenses/wireframe_editor/form_interaction_test.exs` (NEW, +50)
- `test/koalemos/lenses/wireframe_editor/error_recovery_test.exs` (NEW, +50)
- `test/koalemos/lenses/wireframe_editor/integration_chain_test.exs` (NEW, +50)

---

## PHASE 8: Documentation & Wrap-Up

**Goal:** Document what we built, prepare for Sprint 8
**Timeline:** Day 5
**Estimated:** ~2 hours

### Tasks:

1. **Sprint 7 Summary**
   - `docs/sprints/sprint-7-summary.md`
   - What we built
   - How feedback loop works
   - Architecture diagrams
   - Testing results
   - Line count metrics

2. **Update Tracking Docs**
   - `docs/milestones/M4.md` - Mark Sprint 7 complete (7 of 8)
   - `docs/BACKLOG.md` - Update M4 status
   - `docs/wireframe-editor-test-plan.md` - Add feedback loop tests

3. **Sprint 8 Planning Preview**
   - What's left for M4?
   - Context enhancements
   - Testing utilities
   - Agent-as-node pattern
   - Final M4 polish

### Success Criteria:
- [ ] All documentation current
- [ ] Sprint 7 complete and ready to merge
- [ ] Clear path to Sprint 8

### Files:
- `docs/sprints/sprint-7-summary.md` (NEW)
- `docs/milestones/M4.md` (update)
- `docs/BACKLOG.md` (update)
- `docs/wireframe-editor-test-plan.md` (update)

---

## Sprint 7 Success Criteria

At completion, we should have:

**Functionality:**
- [ ] All 9 tools working (including trigger_interaction)
- [ ] Agent sees current DOM state before every LLM request
- [ ] Agent sees console output (errors, logs, warnings)
- [ ] Agent sees screenshots of visual state
- [ ] Differences from designed state highlighted in context
- [ ] Can play tic-tac-toe with agent-built game

**Quality:**
- [ ] All tests passing (950+ of 952)
- [ ] No regressions from Sprint 6
- [ ] Performance acceptable (<2s per context capture)
- [ ] Error handling robust (timeouts, missing previews)

**Documentation:**
- [ ] Sprint 7 plan complete (this document)
- [ ] Sprint 7 summary complete
- [ ] M4 milestone tracking updated
- [ ] Architecture documented

**Ready for Sprint 8:**
- [ ] Clean commit history
- [ ] All documentation current
- [ ] Clear Sprint 8 scope defined

---

## Line Count Estimate

**Code:**
- Phase 2: State snapshot (~200)
- Phase 3: trigger_interaction (~150)
- Phase 4: Console integration (~150)
- Phase 5: Screenshot integration (~100)
- Phase 6: provide_context (~200)

**Tests:**
- Phase 7: Integration tests (~200)

**Total:** ~1,000 lines

---

## Risk Mitigation

**Risk:** State capture timeout (preview doesn't respond)
**Mitigation:** 5-second timeout, use stale data if available, clear error message

**Risk:** Screenshot capture failure (html2canvas issues)
**Mitigation:** Skip screenshot gracefully, continue with text context only

**Risk:** Console spam (infinite loops)
**Mitigation:** ConsoleCache already has rate limiting (15/sec), duplicate detection

**Risk:** Performance (2s is too slow)
**Mitigation:** Profile and optimize, consider async patterns if needed

**Risk:** DOM diff complexity (very large DOMs)
**Mitigation:** Truncate to first 100 elements, provide summary instead of full tree

---

## Open Questions

1. **DOM Diff Format:** Text diff or structured highlights?
   - **Decision:** Start with structured (added/removed/modified), refine based on testing

2. **Screenshot Size:** Full size or thumbnail in context?
   - **Decision:** Test both, pick based on LLM performance and token usage

3. **Console Rate Limiting:** 15/sec good or need to tune?
   - **Decision:** Start with flo's 15/sec limit, adjust if needed

4. **Snapshot Timeout:** 5 seconds enough?
   - **Decision:** Start with 5s, can increase if needed

5. **Context Size:** How much DOM to include if very large?
   - **Decision:** First 100 elements with "... truncated" message

---

## Dependencies

**External:**
- html2canvas (already loaded in preview)
- ConsoleCache (already exists)
- ScreenshotCache (already exists)
- DOMStateCache (already exists)

**Internal:**
- WireframeEditor core (Sprint 4-6)
- WireframePreviewLive (Sprint 4-6)
- JavaScriptUpdater hook (Sprint 6)

---

## Next Sprint Preview (Sprint 8)

After Sprint 7 completes, Sprint 8 will focus on:

1. **Context Enhancements:**
   - Modification history tracking
   - Context-aware suggestions
   - Better DOM tree visualization

2. **Testing Utilities:**
   - Test helpers for wireframe manipulation
   - Fixture management
   - Assertion helpers

3. **Agent-as-Node Pattern:**
   - Complex multi-step operations
   - Tool chain orchestration
   - Sub-routine pattern

4. **Final M4 Polish:**
   - Documentation completion
   - M4 tagging (v0.4.0)
   - Preparation for M5

---

**Status:** Planning Complete ✅
**Next Step:** Begin Phase 1 (Documentation) → Phase 2 (Implementation)
