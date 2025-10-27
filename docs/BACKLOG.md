# Koalemos - Development Backlog

**Last Updated:** October 27, 2024

---

## Milestone 1: Foundation ✅

**Goal:** Project setup and core engine extraction

### Completed
- [x] Create new Phoenix project `koalemos`
- [x] Set up directory structure (engine/, routines/, subroutines/, steps/, lenses/)
- [x] Create project documentation (PRD, BACKLOG, ARCHITECTURE, NAMING)

### In Progress
- [ ] Initialize git repository
- [ ] Create GitHub private repository
- [ ] Initial commit and push

### Todo
- [ ] Port core workflow engine
  - [ ] Extract Flo.WorkflowEngine → Koalemos.Engine
  - [ ] Extract WorkflowOrchestrator → Engine.Orchestrator
  - [ ] Extract WorkflowObserver → Engine.Observer
  - [ ] Extract WorkflowRegistryAdapter → Engine.Registry
- [ ] Port essential steps (minimal set)
  - [ ] ConfigNode → Steps.Core.Config
  - [ ] SystemNode → Steps.Core.System
  - [ ] LLMRequestNode → Steps.Agent.LLMRequest
  - [ ] ResponseParsingNode → Steps.Agent.ResponseParsing
  - [ ] ToolExecutionNode → Steps.Agent.ToolExecution
  - [ ] ChatUserInputNode → Steps.User.ChatUserInput
  - [ ] CombinedInputNode → Steps.User.CombinedInput (wireframe specific)
- [ ] Basic test: Can instantiate and run simple routine

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
