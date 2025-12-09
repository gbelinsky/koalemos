# V4 Wireframe Editor Architecture

## Overview

V4 simplifies the wireframe editing architecture by using a StateServer as the single source of truth with direct Registry-based communication. This replaced the V3 architecture which used PubSub broadcasts and adapters, solving timing issues with init scripts and preview coordination.

## Key Principles

1. **No PubSub** - Direct process communication via Registry
2. **StateServer is single source of truth** - All state lives in one place
3. **Blocking operations** - `capture_state` and `execute_interaction` wait for completion
4. **Parsing in setup** - StateServer receives pre-parsed data from routine setup

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Routine                                  │
│  (WireframeDesignV4Routine, BuildWireframeV4Routine, etc.)      │
│                                                                  │
│  setup() starts StateServer with parsed HTML                     │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   WireframeStateServerV4                         │
│                      (Facade Module)                             │
│                                                                  │
│  API: update_designed, get_designed, capture_state,             │
│       execute_interaction, reload_preview                        │
└───────────────────┬─────────────────────┬───────────────────────┘
                    │                     │
          ┌────────▼────────┐   ┌────────▼────────┐
          │   StateStore    │   │ PreviewCoordinator │
          │   (GenServer)   │   │    (GenServer)     │
          │                 │   │                    │
          │ - designed      │   │ - preview_pid      │
          │ - running       │   │ - request queue    │
          │ - screenshot    │   │ - monitoring       │
          └────────┬────────┘   └────────┬───────────┘
                   │                     │
                   │    Registry Lookup  │
                   │    (WireframeV4Registry)
                   │                     │
┌──────────────────▼─────────────────────▼────────────────────────┐
│                    WireframeEditorV4 Lens                        │
│                                                                  │
│  9 Tools: modify_classes, modify_elements, manage_attributes,   │
│           manage_handlers, manage_functions, manage_variables,  │
│           manage_css, manage_init_scripts, trigger_interaction  │
│                                                                  │
│  Reuses: EditorCore for pure business logic                     │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ Direct calls to StateServer
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   WireframePreviewV4Live                         │
│                      (LiveView)                                  │
│                                                                  │
│  - Renders DOM tree from designed state                          │
│  - Registers with StateServer on "preview_ready"                 │
│  - Receives messages: capture_state, execute_interaction        │
│  - JS hook executes init scripts and attaches handlers          │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### WireframeStateServerV4 (Facade)

**File**: `lib/koalemos_web/servers/wireframe_state_server_v4.ex`

Main API for state coordination. Delegates to two specialized GenServers:

```elixir
# API examples
WireframeStateServerV4.start_link(routine_id: id, designed: parsed_html)
WireframeStateServerV4.update_designed(routine_id, %{dom_tree: new_tree})
WireframeStateServerV4.capture_state(routine_id, opts)
WireframeStateServerV4.execute_interaction(routine_id, %{action: "click", element_id: "btn"})
```

### StateStore (GenServer)

**File**: `lib/koalemos_web/servers/wireframe_state_server_v4/state_store.ex`

Pure state storage with three main sections:

- **designed**: DOM tree, handlers, init scripts, custom CSS/functions/variables
- **running**: Live DOM tree, runtime variables, console logs (captured from preview)
- **screenshot**: Base64 encoded PNG

Registered via `Koalemos.WireframeV4Registry` for direct process lookup.

### PreviewCoordinator (GenServer)

**File**: `lib/koalemos_web/servers/wireframe_state_server_v4/preview_coordinator.ex`

Manages preview lifecycle with two-state model:

- `preview_pid == nil`: Not ready, queue requests
- `preview_pid != nil`: Ready, process requests immediately

Handles:
- Preview registration and monitoring
- Request queuing when preview not ready
- Blocking `capture_state` and `execute_interaction` (waits for response)
- Reload signaling

### WireframeEditorV4 Lens

**File**: `lib/koalemos/lenses/wireframe_editor_v4.ex`

9 tools for editing wireframes. Key differences from V3:

- **No adapters**: Direct calls to StateServer
- **No PubSub**: StateServer handles all coordination
- **Blocking ops**: `capture_state`/`execute_interaction` wait for completion
- **Reuses EditorCore**: Pure business logic in `wireframe_v3/editor_core.ex`

### LiveViews

| LiveView | Route | Purpose |
|----------|-------|---------|
| `WireframeEditorV4Live` | `/wireframe-editor-v4/:routine_id` | Development/test interface |
| `WireframeEditorV4ProductionLive` | `/wireframe-editor-v4-production` | Production interface with config modal |
| `WireframePreviewV4Live` | `/wireframe-preview-v4/:routine_id` | Preview renderer (in iframe) |

### Routines

| Routine | Purpose |
|---------|---------|
| `WireframeDesignV4Routine` | Semantic routing (8 sub-routines: interact, play, debug, build, etc.) |
| `BuildWireframeV4Routine` | 5-stage linear build: planning → layout → behavior → testing → polish |
| `PlayV4Routine` | Tight interaction loop for playing with the wireframe |
| `WireframeEditorV4Routine` | Simple agent loop for basic editing |

## V4 vs V3 Comparison

| Aspect | V3 | V4 |
|--------|-----|-----|
| Communication | PubSub broadcasts | Direct Registry calls |
| State coordination | Adapters, timing-sensitive | StateServer facade, blocking ops |
| Init script timing | Race conditions | Parsing in setup, clean handoff |
| Preview lifecycle | Complex state machine | Two-state model (nil or pid) |
| Request handling | Fire-and-forget | Request queuing, blocking responses |

## File Locations

```
lib/koalemos_web/servers/
├── wireframe_state_server_v4.ex           # Facade API
└── wireframe_state_server_v4/
    ├── state_store.ex                     # State GenServer
    └── preview_coordinator.ex             # Preview coordination

lib/koalemos/lenses/
├── wireframe_editor_v4.ex                 # V4 Lens
└── wireframe_v3/
    └── editor_core.ex                     # Shared business logic

lib/koalemos/routines/
├── wireframe_design_v4_routine.ex         # Semantic routing
├── build_wireframe_v4_routine.ex          # 5-stage build
├── play_v4_routine.ex                     # Play loop
└── wireframe_editor_v4_routine.ex         # Simple loop

lib/koalemos_web/live/
├── wireframe_editor_v4_live.ex            # Dev interface
├── wireframe_editor_v4_production_live.ex # Production interface
└── wireframe_preview_v4_live.ex           # Preview renderer
```

## Request Flow Example

1. **User requests "add a button"**
2. `WireframeDesignV4Routine` routing step analyzes request
3. Routes to `targeted_change` sub-routine
4. Agent uses `modify_elements` tool from `WireframeEditorV4` lens
5. Lens calls `StateServer.update_designed(routine_id, updates)`
6. StateStore merges updates into designed state
7. Lens calls `StateServer.reload_preview(routine_id)`
8. PreviewCoordinator sends `:reload_preview` to preview LiveView
9. Preview LiveView redirects, re-mounts with fresh state
10. JS hook attaches handlers, executes init scripts
11. Preview sends `preview_ready` event
12. PreviewCoordinator flushes any queued requests
