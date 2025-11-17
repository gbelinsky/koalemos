# Koalemos - Product Requirements Document

**Version:** 0.1
**Last Updated:** October 27, 2024
**Status:** Draft

---

## Vision

Koalemos is an AI-powered wireframe design tool that lets users collaboratively build interactive prototypes through natural language conversation. Named after the Greek spirit of foolishness, it embraces the learning process and honest limitations of current AI technology.

## Philosophy

- **Humility at the start** - "I don't know everything, but I'm building anyway"
- **Honest about AI** - Not overselling what LLMs can do
- **Growth mindset** - Learning from mistakes is the whole point
- **Memorable** - The name sparks conversation about foolishness and wisdom

---

## MVP Scope - Initial Release

### Core Functionality

**What we're shipping:**
- Wireframe design routine with AI collaboration
- Live preview with real-time updates
- HTML upload capability for starting points
- Natural language interface for design modifications
- Screenshot capture for AI context
- Phase-based workflow (Discovery → Structure → Behavior → Polish)

**What we're NOT shipping (yet):**
- Other routines (semantic search, file editing, etc.)
- Advanced lens compositions
- Multi-user collaboration
- Routine builder UI
- Database persistence
- User authentication
- Other experimental features

### User Journey (MVP)

1. User lands on landing page
2. Clicks "Start New Session" or uploads HTML wireframe
3. AI introduces itself and asks what to build
4. User describes wireframe in natural language
5. AI analyzes request and routes to appropriate phase:
   - **Discovery**: Gathering requirements
   - **Structure**: HTML/CSS layout changes
   - **Behavior**: JavaScript/interactivity
   - **Polish**: Visual design improvements
6. AI makes changes, preview updates in real-time
7. Iterative conversation continues
8. User can save/export result

---

## Technical Requirements

### Must Have

**Core Engine:**
- Execution engine for running routines
- State management and transitions
- Event broadcasting system
- Process registry

**Wireframe Design:**
- WireframeDesign routine (main process)
- TemplatedSemanticAgent subroutine
- WireframeEditor lens (DOM manipulation)
- Supporting lenses (Scratchpad, PersonaLens, SequentialThinking, Workflow)

**Infrastructure:**
- Phoenix LiveView for real-time UI
- HTML/JavaScript parser
- Screenshot/state caching (DOM, console, variables)
- Simple credential management
- Anthropic API integration

### Nice to Have (Backlog)

- OpenAI/Ollama provider support
- Docker deployment
- Pre-built container image
- Performance optimizations
- Startup time improvements

### Out of Scope

- Database persistence (sessions are ephemeral)
- User accounts/authentication
- Routine builder/visual editor
- Other lenses/routines from prototype

---

## Deployment Goals

**Development:**
- Simple `mix phx.server` for local dev
- Hot reload during development

**Production:**
- Docker container for easy deployment
- Published pre-built image (Docker Hub / GitHub Container Registry)
- One-command deploy to platforms (Fly.io, Render, Railway)
- Environment variable configuration

---

## Success Criteria

**Functional:**
- ✅ Can run complete wireframe design session end-to-end
- ✅ Page reload preserves session state
- ✅ Screenshots attach to AI context messages
- ✅ Can upload custom HTML wireframe
- ✅ All four phases work correctly

**Quality:**
- ✅ Clean, well-documented codebase
- ✅ < 5 minute setup for developers
- ✅ Clear error messages
- ✅ Good user experience

**Performance:**
- ✅ Preview updates feel instant
- ✅ Initial load < 3 seconds
- ✅ No race conditions or timing bugs

---

## Milestones

See [BACKLOG.md](./BACKLOG.md) for detailed task breakdown.

**M1: Foundation** - Project setup, core engine
**M2: Core Routine** - Wireframe design working
**M3: Infrastructure** - Parsers, caches, polish
**M4: UI/UX** - Landing page, error handling
**M5: Release** - Docker, docs, deployment

---

## Future Considerations

*(Not part of MVP, but worth noting)*

- Multi-routine support
- Custom routine creation
- Lens marketplace/plugins
- Collaborative sessions
- Persistent storage
- Analytics/telemetry
- AI provider abstraction layer
