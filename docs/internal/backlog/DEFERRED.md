# Deferred Improvements

**Decisions made during development - documented for future consideration**

---

## Architecture & Design

### Engine.Observer Refactoring
**Status:** Deferred (ported as-is in Phase 2)

During Phase 2, we considered splitting Observer (312 lines) into three modules:
1. **Observer** - Core GenServer, event recording, file writing
2. **EventSerializer** - Handle JSON serialization of complex types
3. **MessageTracker** - Track message changes and broadcast only new messages

**Why deferred:** Module is large but cohesive. Refactoring would add complexity without clear immediate benefit.

### Observer Serialization
**Status:** Ported as-is, needs revisit

Current JSON serialization has known issues:
- Inconsistent atom/string key handling
- Loss of type information
- Hard to deserialize back into useful structures

**Better alternatives to consider:**
- Jason with custom encoders
- Structured event format with explicit type tags
- Telemetry events instead of custom serialization

### Orchestrator Refactoring
**Status:** Ported as-is in Phase 4

The Orchestrator (489 lines) could be split into:
- StepExecutor - Handle step execution
- TransitionManager - Handle transitions
- SubRoutineManager - Handle sub-routine stack

**Why deferred:** Module is cohesive, step completion immediately triggers transitions - coupling is natural.

### ContextManager Nested Updates
**Status:** Tech debt identified

ContextManager only supports top-level updates. When updating nested maps like `lens_state`, steps must manually merge. Consider adding `put_in` operation.

---

## UI & UX

### WireframeEditor Context Display & State Capture
**Status:** Deferred

"Show Agent Context" UI and LLM requests capture state independently, resulting in duplicate snapshots and inconsistent views.

**Better architecture:** Store actual sent context in routine state, UI retrieves exactly what agent saw.

### Live DOM Snapshot Scope & Format
**Status:** Deferred

Current snapshot captures entire iframe body including LiveView wrapper elements. Should only capture wireframe root. Also, designed and live DOM use inconsistent format.

### WireframeEditor Inline DOM Diff Highlighting
**Status:** Deferred from M4 Sprint 7 Phase 6

Attempted inline diff markers (`+` for added, `~` for modified) but inline display proved complex due to recursive tree formatting.

**Current state:** Agent receives both trees + status line indicating differences.

---

## Testing & Infrastructure

### JavaScript Parser Unit Tests
**Status:** Deferred

`priv/nodejs/js_parser.js` has no JavaScript-level unit tests. Only tested indirectly through 28 Elixir integration tests.

**Desired:** Add Jest tests for better unit-level debugging.

### UI-to-Lens Communication Pattern
**Status:** Design needed

No clean pattern for UI elements to directly interact with lenses. All communication goes through full agent loop.

**Potential patterns:**
- Lens-Scoped External Events
- Lens Control API
- Enhanced External Events with Lens Routing

---

## Tool & Lens System

### Lens Tool Execution Request/Result Pairs
**Status:** Deferred

Tool calls contain full argument details, then same information appears in context. This creates duplicate information.

**Future architecture:** Lens returns both stripped request summary and full result. Message array stores the pair without redundancy.

### WireframeEditor Console Isolation
**Status:** Using discipline-based approach

Console interception captures ALL console output including infrastructure logging. Agent sees infrastructure messages instead of just wireframe output.

**Current approach (Option C):** INFRASTRUCTURE_CONSOLE constant - requires discipline.

**Future:** Option A (Nested LiveView Iframes) for proper isolation.

---

## Known Test Failures

### Test Failure: engine_manager_test "list_routines/0 returns empty list"
**Status:** Pre-existing, parallel test execution issue
**File:** `test/koalemos/engine_manager_test.exs:113`

Test expects empty routine list, but finds routines from other tests running in parallel.

**Recommendation:** Change test to be more realistic (check for specific routines, not empty list).

### Test Failures: Flaky Observer Tests
**Status:** Intermittent, timing-dependent
**Files:** `test/koalemos/engine/observer_test.exs`

Two tests occasionally fail depending on test execution order:
1. "record_event/1 - handles events without routine_id"
2. "serialization handles complex nested structures"

**Root cause:** Tests share Observer GenServer, parallel execution causes event interleaving.

**Recommendation:** Use `start_supervised/1` to create test-specific Observer instances.

---

## Performance

### Screenshot System Simplification
**Status:** Deferred

Current system works but has complexity:
- JavaScript hook captures DOM via html2canvas
- WebSocket events + PubSub messages
- ScreenshotCache stores Base64 PNG

**Why deferred:** System works correctly, need real-world usage patterns first.

### Logging Reduction
**Status:** Noted

Could make debug logging configurable, add structured logging, consider telemetry events.

---

## Future Implementation Notes

### Remove V4 Suffix
After V4 is stable, rename to be the default (remove V3 entirely).

### Separate koalemos/koalemos_web
Create abstraction boundary - wireframe routines in koalemos shouldn't depend on KoalemosWeb.Servers.

### Live DOM Form Element Values
DOM snapshot captures attributes but not runtime form element values. Agent cannot see what user typed.

**Implementation:** Enhance `serializeDOM` to capture runtime values for form elements.
