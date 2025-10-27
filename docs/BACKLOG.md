# Koalemos - Development Backlog

**Last Updated:** October 27, 2024

---

## Milestone 1: Foundation (In Progress)

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
- [ ] **Phase 7: Integration Testing**
  - [ ] Basic test: Can instantiate and run simple routine
  - [ ] Registry integration tests

---

## Milestone 2: Core Routine

**Goal:** Get wireframe design working end-to-end

### Todo
- [ ] Port TemplatedSemanticAgent subroutine
- [ ] Port WireframeEditor lens
- [ ] **Screenshot Tool Implementation** (deferred from ChatUserInput + ToolExecution)
  - [ ] Create ScreenshotCache module (~20 lines, basic get/set/clear)
  - [ ] Create screenshot capture tool in WireframeEditor lens (~30 lines)
  - [ ] Tool uses PubSub to request screenshot from JavaScript (~20 lines)
  - [ ] Tool returns image as part of tool result (using Phase 6c-refactor format)
  - [ ] Total: ~70 lines moved from ChatUserInput/ToolExecution to proper location
  - **Design:** Tool controls whether to include images in result, not the execution engine
- [ ] Port supporting lenses
  - [ ] Scratchpad
  - [ ] PersonaLens
  - [ ] SequentialThinking
  - [ ] Workflow (for transitions)
- [ ] Port WireframeDesign routine
  - [ ] Main routine definition
  - [ ] Discovery sub-routine
  - [ ] Structure sub-routine
  - [ ] Behavior sub-routine
  - [ ] Polish sub-routine
- [ ] Port LiveView pages
  - [ ] WireframeEditorLive
  - [ ] WireframePreviewLive
  - [ ] MessageCardsComponent
  - [ ] UserInputComponent
- [ ] Test: Complete wireframe design session works

---

## Milestone 3: Infrastructure

**Goal:** All supporting systems working

### Todo
- [ ] Port HTML/JavaScript parsers
  - [ ] HTMLParser with metadata extraction
  - [ ] JavaScriptParser (NodeJS integration)
  - [ ] JavaScriptExtractor
- [ ] Port caching system
  - [ ] ScreenshotCache
  - [ ] DOMStateCache
  - [ ] ConsoleCache
  - [ ] VariableStateCache
- [ ] Port credential management
  - [ ] SimpleCredentialManager (OAuth)
  - [ ] DemoCredentialStore (file-based)
- [ ] Clean up logging
  - [ ] Make debug logging configurable
  - [ ] Remove excessive trace logs
  - [ ] Add production-level logging
- [ ] Add dependencies to mix.exs
  - [ ] nodejs for JS parsing
  - [ ] finch for HTTP
  - [ ] Review flo dependencies
- [ ] Test: All features work correctly

---

## Milestone 4: UI/UX

**Goal:** Polish user-facing experience

### Todo
- [ ] Create landing page
  - [ ] Project overview
  - [ ] "Start Session" CTA
  - [ ] Optional wireframe upload
  - [ ] Quick examples/demos
- [ ] Clean up debug UI
  - [ ] Hide debug panel by default
  - [ ] Add toggle for advanced users
  - [ ] Clean up log output
- [ ] Error handling
  - [ ] Graceful LLM API failures
  - [ ] Network error messages
  - [ ] Upload validation
- [ ] Loading states
  - [ ] Session initialization
  - [ ] LLM thinking indicator
  - [ ] File upload progress
- [ ] Modal improvements
  - [ ] Smooth transitions
  - [ ] Better upload UX (already improved!)
- [ ] Test: Good UX, no rough edges

---

## Milestone 5: Release

**Goal:** Package and ship

### Todo
- [ ] Create Dockerfile
  - [ ] Multi-stage build
  - [ ] Asset compilation
  - [ ] Minimal runtime image
- [ ] Create docker-compose.yml
  - [ ] Easy local development
  - [ ] Volume mounts for development
- [ ] Environment configuration
  - [ ] .env.example file
  - [ ] Runtime.exs configuration
  - [ ] Secrets management guide
- [ ] Build and publish container
  - [ ] GitHub Container Registry
  - [ ] Version tagging
  - [ ] Latest tag
- [ ] Documentation
  - [ ] README with quick start
  - [ ] ARCHITECTURE.md (system design)
  - [ ] DEPLOYMENT.md (how to deploy)
  - [ ] CONTRIBUTING.md (for future)
- [ ] Test deployment
  - [ ] Local Docker
  - [ ] Fly.io deployment
- [ ] Test: Can deploy and run in < 5 minutes

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
