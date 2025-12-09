# Completed Milestones

Historical summary of completed work. See `docs/internal/archive/` for detailed sprint and milestone docs.

---

## Milestone 1: Foundation (October 2025)

Project setup and core engine extraction. Created Phoenix project structure, ported Engine components (ContextManager, EventBuffer, Orchestrator, etc.), implemented tool system and LLM provider architecture. Supports Anthropic, OpenAI, and Ollama providers. 507 tests passing at completion.

**Key deliverables:**
- Engine core (Orchestrator, EventHandler, EngineManager)
- Step system (ToolSchema, ToolExecution, ResponseParsing)
- Multi-provider LLM support (Anthropic, OpenAI, Ollama)
- Credential management

---

## Milestone 2: UI Foundation + Simple Agent Loop (October 29, 2025)

Chat with AI works (text-only). Built complete UI architecture from Phoenix layouts through message components, input handling, and chat panel. TestChatRoutine and TestLens prove end-to-end flow.

**Key deliverables:**
- HomePage, StartSessionModal, RoutineChatLive
- Message components (UserCard, AssistantCard, ErrorCard)
- TestChatRoutine for agent loop testing
- Multi-turn conversation support

---

## Milestone 3: Infrastructure Layer (October 29 - November 2, 2025)

Screenshot capture and HTML parsing work independently. Built screenshot infrastructure with html2canvas, provider-specific configuration panels, and Ollama integration.

**Key deliverables:**
- ScreenshotCache and JavaScript capture hooks
- OllamaClient with model auto-fetch
- Enhanced StartSessionModal with provider selection
- PubSub communication patterns

---

## Milestone 4: Advanced Lens System (November 2-9, 2025)

Three advanced lenses with comprehensive test infrastructure. PersonaLens (context-only personas), SequentialThinking (step-by-step reasoning), and WireframeEditor (9 DOM editing tools).

**Key deliverables:**
- PersonaLens (5 hardcoded personas)
- SequentialThinking (ported from MCP server)
- WireframeEditor with 9 tools
- WireframePreviewLive infrastructure
- JavaScriptUpdater hook for live updates

---

## Milestone 5: Semantic Routing & Intelligent Workflows (November 12-14, 2025)

Semantic routing infrastructure for intelligent agent workflows. TemplatedSemanticAgent step, SemanticTransition lens, and two workflow patterns.

**Key deliverables:**
- TemplatedSemanticAgent step (EEx templating)
- SemanticTransition lens (natural language routing)
- WireframeDesignRoutine (8 sub-routines)
- BuildWireframeRoutine (5-stage linear build)
- Lens scoping system (merge-with-override)

---

## V4 Architecture (December 2025)

Major refactoring to fix init script timing issues. Replaced PubSub-based V3 with direct Registry communication. StateServer as single source of truth with blocking operations.

**Key deliverables:**
- WireframeStateServerV4 (facade with StateStore + PreviewCoordinator)
- WireframeEditorV4 lens (direct StateServer calls)
- V4 routines (WireframeDesignV4Routine, BuildWireframeV4Routine, PlayV4Routine)
- No PubSub, no adapters, simpler timing

See `docs/guides/V4_ARCHITECTURE.md` for architecture details.
