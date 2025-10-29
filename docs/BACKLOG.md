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
**Status:** Planning → Sprint 1 Ready

---

## Milestone 3: Infrastructure Layer

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

### Part A: Screenshot System (~1,000 lines)

**Components:**
- [ ] **JavaScript Hooks** (~500 lines)
  - [ ] Extract WireframeScriptHook from Flo (screenshot parts only)
  - [ ] Canvas-based screenshot capture
  - [ ] PubSub communication with Elixir
  - [ ] Debouncing/throttling

- [ ] **ScreenshotCache** (~150 lines)
  - [ ] GenServer for in-memory image storage
  - [ ] Store base64 encoded images
  - [ ] get/put/clear operations
  - [ ] Supervision tree integration

- [ ] **Screenshot Tool** (~100 lines)
  - [ ] Tool definition in test lens
  - [ ] Requests screenshot via PubSub
  - [ ] Returns image in tool result (Phase 6c-refactor format)
  - [ ] Proper error handling

- [ ] **Integration** (~250 lines)
  - [ ] Wire JavaScript hooks to LiveView
  - [ ] PubSub channels for coordination
  - [ ] Test workflow: request → capture → store → retrieve

### Part B: Parsing System (~1,500 lines)

**Components:**
- [ ] **HTMLParser** (~800 lines, simplified first version)
  - [ ] Port from Flo (38KB original - simplify for MVP)
  - [ ] Extract semantic structure (headings, forms, buttons, etc.)
  - [ ] Extract metadata (ids, classes, data attributes)
  - [ ] Basic error handling

- [ ] **JavaScriptExtractor** (~200 lines)
  - [ ] Extract inline scripts
  - [ ] Extract event handlers
  - [ ] List functions defined

- [ ] **Caches** (~400 lines total)
  - [ ] DOMStateCache - Store parsed DOM structure
  - [ ] ConsoleCache - Store console logs
  - [ ] VariableStateCache - Store variable snapshots
  - [ ] All GenServers, supervised

- [ ] **Integration** (~100 lines)
  - [ ] Parse HTML on preview load
  - [ ] Store results in caches
  - [ ] Test data flow

**Dependencies:**
- M2 (LiveView for JavaScript context)
- Part B independent of Part A

**Test Criteria:**
- ✅ Can capture screenshot from preview iframe
- ✅ Screenshot stored in cache and retrievable
- ✅ Can parse HTML and extract metadata
- ✅ Caches store/retrieve data correctly
- ✅ Both systems work independently

**Lines:** ~2,500
**Status:** Todo

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
