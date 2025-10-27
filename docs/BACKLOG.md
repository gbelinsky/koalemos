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

### Todo
- [ ] **Phase 4: Level 4 Modules**
  - [ ] Port Engine.Orchestrator (was WorkflowOrchestrator) - Critical module
- [ ] **Phase 5: Level 5 Modules**
  - [ ] Port Engine.EventHandler
  - [ ] Port Engine (was WorkflowEngine)
  - [ ] Port Engine.Registry (was WorkflowRegistryAdapter)
- [ ] **Phase 6: Essential Steps** (minimal set)
  - [ ] Steps.Core.Config (was ConfigNode)
  - [ ] Steps.Core.System (was SystemNode)
  - [ ] Steps.Agent.LLMRequest (was LLMRequestNode)
  - [ ] Steps.Agent.ResponseParsing (was ResponseParsingNode)
  - [ ] Steps.Agent.ToolExecution (was ToolExecutionNode)
  - [ ] Steps.User.ChatUserInput (was ChatUserInputNode)
  - [ ] Steps.User.CombinedInput (was CombinedInputNode)
- [ ] **Phase 7: Integration Testing**
  - [ ] Basic test: Can instantiate and run simple routine
  - [ ] Registry integration tests

---

## Milestone 2: Core Routine

**Goal:** Get wireframe design working end-to-end

### Todo
- [ ] Port TemplatedSemanticAgent subroutine
- [ ] Port WireframeEditor lens
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

### Logging Reduction
**Status:** Noted during port

The Observer has minimal logging in the Koalemos port (removed excessive TRACE logs from Flo). Future work could:
- Make debug logging configurable via environment
- Add structured logging with log levels
- Consider using telemetry events instead of logs

### EventRecorder Pattern
**Status:** Will port as-is in Phase 3, consider refactoring later

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
