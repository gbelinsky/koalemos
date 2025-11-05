# Sprint 4 Summary: WireframeEditor Preview Infrastructure

**Completed:** November 5, 2025
**Branch:** `feature/m4-4-wireframe-preview`
**Lines Added:** ~340 lines

## Overview

Sprint 4 pivoted from the original plan to focus on infrastructure and validation. Instead of implementing DOM tools immediately, we built the foundation for live wireframe preview and validated that our parsing and lens integration works correctly.

## What We Built

### 1. WireframePreviewLive (~170 lines)
**File:** `lib/koalemos_web/live/wireframe_preview_live.ex`

A LiveView that renders inside an iframe to display wireframe previews. Key features:
- **LiveView-in-iframe architecture** (adopted from flo's proven pattern)
- Subscribes to PubSub topic `"wireframe_updates:#{routine_id}"` for DOM tree updates
- Loads initial DOM tree from WireframeStateCache on mount
- Recursively renders DOM tree as HTML with proper escaping
- Uses `Plug.HTML.html_escape()` for safe HTML attribute and content rendering

**Why LiveView instead of static HTML?**
- Enables live updates without iframe reload (preserves JavaScript state)
- Provides smooth transitions when agent modifies wireframe
- Sets foundation for interactive features (click handlers, element selection)

### 2. WireframeStateCache (~80 lines)
**File:** `lib/koalemos/caches/wireframe_state_cache.ex`

ETS-based cache for storing lens_state by routine_id. Solves a critical timing issue:

**Problem:** PubSub broadcast happens BEFORE iframe mounts and subscribes
**Solution:** Cache stores lens_state so preview can fetch it on mount

Features:
- Simple get/put/delete API
- Automatic cleanup of entries older than 1 hour
- Added to application supervision tree

### 3. WireframeTestLive Updates (~50 lines)
**File:** `lib/koalemos_web/live/wireframe_test_live.ex`

Updated the test page to use the new preview architecture:
- Changed from `srcdoc` to `src="/wireframe-preview/:routine_id"`
- Generates unique routine_id on page load
- Stores lens_state in cache before rendering iframe
- Broadcasts DOM tree updates via PubSub
- Shows "Agent Context" tab with output from `provide_context/2`

### 4. WireframeTestRoutine Tool Execution (~40 lines)
**File:** `lib/koalemos/routines/wireframe_test_routine.ex`

Added tool execution infrastructure (pattern from TestChatRoutine):
- New steps: `build_tool_schema`, `tool_lookup`, `tool_execution`
- Tool execution loop: `parse_response → tool_lookup → tool_execution → build_tool_schema`
- Ready for tool integration (just needs tools defined)
- Updated initial_context to include WireframeEditor lens
- Increased max_tokens to 64000 for wireframe context

**Tests Updated:** All 15 wireframe routine tests passing

### 5. Route Updates
**File:** `lib/koalemos_web/router.ex`

Added new route for preview LiveView:
```elixir
live "/wireframe-preview/:routine_id", WireframePreviewLive
```

## Key Decisions

### 1. Adopted flo's Architecture
**Decision:** Use LiveView-in-iframe instead of simple HTML serialization

**Rationale:**
- Flo's architecture is proven to work for similar use case
- Enables live updates without page reload
- Better user experience for agent-driven modifications
- Sets foundation for interactive features

### 2. Infrastructure Before Tools
**Decision:** Build preview system before implementing DOM tools

**Rationale:**
- Need to validate that parsing and preview work correctly
- Tools are useless without a way to see their effects
- Discovered and fixed HTML escaping issues early
- Test page now ready to test tools as we add them

### 3. PubSub + Cache Strategy
**Decision:** Combine PubSub for updates with cache for initial state

**Rationale:**
- PubSub alone has timing issue (broadcast before subscription)
- Cache solves timing while preserving PubSub for updates
- Both patterns will be useful as system grows

## Technical Challenges & Solutions

### Challenge 1: HTML Escaping Errors
**Problem:** `Phoenix.HTML.html_escape()` returns `{:safe, string}` tuples, causing type errors in string concatenation

**Solution:**
- Use `Plug.HTML.html_escape()` for plain strings
- Refactor recursive rendering to return plain strings
- Only wrap in `Phoenix.HTML.raw()` at top level

### Challenge 2: Timing Issue with PubSub
**Problem:** iframe mounts AFTER initial PubSub broadcast, missing first DOM tree

**Solution:**
- Create WireframeStateCache
- Store lens_state before rendering iframe
- Preview fetches from cache on mount
- Still broadcast for any already-mounted previews

### Challenge 3: Test Isolation
**Problem:** EngineManagerTest has pre-existing flakiness with routine cleanup

**Status:** Not fixed (unrelated to Sprint 4 work)
- 1 test fails due to other tests leaving routines running
- All Sprint 4 tests pass (15/15 wireframe routine tests)
- Deferred to future cleanup sprint

## Validation Results

### ✅ Parsing Works
- Simple, medium, and complex wireframes all parse correctly
- ParsingIntegration extracts DOM tree, CSS, and JavaScript
- No errors loading any sample wireframe

### ✅ Preview Works
- LiveView renders DOM tree as HTML
- All three sample wireframes display correctly in iframe
- No HTML escaping issues
- Preview updates via PubSub (tested manually)

### ✅ Context Works
- `provide_context/2` shows complete DOM tree to agent
- Context includes elements, attributes, classes, content
- Agent can see structure needed to make informed modifications

### ✅ Tool Execution Ready
- Routine has ToolLookup and ToolExecution steps
- Transitions configured for tool loop
- Just needs tools defined in lens

## What's Deferred

### To Sprint 5: Core Module + DOM Tools
The original Sprint 4 plan included:
- WireframeEditor Core module
- DOM Handler module
- DOM tools (query_element, add_element, modify_element, etc.)

**Reason for deferral:** Infrastructure and validation took priority. Better to have working preview before building tools.

**Plan for Sprint 5:**
- Implement WireframeEditor Core module
- Implement DOM Handler module
- Add 5-7 DOM manipulation tools
- Wire tools into test page for manual testing

## Metrics

**Lines Added:** ~340 lines
**Tests Passing:** 15/15 wireframe routine tests
**Files Created:** 2 (WireframePreviewLive, WireframeStateCache)
**Files Modified:** 4 (WireframeTestLive, WireframeTestRoutine, router, application)
**Manual Validation:** ✅ All sample wireframes render correctly

## Lessons Learned

### 1. Validate Infrastructure Early
Building preview system first helped us discover HTML escaping issues and timing problems before implementing tools. This approach saved time.

### 2. Adopt Proven Patterns
Using flo's LiveView-in-iframe pattern gave us confidence and a working example to reference. No need to reinvent the wheel.

### 3. Test Infrastructure Catches Issues
The test page made it easy to spot problems visually and validate fixes immediately. Interactive testing is invaluable.

### 4. Pivot When Needed
Original plan called for DOM tools in Sprint 4, but infrastructure needs revealed themselves during implementation. Pivoting was the right call.

## Next Sprint Preview

**Sprint 5 Focus:** Implement actual WireframeEditor functionality
- Core module with lens behavior
- DOM Handler for element manipulation
- 5-7 DOM tools (query, add, modify, remove, etc.)
- Wire tools into test page for manual validation
- Tool execution through agent loop

**Goal:** Enable agent to actually modify wireframes through tools, not just view them.
