# Koalemos - Development Backlog

**Last Updated:** October 28, 2025

---

## Milestone 1: Foundation ✅ COMPLETE

**Goal:** Project setup and core engine extraction

### Completed
- [x] Create new Phoenix project `koalemos`
- [x] Set up directory structure (engine/, routines/, subroutines/, steps/, lenses/)
- [x] Create project documentation (PRD, BACKLOG, ARCHITECTURE, NAMING, COVERAGE_LOG)
- [x] Initialize git repository
- [x] Create GitHub private repository
- [x] Initial commit and push
- [x] **Phase 1: Setup & Level 1 Modules** ✅
  - [x] Setup testing infrastructure (excoveralls, coverage config)
  - [x] Port Engine.ContextManager (100% coverage, 193 lines)
  - [x] Port Engine.EventBuffer (100% coverage, 297 lines)
  - [x] Update documentation (BACKLOG, COVERAGE_LOG)

### Completed (continued)
- [x] **Phase 2: Level 2 Modules** ✅
  - [x] Port Engine.StepUtils (100% coverage, 197 lines)
  - [x] Port Engine.Observer (80.5% coverage, 312 lines)
  - [x] Update documentation (BACKLOG, COVERAGE_LOG)
- [x] **Phase 3: Level 3 Modules** ✅
  - [x] Port Engine.EventRecorder (100% coverage, 137 lines)
  - [x] Update documentation (BACKLOG, COVERAGE_LOG)
- [x] **Phase 4: Level 4 Modules** ✅
  - [x] Port Engine.Orchestrator (79.2% coverage, 489 lines) - Execution heart
  - [x] Update documentation (BACKLOG, COVERAGE_LOG)
- [x] **Phase 5: Level 5 Modules** ✅
  - [x] Port Engine.EventHandler (97.5% coverage, 309 lines)
  - [x] Port Engine (86.6% coverage, 293 lines)
  - [x] Port EngineManager (83.3% coverage, 289 lines) - renamed from Engine.Registry
  - [x] Update Application.ex (add Registry and Observer to supervision tree)
  - [x] Fix test failures with unique IDs and proper cleanup (235 tests pass)
  - [x] Update documentation (BACKLOG, COVERAGE_LOG)

### Todo
- [x] **Phase 6a: Foundation Steps** ✅
  - [x] Utils.MessageBuilder (211 lines, 94.1% coverage)
  - [x] Steps.System.Config (37 lines, 100% coverage)
  - [x] Steps.System.Action (48 lines, 100% coverage)
  - [x] Steps.Agent.LensRendering (67 lines, 93.7% coverage)
- [x] **Phase 6b: User Input** ✅
  - [x] Steps.User.ChatUserInput (174 lines, 78.3% coverage, 24 tests)
- [x] **Phase 6c: Tool System** ✅
  - [x] Steps.Agent.ToolSchema (119 lines, 96.4% coverage, 12 tests)
  - [x] Steps.Agent.ToolLookup (122 lines, 100% coverage, 11 tests)
  - [x] Steps.Agent.ToolExecution (131 lines, 100% coverage, 15 tests)
- [x] **Phase 6c-refactor: Tool Result Images** ✅
  - **Summary:** Made tools self-contained by letting them return images in their results. Cleaner architecture and better separation of concerns.
  - **Changes:**
    - [x] Removed ScreenshotCache logic from ToolExecution (~22 lines)
    - [x] Extended tool result format to support content blocks (images + text)
    - [x] Tools can now return: `{content_blocks, lens_updates, metadata}`
    - [x] Content blocks format: `[{:text, "result"}, {:image, base64, media_type}]`
    - [x] Updated MessageBuilder.build_tool_result_message to accept content blocks
    - [x] Maintained backward compatibility: string results still work
    - [x] Added 7 new tests for content block format
  - **Results:**
    - ToolExecution: 182 lines → 131 lines (28% reduction), coverage 88% → 100%
    - MessageBuilder: 211 lines → 230 lines (new functionality), coverage 94.1% → 92.1%
    - Overall: 355 tests pass (was 351)
- [ ] **Phase 6d: LLM Integration** (~1,531 lines total)

  **Architecture Decisions:**
  - **Multi-provider support is NON-NEGOTIABLE** - Must support Anthropic, OpenAI, and Ollama
  - **Plugin architecture** - Providers are pluggable modules with common interface
  - **Anthropic is first plugin** - Other providers follow same pattern
  - **Credential management required** - File-based storage with OAuth support

  **Sub-phases:**
  - [x] **Phase 6d-1: Credential Management** ✅ (~574 lines)
    - [x] DemoCredentialStore (312 lines, 82.6% coverage, 22 tests)
    - [x] SimpleCredentialManager (269 lines, 58.6% coverage, 15 tests)
    - [x] Supervision tree integration
    - [x] Credential file format: `.koalemos/.credentials.json`

  - [x] **Phase 6d-2: Response Parsing** ✅ (~94 lines)
    - [x] Steps.Agent.ResponseParsing (94 lines, 100% coverage, 15 tests)
    - [x] Extract tool calls from LLM response
    - [x] Build assistant message
    - [x] Usage metadata passthrough

  - [x] **Phase 6d-3: Plugin Architecture** ✅ (~150 lines)
    - [x] LLMProvider behavior - Define plugin interface
    - [x] LLMProvider.Utils - Common message utilities
    - [x] Steps.Agent.LLMRequest - Provider router step
    - [x] docs/LLM_PROVIDER_GUIDE.md - Provider implementation guide
    - [x] Achieved: 70.8% coverage (router), 100% (utils, stubs)

  - [x] **Phase 6d-4: Anthropic Provider** ✅ (~198 lines)
    - [x] LLMProviders.Anthropic - First plugin implementation
    - [x] Native Anthropic message format
    - [x] API key and OAuth authentication
    - [x] Progressive retry logic
    - [x] Achieved: 70.5% coverage (acceptable for HTTP client), 13 tests

  - [x] **Phase 6d-5: OpenAI Provider** ✅ (~485 lines)
    - [x] LLMProviders.OpenAI - Second plugin (~400 lines)
    - [x] ToolSchemaConverter (~85 lines) - Anthropic ↔ OpenAI schema conversion
    - [x] Message format conversion (text, tool_use, tool_result)
    - [x] Response conversion (OpenAI → Anthropic format)
    - [x] System prompt handling
    - [x] Achieved: ToolSchemaConverter 100%, OpenAI 57.2%, 21 tests

  - [x] **Phase 6d-6: Ollama Provider & Format Converter** ✅ (~726 lines)
    - [x] OpenAIFormatConverter - Shared conversion logic (357 lines, 91.3% coverage, 20 tests)
    - [x] Refactored OpenAI provider to use converter (reduced from 400 to 152 lines, 78.9%)
    - [x] LLMProviders.Ollama - Third plugin (149 lines, 86.8% coverage, 16 tests)
    - [x] Reuses OpenAI format conversion (DRY principle)
    - [x] Local endpoint support (http://localhost:11434)
    - [x] Reasoning model support (qwen3, deepseek-r1, gpt-oss)
    - [x] Real API testing with user's Ollama server
    - [x] Achieved: 86.8% coverage for Ollama, 91.3% for converter

  - [x] **Phase 6d-7: Lens-Based Image Context Handling** ✅ (~161 insertions, 246 deletions)
    - [x] Updated LensRendering to separate text and image contexts
    - [x] Updated all providers (Anthropic, OpenAI, Ollama) to prepend image contexts
    - [x] Removed keep_only_last_screenshot logic from Utils (51 lines deleted)
    - [x] Lenses can now return images in provide_context()
    - [x] Images prepended as user messages (not saved to history)
    - [x] Simplified screenshot handling - lens decides when to provide images
    - [x] Updated 11 files, 493 tests passing

- [x] **Phase 7: Integration Testing** ✅ (~650 lines test code)
  - [x] Phase 7a: Basic Engine Integration (10 tests, 150 lines)
    - [x] Single-step and multi-step routine execution
    - [x] Registry integration (start, lookup, stop)
    - [x] Context flow between steps
    - [x] Error handling
  - [x] Phase 7b: Full Agent Loop Integration (4 tests + framework, 220 lines)
    - [x] Real API integration tests (Anthropic, Ollama)
    - [x] Test lens with tools (echo, add, fail)
    - [x] Marked with @moduletag :real_api (excluded by default)
  - [x] Phase 7c: Real API Fixes (6 files, ~150 lines)
    - [x] Fixed LLM provider return format (context diff format)
    - [x] Removed Flo credential dependencies
    - [x] Fixed credential manager startup in tests
    - [x] Fixed context diff application in tests
    - [x] Updated provider tests for new format
  - [x] **Final Results:**
    - [x] 507 tests passing (all providers, all steps)
    - [x] 4 real API tests work with live credentials
    - [x] Clean credential management (.koalemos/.credentials.json)
    - [x] Verified with real Anthropic API ✅

---

## Development Workflow (Starting M2)

**Branch Strategy:**
- `main` - Production-ready releases (tagged milestones)
- `develop` - Integration branch for completed features
- `feature/*` - Feature branches off `develop`

**Process:**
1. Create feature branch: `git checkout -b feature/m2-ui-foundation develop`
2. Develop and test
3. Create PR: `feature/m2-*` → `develop`
4. Code review
5. Merge to `develop`
6. When milestone complete: `develop` → `main` (tag release)

---

## Milestone 2: UI Foundation + Simple Agent Loop ✅ COMPLETE

**Goal:** Chat with AI works (text-only, no screenshots)

**Status:** Completed October 29, 2025

**Why This Scope:**
- Proves complete architecture flow without screenshot complexity
- Tests engine → routine → lens → LiveView integration
- Derisks M3+ by validating design early
- Generic chat interface works with ANY routine (not wireframe-specific)

**Strategy:** Component-by-component, bottom-up build. Port working components where possible, break monolithic components into smaller pieces.

**Detailed Planning:** See [docs/milestones/M2.md](./milestones/M2.md) for sprint breakdown and component architecture.

**High-Level Components:**
- [x] **Foundation** - Layouts, core components, minimal app.js
- [x] **Message Cards** - UserCard, AssistantCard, ErrorCard, ImageGallery (break down monolith)
- [x] **Input & Feed** - UserInputComponent (port), MessageFeed (new)
- [x] **Chat Panel** - Combine feed + input
- [x] **Pages** - HomePage, StartSessionModal, RoutineChatLive
- [x] **Backend** - TestChatRoutine (simple agent loop), TestLens
- [x] **Integration** - Loading states, autofocus, debug cleanup

**Dependencies:** M1 only

**Test Criteria:**
- ✅ Navigate to home page
- ✅ Click "Start Chat" → modal opens
- ✅ Start session → navigates to chat page
- ✅ Type message, see in chat
- ✅ AI responds with message
- ✅ Multi-turn conversation works
- ✅ Routine status displays correctly
- ✅ No errors, smooth flow

**Lines:** ~2,250 (7 sprints, ~300 lines each)
**Status:** ✅ **COMPLETE** (October 29, 2025)

---

## Milestone 3: Infrastructure Layer 🏗️ IN PROGRESS

**Status:** Planning Complete → Sprint 1 Starting
**Started:** October 29, 2025

**Goal:** Screenshot capture + HTML parsing work independently

**Why Together:**
- Both are infrastructure needed by M4
- Can be tested separately (no interdependency)
- Large milestone but two independent tracks (could parallelize)

### M3 UX Improvements (Deferred from M2)

**Goal:** Polish chat interface and provider configuration

**Components:**

- [ ] **Compact Config Display**
  - Move provider/model info next to title (2 lines, small text)
  - Show actual routine config (not URL params) ✅ Fixed in M2
  - Keep unobtrusive, doesn't increase header height
  - Remove debug panel from production

- [ ] **Provider-Specific Configuration Panels**
  - **Ollama:**
    - Fetch available models from `/api/tags` endpoint
    - Display model list in dropdown
    - Show model size/parameters info
    - Real-time availability check
  - **Anthropic:**
    - Update API key UI
    - Show current key status (valid/invalid/missing)
    - OAuth token refresh status
  - **OpenAI:**
    - Update API key UI
    - Model selection with descriptions
    - Organization ID support (optional)

- [ ] **Enhanced Start Session Modal**
  - Provider-specific configuration UI
  - Model selection based on provider
  - Persist last-used configuration
  - Configuration validation before starting

- [ ] **Better Error Handling**
  - User-friendly error messages
  - Retry mechanisms for transient failures
  - Network status indicators
  - Model availability warnings

**Dependencies:** M2 (chat interface complete)
**Lines:** ~400-600 (mostly UI components)
**Status:** Deferred - Will plan during M3

---

### Code Quality & Coverage Review (Future Task)

**Goal:** Audit codebase for unused code and coverage gaps

**Observations:**
- Some ported components may not be used and lowering overall coverage
- Some actively used components are under-tested
- Need systematic review to identify:
  - Dead code to remove
  - Under-tested critical paths
  - Over-tested trivial code

**Tasks:**
- [ ] Run coverage report with detailed line-by-line analysis
- [ ] Identify unused modules/functions
- [ ] Identify coverage gaps in critical paths
- [ ] Create cleanup/testing plan
- [ ] Execute in focused sprint

**Status:** Future - Will schedule after M3 or M4

---

### Sprint Structure (8 sprints, ~3,000 lines)

**Strategy:** Sequential bottom-up (Screenshots → Parsing → UX)

- [x] **Sprint 1: Screenshot Foundation** (~220 lines) ✅ Oct 29
  - [x] ScreenshotCache GenServer (`lib/koalemos/caches/`)
  - [x] JavaScript hook scaffold (`assets/js/wireframe_hooks.js`)
  - [x] Supervision tree integration
  - [x] 15 tests, all passing

- [x] **Sprint 2: Screenshot Capture** (~470 lines) ✅ Oct 29
  - [x] JavaScript capture with html2canvas
  - [x] Test page at `/test/screenshot`
  - [x] PubSub communication (pushEvent)
  - [x] LiveView event handlers
  - [x] 9 tests, all passing

- [ ] **Sprint 3: Screenshot Tool** (~200 lines)
  - [ ] Tool in TestLens
  - [ ] Request → Capture → Retrieve
  - [ ] Integration tests

- [ ] **Sprint 4: HTML Parser** (~500 lines)
  - [ ] Semantic structure extraction
  - [ ] Use Floki (simplified from Flo)
  - [ ] Metadata extraction

- [ ] **Sprint 5: JavaScript Extractor** (~200 lines)
  - [ ] Extract inline scripts
  - [ ] Extract event handlers
  - [ ] List functions

- [ ] **Sprint 6: Cache GenServers** (~500 lines)
  - [ ] DOMStateCache
  - [ ] ConsoleCache
  - [ ] VariableStateCache
  - [ ] Supervision

- [ ] **Sprint 7: Parsing Integration** (~250 lines)
  - [ ] Parser → Caches
  - [ ] Integration tests
  - [ ] Data flow verification

- [ ] **Sprint 8: UX Polish & Testing** (~600 lines)
  - [ ] Compact config display
  - [ ] Provider panels (Ollama models, API keys)
  - [ ] Enhanced modal
  - [ ] Final integration

**See docs/milestones/M3.md for detailed sprint plans**

**Lines:** ~3,000 (8 sprints)
**Status:** Sprint 2 Complete ✅ → Sprint 3 Ready

---

## Milestone 4: WireframeEditor Lens + Supporting Lenses

**Goal:** Full lens system with rich context and tools

**Why This Scope:**
- All infrastructure ready (M2 UI, M3 screenshots/parsers)
- Focus purely on lens logic and tools
- Supporting lenses are small and straightforward

**Components:**
- [ ] **WireframeEditor Lens** (~2,000 lines)
  - [ ] Port from Flo (1,986 lines - may need adjustments)
  - [ ] Context generation (uses HTMLParser, caches)
  - [ ] Tool definitions (DOM manipulation, analysis)
  - [ ] Screenshot integration (uses M3 screenshot tool)
  - [ ] State management

- [ ] **Supporting Lenses** (~600 lines total)
  - [ ] PersonaLens (~200 lines) - Agent personality/instructions
  - [ ] Scratchpad (~100 lines) - Working memory
  - [ ] SequentialThinking (~250 lines) - Step-by-step reasoning
  - [ ] Workflow (~50 lines) - Phase management

- [ ] **Integration** (~400 lines)
  - [ ] Wire all lenses to test routine
  - [ ] Test tool execution
  - [ ] Test context generation
  - [ ] Verify screenshot flow

**Dependencies:** M2 (LiveView), M3 (screenshots + parsers)

**Test Criteria:**
- ✅ WireframeEditor provides context from parsed HTML
- ✅ Tools execute and manipulate DOM
- ✅ Screenshots captured when tool requests
- ✅ Supporting lenses integrate correctly
- ✅ Lens system works end-to-end

**Lines:** ~3,000
**Status:** Todo

---

## Milestone 5: WireframeDesign Routine (MVP Complete!)

**Goal:** End-to-end wireframe design with phases

**Why This Scope:**
- All dependencies satisfied (M2-M4)
- Final integration piece
- Completes MVP functionality

**Components:**
- [ ] **WireframeDesign Routine** (~600 lines)
  - [ ] Port from Flo (10KB original)
  - [ ] Phase definitions:
    - [ ] Discovery (requirements gathering)
    - [ ] Structure (HTML/CSS layout)
    - [ ] Behavior (JavaScript/interactivity)
    - [ ] Polish (visual design)
  - [ ] Phase transitions
  - [ ] Uses WireframeEditor lens
  - [ ] Uses all supporting lenses

- [ ] **HTML Upload** (~200 lines)
  - [ ] File upload component
  - [ ] Parse uploaded HTML
  - [ ] Initialize routine with HTML

- [ ] **Full Integration** (~200 lines)
  - [ ] Wire everything together
  - [ ] Complete workflow test
  - [ ] Error handling

**Dependencies:** M2-M4 (everything)

**Test Criteria:**
- ✅ Can start session with blank wireframe
- ✅ Can upload HTML wireframe
- ✅ AI guides through all phases
- ✅ Can make changes to wireframe
- ✅ Preview updates in real-time
- ✅ Screenshots work throughout
- ✅ Complete session works end-to-end

**MVP COMPLETE** ✅

**Lines:** ~1,000
**Status:** Todo

---

## Milestone 6: Polish & Production-Ready

**Goal:** Ship production-ready MVP!

**Why This Scope:**
- MVP complete from M5, now make it production-worthy
- UX polish for real users
- Deployment infrastructure
- Complete documentation

**Components:**
- [ ] **UI Polish** (~200 lines)
  - [ ] Landing page (start session, upload wireframe)
  - [ ] Loading states (LLM thinking, file upload)
  - [ ] Error handling (graceful failures, network errors)
  - [ ] Smooth transitions

- [ ] **Logging & Monitoring** (~100 lines)
  - [ ] Make debug logging configurable
  - [ ] Clean up excessive logs
  - [ ] Production-level logging
  - [ ] Error tracking setup

- [ ] **Docker & Deployment** (~200 lines)
  - [ ] Dockerfile (multi-stage build)
  - [ ] docker-compose.yml (easy local dev)
  - [ ] Environment configuration (.env.example)
  - [ ] Deploy to Fly.io

- [ ] **Documentation** (update existing docs)
  - [ ] README with quick start
  - [ ] CONTRIBUTING.md (branch workflow)
  - [ ] DEPLOYMENT.md (how to deploy)
  - [ ] Update ARCHITECTURE.md

**Dependencies:** M5 (complete MVP)

**Test Criteria:**
- ✅ Landing page looks professional
- ✅ No rough edges in UX
- ✅ Can deploy in < 5 minutes
- ✅ Docker container works
- ✅ Deployed app works in production
- ✅ Documentation is clear and complete

**SHIP IT!** 🚀

**Lines:** ~500
**Status:** Todo

---

## Deferred Improvements

**Decisions we made during porting - documented for future consideration**

### Engine.Observer Refactoring
**Status:** Deferred (ported as-is in Phase 2)

During Phase 2, we considered splitting Observer (312 lines) into three modules:
1. **Observer** - Core GenServer, event recording, file writing
2. **EventSerializer** - Handle JSON serialization of complex types (PIDs, functions, tuples)
3. **MessageTracker** - Track message changes and broadcast only new messages

**Why deferred:**
- Module is large but cohesive (all event observation)
- Code works well and is well-organized
- Refactoring would add complexity without clear immediate benefit
- Can revisit if maintenance becomes difficult

**Future considerations:**
- If we add more serialization types, extract EventSerializer
- If message tracking logic grows, extract MessageTracker
- Could improve testability with smaller modules

### Observer Serialization
**Status:** Ported as-is, needs revisit

The current JSON serialization in Observer has known issues and has caused problems in production:

**Current approach:**
- `make_serializable/1` recursively walks data structures
- Converts complex types (PIDs, functions, tuples, DateTime) to strings/lists
- Atom keys may or may not be converted depending on nesting
- Inconsistent behavior makes event data hard to work with

**Problems:**
- Inconsistent atom/string key handling causes test brittleness
- Loss of type information (everything becomes strings/lists)
- Hard to deserialize back into useful Elixir structures
- Recursive approach can be slow for large data structures

**Better alternatives to consider:**
1. **Use Jason with custom encoders:**
   ```elixir
   defimpl Jason.Encoder, for: [PID, Reference, Port, Function] do
     def encode(term, opts), do: Jason.Encode.string(inspect(term), opts)
   end
   ```

2. **Structured event format with explicit type tags:**
   ```elixir
   %{type: :pid, value: "#PID<0.123.0>"}
   %{type: :datetime, value: "2024-10-27T12:00:00Z"}
   ```

3. **Don't serialize complex types - log references only:**
   ```elixir
   # Instead of serializing the whole PID, just note that a PID was there
   %{metadata: %{had_pid: true}}
   ```

**Why deferred:**
- Serialization works for current use cases
- Fixing would require updating all event consumers
- Tests now handle the inconsistency
- Better to establish event patterns first, then optimize serialization

**Future considerations:**
- After porting all engine components, audit what data is actually being logged
- Consider using Erlang's `:erlang.term_to_binary/1` for faithful round-tripping
- May want different serialization for file logs vs PubSub broadcasts
- Telemetry events might eliminate need for custom serialization entirely

### Logging Reduction
**Status:** Noted during port

The Observer has minimal logging in the Koalemos port (removed excessive TRACE logs from Flo). Future work could:
- Make debug logging configurable via environment
- Add structured logging with log levels
- Consider using telemetry events instead of logs

### Screenshot System Simplification
**Status:** Deferred (M3 Sprint 3 implemented October 30, 2025)

The current screenshot system works but has complexity that could be simplified:

**Current architecture:**
- JavaScript hook captures DOM via html2canvas
- WebSocket events: LiveView → JS (trigger) and JS → LiveView (result)
- PubSub messages: Lens → LiveView (request) and LiveView → Lens (notification)
- ScreenshotCache stores Base64 PNG data
- Helper module coordinates the flow with timeout

**Works well:**
- Easy to use from lenses: `ScreenshotCapture.capture(routine_id)`
- Clean abstraction - comprehensive documentation
- Tested independently of tool execution
- Ready for M4 WireframeEditor lens

**Potential simplifications to consider:**
- Could the PubSub/WebSocket coordination be simplified?
- Is the timeout approach the best way to synchronize?
- Could we use a more direct LiveView → Lens callback?
- Is Base64 in-memory cache the right storage approach?

**Why deferred:**
- System works correctly and is well-tested
- Simple API for lenses (one function call)
- Need to use it in M4 to understand usage patterns
- Premature to optimize before seeing real-world usage

**Future considerations:**
- After M4 WireframeEditor implementation, revisit the flow
- Consider alternative coordination mechanisms
- Evaluate if complexity is justified by functionality
- Document any pain points discovered during M4

### UI-to-Lens Communication Pattern
**Status:** Design needed (identified October 30, 2025)

**Problem:**
Currently, there's no clean pattern for UI elements (buttons, controls) to directly interact with lenses. All communication goes through the full agent loop (UI → Engine → Routine → Steps → Agent → Lens). For testing and direct UI controls (like "take screenshot" button), we need a more direct path.

**Current workarounds:**
- External events that routines must explicitly handle
- Requires routine modification for each lens action
- No standard pattern or abstraction

**Design goals:**
1. UI should be able to trigger lens-specific actions
2. Pattern should be reusable across lenses
3. Should integrate cleanly with existing architecture
4. Should support both immediate actions and state updates

**Potential patterns:**

**Option A: Lens-Scoped External Events**
```elixir
# UI sends lens-scoped event
Engine.send_lens_event(routine_id, lens_module, :action, data)

# Lens implements optional callback
@callback handle_lens_event(action :: atom, data :: term, state :: map) ::
  {:ok, keyword()} | {:error, term()}

def handle_lens_event(:request_screenshot, _data, _state) do
  {:ok, lens_updates: [request_screenshot: true], trigger_turn: true}
end
```

**Option B: Lens Control API**
```elixir
# Dedicated lens control module
LensController.update_state(routine_id, TestLens, %{request_screenshot: true})
LensController.trigger_action(routine_id, TestLens, :capture_screenshot)

# Lenses declare supported actions
def supported_actions do
  [
    {:request_screenshot, "Capture and include screenshot in next context"}
  ]
end
```

**Option C: Enhanced External Events with Lens Routing**
```elixir
# Routine declares lens event handlers
external_events: [
  {:lens_action, TestLens, :request_screenshot,
    fn context -> {context, lens_updates: [request_screenshot: true]} end}
]

# UI sends generic lens action event
Engine.send_external_event(routine_id, :lens_action,
  %{lens: TestLens, action: :request_screenshot})
```

**Trade-offs:**
- Option A: Most lens-centric, but adds new Engine API
- Option B: Explicit control layer, clear separation of concerns
- Option C: Leverages existing external events, minimal new APIs

**Why deferred:**
- Need to use pattern in multiple contexts to evaluate
- Current external events work but are verbose
- Should emerge from real usage patterns
- M4 WireframeEditor will provide more use cases

**Future work:**
- Implement in M4 with WireframeEditor lens
- Consider standardizing lens action declarations
- Evaluate integration with tool system
- Document best practices

### Test Routine Progression
**Status:** Architecture pattern identified October 30, 2025

As capabilities are added to the system, test routines should follow a logical progression:

**Progression levels:**
1. **Chat only** - Basic message exchange (not needed - covered by unit tests)
2. **Chat with context** - TestChatRoutine + TestLens ✅ (M2, current)
   - Lens provides text context
   - Lens provides image context (including screenshots)
   - No tool execution
3. **Chat with context and tools** - AgentTestRoutine (future)
   - Full agent loop with tool execution
   - Tool lookup and execution steps
   - Lens updates from tools
4. **Multi-phase workflows** - Future test routines
   - Phase transitions
   - Sub-routine management
   - Complex state management

**Current status:**
- M2-M3: Using TestChatRoutine (level 2 - chat with context)
- TestLens provides context but doesn't execute tools
- Screenshot testing uses direct flag setting (no tool execution needed)
- Echo tool enhancement in TestLens is for manual testing only

**Future work:**
- Create AgentTestRoutine when tool execution needs testing
- Keep progression clear: each level builds on previous
- Don't conflate testing levels (e.g., screenshot tests don't need tools)

### Orchestrator Refactoring
**Status:** Ported as-is in Phase 4, consider splitting later

The Orchestrator (489 lines) handles the complete step execution lifecycle. The original Flo code has a TODO suggesting splitting into separate modules:

**Current structure:**
- Single module with step execution, transition logic, sub-routine management, LLM transitions

**Suggested split:**
1. **StepExecutor** - Handle step execution (execute_current_step, async execution, setup)
2. **TransitionManager** - Handle transitions (check_transitions, handle_transitions, condition evaluation)
3. **SubRoutineManager** - Handle sub-routine stack (enter/exit sub-routines)

**Why deferred:**
- Module is large but cohesive (all about step lifecycle)
- Splitting would require careful coordination between modules
- Step completion immediately triggers transitions - coupling is natural
- Better to port working code first, understand usage patterns
- Can refactor after Phase 5 when we see how Engine uses it

**Future considerations:**
- After porting Engine and EventHandler, evaluate if split would improve clarity
- Sub-routine management might be cleanly separable
- Transition logic is tightly coupled to step completion - may not be worth splitting
- Consider if the module becomes hard to test or maintain

### EventRecorder Pattern
**Status:** Ported as-is in Phase 3, consider refactoring later

EventRecorder is a thin wrapper around Observer that extracts standard fields from engine state. This pattern isn't idiomatic Elixir.

**Current pattern:**
```elixir
EventRecorder.record_event(state, "step_started", %{metadata: %{}})
# Extracts routine_id, module, current_step from state
```

**More idiomatic alternatives:**
1. **Observer takes state directly:**
   ```elixir
   Observer.record_event(state, "step_started", %{metadata: %{}})
   # Observer extracts what it needs
   ```

2. **Explicit parameters (most explicit):**
   ```elixir
   Observer.record_event(
     routine_id: state.routine_id,
     event_type: "step_started",
     ...
   )
   ```

3. **Protocol-based (most flexible):**
   ```elixir
   defprotocol EventSource do
     def extract_event_context(source)
   end
   ```

**Why deferred:**
- EventRecorder works and is used throughout engine components
- Small module (35 lines), easy to understand
- Changing would require updating all call sites in Orchestrator, EventHandler, Engine
- Better to port working code first, refactor after we understand usage patterns

**Future considerations:**
- After porting all engine components, evaluate which pattern fits best
- Consider if the abstraction is even needed - maybe Observer should handle state directly
- Telemetry events might be a better fit than custom event recording

### ContextManager Nested Updates
**Status:** Tech debt identified (October 30, 2025)

**Problem:**
Currently, ContextManager only supports top-level updates. When updating nested maps (like `lens_state`), steps must manually read the existing value, merge changes, and replace the entire map. This is error-prone and verbose.

**Current pattern (error-prone):**
```elixir
# Must manually merge to preserve existing keys
existing_lens_state = state.context[:lens_state] || %{}
updated_lens_state = Map.put(existing_lens_state, :request_screenshot, true)

diff = [add_or_update: %{lens_state: updated_lens_state}]
```

**Desired pattern:**
```elixir
# Direct nested update with put_in semantics
diff = [put_in: %{lens_state: %{request_screenshot: true}}]

# Or even deeper nesting
diff = [put_in: %{config: %{ui: %{theme: "dark"}}}]
```

**Why it matters:**
- Common pattern across steps (ChatUserInput, ToolExecution, etc.)
- Easy to accidentally replace instead of merge
- Verbose boilerplate in every step
- `lens_state` specifically designed for cross-turn state merging
- Similar issues with other nested context keys

**Potential implementations:**

**Option A: New `put_in` operation**
```elixir
@type diff_operation ::
  {:add, map()}
  | {:update, map()}
  | {:add_or_update, map()}
  | {:append_to, map()}
  | {:remove, list()}
  | {:put_in, map()}  # NEW: Nested merge

# Semantics: Deep merge - creates parent keys if needed, merges nested maps
```

**Option B: Enhanced `add_or_update` with deep merge option**
```elixir
{:add_or_update, map(), deep: true}
```

**Option C: Separate `merge_nested` operation**
```elixir
{:merge_nested, %{lens_state: %{request_screenshot: true}}}
```

**Why deferred:**
- Current manual merge works but is repetitive
- Need to consider semantics carefully (how deep? conflict handling?)
- Should evaluate common patterns across all steps first
- Want to avoid over-engineering before we understand all use cases

**Future considerations:**
- Audit all context updates to find common patterns
- Consider if this is specific to `lens_state` or general need
- Think about conflict resolution for deep merges
- Consider JSON Patch-style operations for flexibility
- May want different semantics for different keys (some replace, some merge)

---

## Future / Ideas

*(Not committed to any milestone)*

- [ ] Performance profiling and optimization
- [ ] Reduce initial startup time
- [ ] OpenAI provider support
- [ ] Ollama local LLM support
- [ ] Custom routine creation guide
- [ ] Video demo/tutorial
- [ ] Blog post about architecture
- [ ] Additional example routines
- [ ] Lens development guide

---

## Notes

- Keep backlog updated as we discover new tasks
- Mark blockers clearly
- Celebrate completed milestones!
- Re-plan as needed
- Document deferred decisions in "Deferred Improvements" section
