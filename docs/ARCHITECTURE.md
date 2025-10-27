# Koalemos - System Architecture

**Last Updated:** October 27, 2024
**Status:** Living Document (will evolve as we build)

---

## Overview

Koalemos is an AI-powered wireframe design tool built on Phoenix LiveView and a custom execution engine. The system allows users to collaboratively build interactive prototypes through natural language conversation.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         User Browser                         │
│  ┌──────────────────┐              ┌───────────────────┐    │
│  │ WireframeEditor  │◄───LiveView──►│ WireframePreview  │    │
│  │   (Main UI)      │              │    (iframe)       │    │
│  └──────────────────┘              └───────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                    WebSocket (Phoenix)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Phoenix LiveView Layer                    │
│  - WireframeEditorLive: Main UI, session management         │
│  - WireframePreviewLive: Wireframe rendering                │
│  - PubSub: Real-time event broadcasting                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      Koalemos.Engine                         │
│  ┌──────────────┬──────────────┬─────────────────────────┐  │
│  │ Orchestrator │   Observer   │       Registry          │  │
│  │ (State mgmt) │   (Events)   │   (Process tracking)    │  │
│  └──────────────┴──────────────┴─────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Routines & Subroutines                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            WireframeDesign Routine                   │    │
│  │  ┌───────────┬───────────┬──────────┬────────────┐  │    │
│  │  │ Discovery │ Structure │ Behavior │   Polish   │  │    │
│  │  └───────────┴───────────┴──────────┴────────────┘  │    │
│  │                Uses: TemplatedSemanticAgent          │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │             │
                    ▼             ▼
        ┌──────────────────┬─────────────────┐
        │      Steps       │     Lenses      │
        │  - Agent steps   │ - WireframeEd   │
        │  - User steps    │ - Scratchpad    │
        │  - Core steps    │ - PersonaLens   │
        └──────────────────┴─────────────────┘
                    │
                    ▼
        ┌─────────────────────────┐
        │   Infrastructure        │
        │ - HTML/JS Parsers       │
        │ - Caches (Screenshot,   │
        │   DOM, Console, etc.)   │
        │ - Credential Manager    │
        │ - LLM API Client        │
        └─────────────────────────┘
```

---

## Core Components

### Engine

*(To be documented as we port)*

**Koalemos.Engine**
- Purpose: Execute routines with state management
- Responsibilities: TBD

**Engine.Orchestrator**
- Purpose: Manage routine state and transitions
- Responsibilities: TBD

**Engine.Observer**
- Purpose: Broadcast events (messages, UI updates)
- Responsibilities: TBD

**Engine.Registry**
- Purpose: Track running routine processes
- Responsibilities: TBD

### Routines

*(To be documented as we port)*

**WireframeDesign**
- Purpose: Main design conversation routine
- Phases: Discovery, Structure, Behavior, Polish
- Sub-routines used: TBD

### Subroutines

*(To be documented as we port)*

**TemplatedSemanticAgent**
- Purpose: Reusable agent pattern with template-based prompts
- Used by: Most phases in WireframeDesign
- Capabilities: TBD

### Steps

*(To be documented as we port)*

**Agent Steps:**
- LLMRequest: Make API calls to LLMs
- ResponseParsing: Parse LLM responses
- ToolExecution: Execute tools from LLM responses

**User Steps:**
- ChatUserInput: Handle chat messages
- CombinedInput: Wireframe-specific input handling

**Core Steps:**
- Config: Configure routine parameters
- System: System-level actions

### Lenses

*(To be documented as we port)*

**WireframeEditor**
- Purpose: Manipulate DOM tree, CSS, JavaScript
- Tools provided: TBD

**Supporting Lenses:**
- Scratchpad: Persistent notes
- PersonaLens: Multiple AI perspectives
- SequentialThinking: Reasoning chains
- Workflow: Transition control

---

## Data Flow

### Session Lifecycle

1. **Session Start**
   - User navigates to `/wireframe-editor` or clicks "New Session"
   - LiveView mounts, generates workflow_id
   - Optional: HTML wireframe uploaded and parsed
   - Engine starts WireframeDesign routine with initial context

2. **Routine Execution**
   - Engine runs `:initialize_ui` step
     - Broadcasts DOM tree to preview
     - Captures initial screenshot
     - Adds screenshot to message context
   - Transitions to `:introduce_and_discover` phase
   - Agent introduces itself, asks user intent

3. **Conversation Loop**
   - User sends message via chat
   - `:wait_for_user` step receives input
   - `:route_to_phase` agent analyzes request
   - Routes to appropriate phase (Discovery/Structure/Behavior/Polish)
   - Phase subroutine executes (uses TemplatedSemanticAgent)
   - Lens tools modify wireframe (if applicable)
   - Preview updates in real-time via PubSub
   - Returns to `:wait_for_user`

4. **Real-time Updates**
   - DOM changes → PubSub → Preview LiveView → Re-render
   - Screenshots captured after changes
   - State caches updated (DOM, console, variables)

### Message Flow

```
User Input → LiveView → PubSub → Engine → Step → Lens Tool →
LLM API → Response → Context Update → UI Update → User
```

---

## Key Design Decisions

### Why Phoenix LiveView?
- Real-time updates without custom WebSocket code
- Server-side rendering with client-side feel
- Built-in PubSub for event broadcasting
- Elixir/OTP for robust process management

### Why Custom Engine?
- Need for complex, stateful conversation flows
- Dynamic routing between phases
- Tool execution with state management
- Reusable patterns (subroutines)

### Why Lenses?
- Separation of concerns (tools vs. execution)
- Composable perspectives on same data
- Easy to add new capabilities
- Clear API for LLM tool use

### Why Ephemeral Sessions?
- Simplicity (no database for MVP)
- Fast startup
- Privacy (no stored data)
- Easy deployment

---

## Infrastructure

### Parsers

*(To be documented)*

- HTML Parser: Extract structure, styles, scripts
- JavaScript Parser: Parse and extract functions

### Caches

*(To be documented)*

- ScreenshotCache: Store PNG screenshots
- DOMStateCache: Live DOM snapshots
- ConsoleCache: JavaScript console output
- VariableStateCache: Tracked JS variables

### Credentials

*(To be documented)*

- SimpleCredentialManager: OAuth token management
- DemoCredentialStore: File-based API key storage

---

## Future Architecture

*(Potential improvements, not committed)*

- Persistent storage layer (PostgreSQL + Ecto)
- Multi-routine support
- Routine builder/editor
- Plugin system for custom lenses
- Distributed execution (for scaling)
- Event sourcing for routine replay

---

## Notes

This document will be updated as we build the system. Each section marked *(To be documented)* will be filled in as we port and understand that component.
