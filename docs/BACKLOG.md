# Koalemos - Development Backlog

**Last Updated:** November 2, 2025

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

## Milestone 3: Infrastructure Layer ✅ COMPLETE

**Status:** All 8 Sprints Complete
**Started:** October 29, 2025
**Completed:** November 2, 2025

**Goal:** Screenshot capture + HTML parsing work independently

**Why Together:**
- Both are infrastructure needed by M4
- Can be tested separately (no interdependency)
- Large milestone but two independent tracks (could parallelize)

### M3 UX Improvements (Completed in Sprint 8)

**Goal:** Polish chat interface and provider configuration

**Components:**

- [x] **Compact Config Display** ✅
  - Show provider/model info in header (small text)
  - Shows actual routine config from context
  - Unobtrusive, doesn't increase header height
  - Chat panel displays configuration

- [x] **Provider-Specific Configuration Panels** ✅
  - **Ollama:**
    - ✅ OllamaClient fetches models from `/api/tags` endpoint
    - ✅ Auto-populates model dropdown on connection
    - ✅ Real-time connection check (connected/error states)
    - ✅ Shows connection errors with helpful messages
  - **Anthropic:**
    - ✅ API key input in StartSessionModal
    - ✅ OAuth support (uses existing SimpleCredentialManager)
    - ✅ Model selection via text input
  - **OpenAI:**
    - ✅ API key input in StartSessionModal
    - ✅ Model selection via text input

- [x] **Enhanced Start Session Modal** ✅
  - ✅ Provider selection dropdown (Anthropic/OpenAI/Ollama)
  - ✅ Provider-specific configuration UI
  - ✅ Model selection based on provider
  - ✅ Persist configuration via DemoCredentialStore
  - ✅ Button validation (disabled until config valid)
  - ✅ Comprehensive test coverage (56.1%)

- [x] **Better Error Handling** ✅
  - ✅ User-friendly Ollama connection errors
  - ✅ Graceful GenServer failure handling
  - ✅ Model availability checking
  - ✅ Error states displayed in modal

**Dependencies:** M2 (chat interface complete)
**Lines:** ~900 (Sprint 8)
**Status:** ✅ Complete (November 2, 2025)

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

- [x] **Sprint 8: UX Polish & Testing** (~900 lines) ✅ Nov 2
  - [x] OllamaClient module (111 lines, 42.8% coverage, 11 tests)
  - [x] Compact config display (show provider/model in header)
  - [x] Enhanced StartSessionModal with provider selection
  - [x] Ollama integration (auto-fetch models, connection check)
  - [x] API key management (Anthropic, OpenAI)
  - [x] Comprehensive test suite (23 new tests)
  - [x] Coverage improvements (StartSessionModal: 8.5% → 56.1%)
  - [x] Error handling improvements (graceful GenServer failures)

**See docs/milestones/M3.md for detailed sprint plans**

**Lines:** ~3,000 (8 sprints)
**Status:** ✅ **MILESTONE 3 COMPLETE** (November 2, 2025)

---

## Milestone 4: Advanced Lens System 🔄 IN PROGRESS

**Status:** Sprint 7 of 8 In Progress (75% estimated)
**Started:** November 2, 2025
**Goal:** Build three advanced lenses (PersonaLens, SequentialThinking, WireframeEditor) with comprehensive test infrastructure and modular architecture

**Why This Scope:**
- Test infrastructure first prevents debugging nightmares
- Modular WireframeEditor architecture (no 1500-line monoliths)
- Tool execution infrastructure for lens tools
- Agent-as-node pattern for complex operations
- Complex wireframe as validation target throughout

**Detailed Plan:** See `docs/milestones/M4.md` for complete sprint breakdown

### Completed

- [x] **Sprint 1: Test Infrastructure Foundation** (~400 lines) ✅ Nov 2
  - [x] Sample HTML files (simple, medium, complex wireframes)
  - [x] WireframeTestLive - Interactive test page at `/test/wireframe`
  - [x] WireframeTestRoutine - Test routine with sample loading
  - [x] Manual validation checklist
  - [x] Complex wireframe as validation target documented

- [x] **Sprint 2: PersonaLens** (~290 lines) ✅ Nov 3
  - [x] Context-only lens (following flo's pattern - simpler than planned)
  - [x] 5 hardcoded personas: professional, casual, technical, creative, empathetic
  - [x] PersonaTestRoutine for manual testing
  - [x] Full test coverage (42 tests)
  - [x] No tools needed - works through system prompt injection

- [x] **Sprint 3: SequentialThinking** (~300 lines) ✅ Nov 4
  - [x] Ported from MCP server with full MIT license attribution
  - [x] Adapted to Koalemos lens interface (provide_context, execute_tool)
  - [x] Step-by-step reasoning with dynamic thought progression
  - [x] Single tool: sequential_thinking (4 required + 5 optional parameters)
  - [x] Context shows only current chain (replaces previous chain on reset)
  - [x] Brief tool results (no thought echo to reduce redundancy)
  - [x] State management: thought_history and branches in lens_state
  - [x] Support for revisions and branching (advanced features)
  - [x] ThinkingTestRoutine for manual testing
  - [x] Full test coverage (19 tests, 100% coverage)
  - [x] Future architecture documented in BACKLOG (request/result pairs)

- [x] **Sprint 4: WireframeEditor Preview Infrastructure** (~340 lines) ✅ Nov 5
  - [x] **Pivoted from original plan** - Built infrastructure over DOM tools
  - [x] WireframePreviewLive - LiveView in iframe (flo's architecture)
  - [x] WireframeStateCache - ETS cache for lens_state by routine_id
  - [x] WireframeTestLive updates - iframe src instead of srcdoc
  - [x] WireframeTestRoutine - Tool execution infrastructure ready
  - [x] Route for `/wireframe-preview/:routine_id`
  - [x] PubSub broadcasting for DOM tree updates
  - [x] HTML escaping fixes (Plug.HTML vs Phoenix.HTML)
  - [x] Manual validation - All sample wireframes load and render
  - [x] Context validation - `provide_context/2` shows complete DOM tree
  - [x] 15 wireframe routine tests passing
  - [x] **Deferred to Sprint 5:** Core module, DOM Handler, DOM tools

### Lessons Learned (Sprint 4)

**1. Validate Infrastructure Before Building Features**
Building the preview system first helped us discover HTML escaping issues and timing problems early. This saved time compared to implementing tools without a way to test them visually.

**2. Adopt Proven Patterns When Available**
Using flo's LiveView-in-iframe architecture gave us confidence and a working reference. No need to design from scratch when a proven solution exists.

**3. Test Pages Are Invaluable**
The interactive test page at `/test/wireframe` made it easy to spot problems visually and validate fixes immediately. Manual validation complements automated testing.

**4. Pivot When Reality Differs from Plan**
Original Sprint 4 plan called for DOM tools, but infrastructure needs revealed themselves during implementation. Pivoting to build foundation first was the right decision.

**5. Cache + PubSub Solves Timing Issues**
Combining WireframeStateCache (for initial load) with PubSub (for updates) elegantly solved the iframe mount timing problem. Both patterns will be useful as the system grows.

### Completed (continued)

- [x] **Sprint 5: WireframeEditor Core + DOM Tools** (~400 lines) ✅ Nov 5
  - [x] Fixed batch operation accumulation in all DOM tools
  - [x] Implemented element replacement functionality
  - [x] Added PubSub broadcasting for live updates
  - [x] Built chat interface for agent interaction
  - [x] Added CSS rendering to preview
  - [x] **All 9 tools functional** (CSS already complete)
  - [x] See `docs/sprints/sprint-5-summary.md` for full details

- [x] **Sprint 6: JavaScript Rendering + Critical Fixes** (~680 lines) ✅ Nov 7
  - [x] JavaScript rendering in preview (variables, functions, handlers, init scripts)
  - [x] JavaScriptUpdater LiveView hook for dynamic updates
  - [x] Auto-reload system for init script changes
  - [x] JavaScript syntax validation (NodeJS integration)
  - [x] **6 Critical Bug Fixes:** Boolean serialization, nested children, auto-IDs, init script timing, JS validation, argument validation
  - [x] Context clarity improvements
  - [x] Integration tests
  - [x] **8 of 9 tools tested and working** (trigger_interaction deferred)
  - [x] See `docs/sprints/sprint-6-summary.md` for full details

### Deferred from Sprint 6

**Infrastructure & Integration Work:**
- [ ] **trigger_interaction tool implementation** - Requires client-side infrastructure for server-to-client interaction triggers and element highlighting/selection
- [ ] **Console capture integration (ConsoleCache)** - May be significant work to get console capture correct
- [ ] **Screenshot integration** - Connect with existing screenshot infrastructure from M3
- [ ] **Better integration test scenarios (Test 12)** - Multi-tool workflows and complex agent interactions

**Performance Optimizations (Nice-to-have):**
- [ ] Server-side diff for push events - Only broadcast changed parts of state
- [ ] Smart diffing for variables/functions - Don't re-send unchanged code
- [ ] Soft reload for init scripts - Reset state without browser reload

**Bug Investigation:**
- [ ] Investigate document.title change issue in init scripts - Browser ignores title changes, low priority

### In Progress / Todo

- [x] **Sprint 7: WireframeEditor Feedback Loop & Integration** (~1,000 lines) 🔄 **IN PROGRESS**
  - [ ] State snapshot infrastructure (~200 lines)
    - [ ] Current state capture orchestration
    - [ ] Preview state broadcaster
    - [ ] Client-side state capture
    - [ ] Two-state model (designed vs current)
  - [ ] trigger_interaction tool (~150 lines)
    - [ ] Server-side implementation
    - [ ] Preview interaction handler
    - [ ] Client-side execution (click, fill, submit, js)
    - [ ] Completes all 9 tools
  - [ ] Console integration (~150 lines)
    - [ ] Console interception in preview
    - [ ] Integration with ConsoleCache
    - [ ] Console output in context
  - [ ] Screenshot integration (~100 lines)
    - [ ] Blocking screenshot capture
    - [ ] Screenshots in state snapshots
    - [ ] Automatic inclusion in context
  - [ ] Enhanced context (~200 lines)
    - [ ] State capture before LLM requests
    - [ ] Designed vs current state display
    - [ ] Diff highlighting
    - [ ] Console error highlighting
  - [ ] Integration tests (~200 lines)
    - [ ] Tic-tac-toe test (agent plays game it built)
    - [ ] Form interaction test
    - [ ] Error recovery test
    - [ ] Complex chain test
  - [ ] See `docs/sprints/sprint-7-plan.md` for full details

- [ ] **Sprint 8: Advanced Patterns & M4 Completion** (~500 lines)
  - [ ] Context enhancements (modification history, suggestions)
  - [ ] Testing utilities (helpers, fixtures, assertions)
  - [ ] Agent-as-node pattern (complex multi-step operations)
  - [ ] Final M4 documentation
  - [ ] M4 tagged and complete (v0.4.0)

**Dependencies:** M2 (LiveView), M3 (screenshots + parsers)

**Key Decisions:**
- **Modular WireframeEditor:** 5 separate modules (Core, DOM, JavaScript, CSS, Testing, Context) instead of monolithic file
- **Leverage Existing Parsers:** Use HTMLParser, JavaScriptParser, CSSParser - don't reimplement parsing
- **Two-Version State Management:** Track designed source (being edited) vs running preview (live state)
- **Tool Execution in Sprint 4:** Copy ThinkingTestRoutine pattern for immediate testing capability
- **JavaScriptParser Improvements in Sprint 5:** Fix extraction issues revealed by complex wireframe
- **Manual Verification Throughout:** Update test page each sprint, build reusable patterns
- **Tool Execution Tiers:** Direct execution (Sprint 4), agent-as-node pattern (Sprint 7) for complex operations
- **Validation Target:** Complex wireframe used throughout development as demo showcase
- **Cache Integration:** Use DOMStateCache, ConsoleCache, VariableStateCache, ScreenshotCache for state snapshots

**Test Criteria:**
- ✅ All 3 lenses fully functional (PersonaLens, SequentialThinking, WireframeEditor)
- ✅ Tool execution works from Sprint 4 onward (not deferred to Sprint 7)
- ✅ Two-version state management tracks designed vs running
- ✅ JavaScriptParser can extract all content from complex wireframe
- ✅ Agent-as-node pattern enables multi-step tool orchestration (Sprint 7)
- ✅ Complex wireframe fully parsed and editable via all handlers
- ✅ Manual verification page functional and updated each sprint
- ✅ Test coverage ≥ 80% for new code
- ✅ Round-trip fidelity (parse → modify → serialize → parse matches)

**Lines:** ~3,800 lines (reduced by 500 due to leveraging existing parsers)
**Status:** Sprint 1-3 Complete, Sprint 4-8 Todo

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

### JavaScript Parser Unit Tests
**Status:** Deferred (October 31, 2025)

**Problem:**
Currently, `priv/nodejs/js_parser.js` (241 lines) has no JavaScript-level unit tests. We only test it indirectly through 28 Elixir integration tests in `javascript_parser_test.exs`. While this validates the integration path, it makes debugging JavaScript-specific issues more difficult.

**Current approach:**
- 28 Elixir tests call the Elixir wrapper which calls the JS parser
- Tests cover all parsing scenarios (variables, functions, handlers, DOMContentLoaded unwrapping)
- Matches Flo's approach (also no JS unit tests)
- Works well for integration testing

**Desired approach:**
- Add JavaScript unit tests with Jest
- Test `js_parser.js` functions directly at the JavaScript level
- Better unit-level granularity for debugging
- Standard Node.js best practice
- Keep Elixir integration tests (Option C: both)

**Benefits of adding Jest tests:**
- ✅ Easier to debug AST transformation issues
- ✅ Faster test execution for JS-only changes
- ✅ Better coverage of edge cases
- ✅ Standard Node.js development practice

**Implementation:**
- Add Jest to `priv/nodejs/package.json`
- Create `priv/nodejs/js_parser.test.js`
- Test individual functions: `extractHandlerInfo`, `walkAndTransform`, `unwrapAllDOMContentLoaded`
- Keep existing Elixir tests for integration validation

**Why deferred:**
- Current integration tests are comprehensive
- Simple to maintain (no Jest setup needed)
- Need to evaluate debugging pain points first
- Can add later without affecting functionality

**Future considerations:**
- Add Jest tests if debugging becomes difficult
- Consider test coverage for individual helper functions
- May want both unit (Jest) and integration (ExUnit) tests

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

## Known Test Failures

### Test Failure: engine_manager_test "list_routines/0 returns empty list"
**Status:** Pre-existing, parallel test execution issue (identified October 31, 2025)
**File:** `test/koalemos/engine_manager_test.exs:113`

**Problem:**
Test expects empty routine list, but finds routines from other tests running in parallel. ExUnit runs tests in parallel by default (async: true), and routines from other test cases are still registered when this test runs.

**Test code:**
```elixir
test "list_routines/0 returns empty list when no routines" do
  assert EngineManager.list_routines() == []
end
```

**Typical failure:**
```
left:  [
  %Koalemos.EngineManager.RoutineInfo{
    id: "routine-test-4549", ...
  },
  %Koalemos.EngineManager.RoutineInfo{
    id: "screenshot-test-5059", ...
  }
]
right: []
```

**Root cause:**
- Tests use shared Registry (Koalemos.RoutineRegistry)
- Parallel tests register routines at overlapping times
- Registry cleanup isn't instantaneous

**Options:**
1. **Make test non-async** - Run sequentially (slow, doesn't fix race conditions)
2. **Add test-specific registry** - Each test gets its own Registry (complex)
3. **Use setup/cleanup properly** - Ensure cleanup happens before assertion (may not work due to timing)
4. **Change assertion** - Test that list contains expected routines, not that it's empty
5. **Skip the test** - Mark as known flaky test

**Recommendation:** Option 4 - Change the test to be more realistic. In a real system, we care about finding specific routines, not that the list is empty. Or option 2 - use test-specific registries for better isolation.

**Future work:**
- Audit all EngineManager tests for parallel safety
- Consider test-specific Registry per test (via start_supervised)
- Document testing patterns for stateful systems

### Test Failures: Flaky Observer Tests
**Status:** Intermittent, timing-dependent (identified November 2, 2025)
**Files:** `test/koalemos/engine/observer_test.exs`

**Problem:**
Two ObserverTest tests occasionally fail depending on test execution order and timing:

1. **"record_event/1 - basic functionality handles events without routine_id"**
   - Expected event type: "global_event"
   - Received: "step_started" (from parallel test)
   - Tests share Observer GenServer state

2. **"serialization handles complex nested structures"**
   - Expected specific complex structure
   - Receives different routine event (integration-test-7818)
   - Race condition with integration tests

**Root cause:**
- Tests use shared Observer GenServer
- Parallel test execution causes event interleaving
- Observer receives events from other tests
- Event ordering is non-deterministic

**Test behavior:**
- Usually pass (0 failures with seed 99999)
- Sometimes fail (1-2 failures with seed 12345)
- Flakiness depends on test execution order

**Options:**
1. **Make tests non-async** - Run sequentially (slow, doesn't fully fix timing issues)
2. **Isolate Observer per test** - Each test gets its own Observer instance
3. **Use test-specific routine IDs** - Filter events by test-specific IDs
4. **Mock Observer** - Don't use real GenServer in unit tests
5. **Accept flakiness** - Document and monitor

**Recommendation:** Option 2 - Use `start_supervised/1` to create test-specific Observer instances with unique names. This provides true isolation without sacrificing integration testing.

**Future work:**
- Refactor ObserverTest to use isolated Observer instances
- Consider pattern for all stateful GenServer tests
- Document best practices for testing stateful systems
- Add test isolation guide to CONTRIBUTING.md

### Lens Tool Execution Request/Result Pairs
**Status:** Deferred (identified during M4 Sprint 3 - SequentialThinking, November 2025)

**Problem:**
When lenses provide both context and tools, there's redundancy in the message array. Tool calls contain full argument details (e.g., complete thought text in `sequential_thinking` tool), and then the same information appears in context provided by the lens. This creates duplicate information in the message history.

**Current approach (MVP):**
- Tool calls stored in message array with full arguments
- Lens provides context showing current reasoning chain
- Tool results are brief JSON (status, metadata only)
- Accept redundancy for simplicity - ship fast, iterate later

**Example redundancy:**
```elixir
# Message array contains full tool call
%{
  role: "assistant",
  content: [
    %{
      type: "tool_use",
      name: "sequential_thinking",
      input: %{
        "thought" => "Breaking down the problem into steps...",  # FULL TEXT
        "thought_number" => 1,
        "total_thoughts" => 3
      }
    }
  ]
}

# Context also shows the thought text
## Current Thinking Chain
1. Breaking down the problem into steps...  # DUPLICATE
```

**Future architecture: Request/Result Pairs**

Change lens tool execution semantics to return both a stripped request and result:

```elixir
# Current signature
@callback execute_tool(name :: String.t(), args :: map(), state :: map()) ::
  {:ok, result :: term(), lens_updates :: keyword()} | {:error, term()}

# Future signature
@callback execute_tool(name :: String.t(), args :: map(), state :: map()) ::
  {:ok, {request_summary :: map(), result :: term()}, lens_updates :: keyword()}
  | {:error, term()}
```

**How it works:**

1. **Lens knows its context** - Since the lens provides context, it knows what information is redundant
2. **Return stripped request** - Lens returns summary of request without redundant details
3. **Return full result** - Result can be as detailed as needed
4. **Store pair in messages** - Message array stores the {request_summary, result} pair

**Example implementation:**
```elixir
def execute_tool("sequential_thinking", args, state) do
  # ... execute thinking logic ...

  # Strip redundant thought text from request
  request_summary = %{
    tool: "sequential_thinking",
    thought_number: args["thought_number"],
    total_thoughts: args["total_thoughts"]
    # Omit "thought" text - it's in context already
  }

  result = %{
    status: "ok",
    thought: args["thought_number"],
    total: args["total_thoughts"],
    continue: args["next_thought_needed"]
  }

  {:ok, {request_summary, result}, lens_updates}
end
```

**Benefits:**
- ✅ Eliminates redundancy between context and messages
- ✅ Lens controls what's essential vs. what's already shown
- ✅ Reduces message array size for long reasoning chains
- ✅ Each lens optimizes for its own context strategy
- ✅ Backward compatible - single result still works

**Long-term vision: ToolLens**

Eventually, tool request/result pairs could be:
- Tracked separately from main message flow
- Displayed via dedicated ToolLens (optional context)
- Shown/hidden based on user preference
- Aggregated/summarized for long tool chains

**Why deferred:**
- Current approach works for MVP
- Need experience with multiple tool lenses first
- Requires updating message handling throughout engine
- Should understand common patterns before optimizing
- Better to validate lens concept, then reduce redundancy

**Future considerations:**
- After implementing more tool lenses (M4 Sprint 4-7), evaluate patterns
- Consider if all lenses need this or just stateful tool lenses
- Think about UI for showing/hiding tool details
- May want configurable verbosity (debug vs. production)
- Integration with future observability/debugging tools

### WireframeEditor Context Display & State Capture
**Status:** Deferred (identified during M4 Sprint 7 - November 9, 2025)

**Problem:**
The "Show Agent Context" UI button and the actual agent LLM request capture state independently, resulting in:
1. Duplicate snapshot requests (wasteful)
2. Inconsistent views (UI shows stale, agent sees fresh)
3. Confusion about what the agent actually sees

**Current workaround:**
When "Show Agent Context" button is clicked, regenerate context with fresh state capture. This works but:
- Captures state twice per turn (once for agent, once for UI)
- UI context may differ from what agent actually saw
- No guarantee of temporal consistency

**Better architecture:**
UI should display the ACTUAL context that was sent to the LLM in the most recent request, not regenerate it:

```elixir
# Store actual sent context in routine state
context.last_llm_context = %{
  text: "...",  # What was actually sent
  captured_at: DateTime.utc_now(),
  turn_number: 5
}

# UI retrieves and displays exactly what agent saw
def show_agent_context(routine_id) do
  get_last_llm_context(routine_id)
end
```

**Benefits:**
- ✅ Single source of truth
- ✅ No duplicate captures
- ✅ UI shows EXACTLY what agent saw
- ✅ Can track context over time (history viewer)

**Why deferred:**
- Current approach works for Sprint 7
- Need to implement context history tracking first
- Requires Engine changes to store sent contexts
- Should wait until M4 complete to evaluate patterns

**Future considerations:**
- Context history viewer (see what agent saw on each turn)
- Diff viewer (show context changes between turns)
- Time-travel debugging (replay from specific context)

### Live DOM Snapshot Scope & Format
**Status:** Deferred (identified during M4 Sprint 7 - November 9, 2025)

**Problem 1: Snapshot captures too much**
Current DOM snapshot captures the entire iframe body, including LiveView wrapper elements (flash-group, phx-* attributes, etc.). Should only capture the actual wireframe content:

```javascript
// Current: captures everything
this.serializeDOM(document.body)

// Should be: capture only wireframe root
const wireframeRoot = document.getElementById('root')
this.serializeDOM(wireframeRoot)
```

**Problem 2: Inconsistent rendering format**
Designed DOM shows clean format:
```
- auto-div-4: <div> .logo | Content: "Complex Dashboard"
```

Live DOM shows verbose format:
```
- auto-div-4: <div> .logo | class: logo, id: auto-div-4 | Content: "Complex Dashboard"
```

The designed format is better because:
- Classes shown inline with dot notation (.logo)
- ID already in line prefix (auto-div-4:)
- No redundant attribute listing

**Current workaround:**
Accept the inconsistency and extra verbosity. Filter noise manually.

**Better architecture:**

1. **Scoped capture:**
```javascript
captureCompleteState(opts = {}) {
  // Find wireframe root element
  const wireframeRoot = document.getElementById(opts.rootId || 'root')
  if (!wireframeRoot) {
    console.warn('[StateCapture] Wireframe root not found')
    return
  }

  // Capture only the wireframe content
  const dom_tree = this.serializeDOM(wireframeRoot)
  // ...
}
```

2. **Unified format_dom_tree:**
Share the same formatting logic between designed and live DOM. Currently using two different code paths:
- Designed: `format_dom_tree(tree, indent, handlers)` - clean output
- Live: `format_dom_tree(tree, indent, %{})` - verbose output

Both should use the same formatter with the same output style.

**Benefits:**
- ✅ Cleaner context (no LiveView noise)
- ✅ Consistent presentation (easier to compare)
- ✅ Less token usage (removes redundant attributes)
- ✅ Better agent experience (focused on actual wireframe)

**Why deferred:**
- Current approach works for Sprint 7 (agent can see changes)
- Need to test with various wireframe structures first
- Should understand what root element patterns emerge
- Format unification requires careful refactoring

**Future considerations:**
- Make root selector configurable per wireframe
- Add visual diff highlighting (designed vs live)
- Consider showing only CHANGED elements in live view
- Extract common formatting to shared module

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
