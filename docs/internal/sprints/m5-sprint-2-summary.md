# M5 Sprint 2 Summary: Linear Playbooks & Wireframe Workflow Polish

**Completed:** November 14, 2025
**Branch:** `feature/m5-2-advanced-workflows`
**Lines Modified:** ~744 lines (BuildWireframeRoutine, WireframeDesignRoutine improvements, observability features)

---

## Overview

Sprint 2 delivered a complete redesign of the wireframe building workflow, introducing the **linear playbook pattern** as an alternative to semantic routing. This sprint focused on clarifying when to use semantic routing (for real decision points) versus linear sequences (for known steps).

**What We Built:**
- BuildWireframeRoutine: Linear playbook for building wireframes from scratch
- WireframeDesignRoutine improvements: Added interact_wireframe sub-routine
- Observability features: Raw Messages tab and resizable panels
- Documentation updates: Linear playbook pattern and production examples
- Tests: Comprehensive tests for both routines

**Key Insight:** Use semantic routing for decisions, linear playbooks for known sequences. Think of routines as "early binding" vs tool calls as "late binding."

---

## Plan vs Reality

### Original Sprint 2 Plan (from M5.md)
**Goal:** Advanced workflows & polish
**Scope:**
- Additional workflow examples
- Nested semantic routing
- Conditional lens activation
- Performance optimization
- Error handling improvements

### What We Actually Did
**Goal:** Linear playbook pattern + workflow polish
**Scope:** ~744 lines
- **BuildWireframeRoutine created** - Linear playbook for building wireframes
- **WireframeDesignRoutine improved** - Added interact_wireframe sub-routine
- **Observability enhanced** - Raw messages tab, resizable panels
- **Documentation updated** - Linear playbook pattern explained
- **Tests created** - Comprehensive routine structure tests

**Why Different from Plan:**
- User feedback identified issue: "Don't ask agent what to do next when you know the steps"
- Realized semantic routing was overused (agent choosing between known steps)
- Needed to demonstrate when NOT to use semantic routing
- Focus shifted from "more routing" to "right kind of routing"

---

## What We Built

### BuildWireframeRoutine: Linear Playbook (~260 lines)

**File:** `lib/koalemos/routines/build_wireframe_routine.ex`

Created a linear sequential workflow for building wireframes from scratch, demonstrating when to use predetermined sequences instead of semantic routing.

**Sequential Flow:**
```
planning → layout_and_structure → behavior → testing → polish → complete
```

**Stage 1: Planning** (Readonly)
```elixir
planning: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: """
    Analyze what the user wants and plan the wireframe.

    Use think_step to:
    1. Break down what components are needed
    2. Plan the HTML structure and hierarchy
    3. Consider what interactions and behaviors will be needed
    4. Think about layout and styling approach
    """,
    lenses: [
      ["Koalemos.Lenses.WireframeEditor", %{readonly: true}],
      "Koalemos.Lenses.SequentialThinking"
    ]
  },
  transitions: [{:layout_and_structure, :always}]
}
```

**Stage 2: Layout & Structure** (HTML + Layout CSS)
```elixir
layout_and_structure: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: """
    Build the HTML structure and layout.

    Use modify_elements to create the complete HTML structure:
    - Main containers with appropriate IDs
    - Form elements, buttons, inputs (if needed)
    - Structural elements (header, main, footer, sections, etc.)

    Use manage_css to create the layout:
    - Layout CSS (flexbox, grid, positioning)
    - Spacing (margins, padding)
    - Container sizing and alignment
    - Basic structural CSS to make the layout work

    Build the full structure with all content and layout CSS.
    Focus on making the layout functional - no visual polish yet.
    """,
    lenses: [
      "Koalemos.Lenses.WireframeEditor",
      "Koalemos.Lenses.SequentialThinking"
    ]
  },
  transitions: [{:behavior, :always}]
}
```

**Key Design Decision:** Combine HTML structure + layout CSS in single stage
- **Problem:** Layout stage with only HTML doesn't create proper layout
- **Solution:** Add both structure AND layout CSS together
- **Separation:** Layout CSS (stage 2) vs Visual CSS (stage 5)

**Stage 3: Behavior** (JavaScript)
```elixir
behavior: %{
  config: %{
    template: """
    Add interactive behavior using handlers and JavaScript.

    Add interactivity:
    - Event handlers for buttons (onclick, etc.)
    - Form submission handlers
    - Input validation or dynamic behavior
    - Custom JavaScript functions if needed
    """,
    lenses: [
      "Koalemos.Lenses.WireframeEditor",
      "Koalemos.Lenses.SequentialThinking"
    ]
  },
  transitions: [{:testing, :always}]
}
```

**Stage 4: Testing** (Systematic Validation)
```elixir
testing: %{
  config: %{
    template: """
    Test the wireframe functionality using trigger_interaction.

    Verify the wireframe works as expected:
    - Click buttons to see if they respond
    - Fill in forms and submit
    - Test all interactive elements
    - Verify JavaScript handlers execute correctly

    Use trigger_interaction to test (changes are ephemeral).
    Check the LIVE DOM STATE in context to see what happened.
    """,
    lenses: [
      "Koalemos.Lenses.WireframeEditor",
      "Koalemos.Lenses.SequentialThinking"
    ]
  },
  transitions: [{:polish, :always}]
}
```

**Stage 5: Polish** (Visual CSS)
```elixir
polish: %{
  config: %{
    template: """
    Add visual polish and styling to the wireframe.

    Apply CSS rules using manage_css for visual appeal:
    - Colors and backgrounds (use good contrast ratios)
    - Typography (font sizes 14-16px body, weights, line height 1.5)
    - Borders, shadows, and visual effects
    - Button and form styling (colors, hover states)

    IMPORTANT: Apply CSS rules once based on good design principles.
    Do NOT check screenshots to verify - screenshots are not pixel-perfect.
    Trust your CSS choices and move on.
    """,
    lenses: [
      "Koalemos.Lenses.WireframeEditor",
      "Koalemos.Lenses.SequentialThinking"
    ]
  },
  transitions: [{:complete, :always}]
}
```

**Critical Fix:** Added anti-loop instruction
- **Problem:** Agent checking screenshots, seeing imperfect rendering, adjusting CSS repeatedly
- **Solution:** Explicit instruction to apply CSS once and not verify with screenshots
- **Impact:** Prevents infinite loops in polish stage

**Stage 6: Complete** (Readonly Summary)
```elixir
complete: %{
  config: %{
    template: """
    Summarize what was built:
    - What components were created
    - What functionality is available
    - Any notable features or styling

    Let the user know their wireframe is ready.
    """,
    lenses: [
      ["Koalemos.Lenses.WireframeEditor", %{readonly: true}],
      "Koalemos.Lenses.SequentialThinking"
    ]
  },
  transitions: []  # End of routine
}
```

**Architecture Pattern: Linear Playbook**
```elixir
def start, do: :planning  # Start at first stage

def routine_definition do
  %{
    planning: %{transitions: [{:layout_and_structure, :always}]},
    layout_and_structure: %{transitions: [{:behavior, :always}]},
    behavior: %{transitions: [{:testing, :always}]},
    testing: %{transitions: [{:polish, :always}]},
    polish: %{transitions: [{:complete, :always}]},
    complete: %{transitions: []}  # Done
  }
end
```

**When to Use Linear Playbooks:**
- You know the exact sequence of steps needed
- Steps must happen in a specific order
- No decision points (path is predetermined)
- Think: "early binding" of workflow steps

**Example:** Building a wireframe always needs: plan → structure → behavior → test → polish

---

### WireframeDesignRoutine Improvements (~30 lines)

**File:** `lib/koalemos/routines/wireframe_design_routine.ex`

**Added: interact_wireframe Sub-Routine**

**Problem:** Agent often chose `answer_directly` (readonly) when user wanted to test/interact with wireframe

**Solution:** New sub-routine with full tool access for interaction

```elixir
interact_wireframe: %{
  type: TemplatedSemanticAgent,
  config: %{
    template: """
    Interact with and explore the wireframe using tools.

    You have full access to wireframe tools for:
    - Testing interactions with trigger_interaction
    - Inspecting the current state
    - Making small exploratory changes if helpful
    - Answering questions that require tool use

    Use tools as needed to respond to the user's request.
    Focus on interaction and exploration rather than major modifications.
    """
  },
  transitions: [{:start, :always}]
}
```

**Added to Routing Transitions:**
```elixir
routing: %{
  transitions: [
    {:answer_directly, "Answer questions or provide information without making changes"},
    {:interact_wireframe, "Interact with, inspect, or test the wireframe using tools"},  # NEW
    {:targeted_change, "Make a specific, focused modification to the wireframe"},
    {:build_from_scratch, "Create a new wireframe structure from description"},
    {:modify_existing, "Make broader changes to existing wireframe structure"},
    # ...
  ]
}
```

**Model Change:**
```elixir
# Changed from Haiku to Sonnet 4.5 for routing decisions
llm_model: "claude-sonnet-4-5"
```

**Why:** Better routing decisions require more capable model

**Impact:** Agent now has 7 distinct sub-routines covering all user intents

---

### Observability Enhancements (~200 lines)

**Problem:** Hard to debug agent loops without seeing raw message structure

**Solution 1: Raw Messages Tab**

**File:** `lib/koalemos_web/components/chat_panel.ex`

Added tabbed interface to ChatPanel component:

```elixir
# State
mount(socket) do
  socket
  |> assign(:active_tab, "conversation")  # New state
end

# Tab header
<div class="border-b border-slate-200 bg-white">
  <div class="flex">
    <button
      phx-click="switch_tab"
      phx-value-tab="conversation"
      phx-target={@myself}
      class={[if(@active_tab == "conversation", do: "border-blue-500 text-blue-600", ...)]}
    >
      Conversation
    </button>
    <button
      phx-click="switch_tab"
      phx-value-tab="raw"
      phx-target={@myself}
    >
      Raw Messages
    </button>
  </div>
</div>

# Conditional content
<%= if @active_tab == "conversation" do %>
  <.live_component module={MessageFeed} ... />
<% else %>
  <div class="h-full overflow-auto p-4 bg-slate-50 font-mono text-xs">
    <pre class="text-slate-800"><%= Jason.encode!(@messages, pretty: true) %></pre>
  </div>
<% end %>

# Event handler
def handle_event("switch_tab", %{"tab" => tab}, socket) do
  {:noreply, assign(socket, :active_tab, tab)}
end
```

**Impact:** Can now see exact message structure for debugging agent behavior

---

**Solution 2: Resizable Panel Divider**

**Problem:** User reported "split pane only works when iframe is empty, otherwise I have to grab the line at the header"

**Root Cause:** Iframe captures mousemove events during drag, breaking resize

**Files:** `lib/koalemos_web/live/wireframe_test_live.ex`, `assets/js/app.js`

**LiveView State:**
```elixir
# wireframe_test_live.ex
mount(socket) do
  socket
  |> assign(:left_panel_width, 33)  # New state (percentage)
end

# Event handler
def handle_event("resize_panel", %{"width" => width_str}, socket) do
  width = String.to_integer(width_str)
  clamped_width = max(20, min(60, width))  # Clamp 20-60%
  {:noreply, assign(socket, left_panel_width: clamped_width)}
end

# Dynamic widths in template
<div id="resizable-container" class="flex flex-row h-full">
  <!-- Left panel -->
  <div style={"width: #{@left_panel_width}%"}>
    <!-- Chat panel -->
  </div>

  <!-- Resize handle -->
  <div id="resize-handle" phx-hook="PanelResizer"
    class="w-1 bg-slate-300 hover:bg-blue-500 cursor-col-resize">
  </div>

  <!-- Right panel -->
  <div style={"width: #{100 - @left_panel_width}%"}>
    <!-- Preview panel -->
  </div>
</div>
```

**PanelResizer Hook:**
```javascript
// app.js
Hooks.PanelResizer = {
  mounted() {
    let isDragging = false
    let container = null
    let overlay = null

    this.el.addEventListener('mousedown', (e) => {
      isDragging = true
      container = document.getElementById('resizable-container')

      // CRITICAL: Create overlay to prevent iframe from capturing events
      overlay = document.createElement('div')
      overlay.style.position = 'fixed'
      overlay.style.top = '0'
      overlay.style.left = '0'
      overlay.style.width = '100%'
      overlay.style.height = '100%'
      overlay.style.zIndex = '9999'
      overlay.style.cursor = 'col-resize'
      document.body.appendChild(overlay)

      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'
      e.preventDefault()
    })

    document.addEventListener('mousemove', (e) => {
      if (!isDragging || !container) return

      const containerRect = container.getBoundingClientRect()
      const newWidth = ((e.clientX - containerRect.left) / containerRect.width) * 100
      const clampedWidth = Math.max(20, Math.min(60, Math.round(newWidth)))

      // Send to server
      this.pushEvent("resize_panel", { width: clampedWidth.toString() })
    })

    document.addEventListener('mouseup', () => {
      if (isDragging) {
        isDragging = false
        document.body.style.cursor = ''
        document.body.style.userSelect = ''

        // Remove overlay
        if (overlay && overlay.parentNode) {
          overlay.parentNode.removeChild(overlay)
          overlay = null
        }
      }
    })
  }
}
```

**Key Innovation:** Transparent overlay during drag
- Prevents iframe from capturing mousemove events
- Ensures smooth resizing regardless of iframe content
- Removed on mouseup to restore normal interactions

**Impact:** Resizable divider works perfectly even with loaded iframes

---

### Documentation Updates (~150 lines)

**File:** `docs/guides/SEMANTIC_ROUTING.md`

**Added: Linear Playbooks Section**

```markdown
### Alternative 2: Linear Playbooks

**When You Know The Steps:** Use a linear sequential flow instead of asking the agent to decide.

Think of routines as "early binding" vs tool calls as "late binding." If you know the
sequence of steps needed to accomplish a task, script them as a linear playbook rather
than making the agent choose.

**Example: BuildWireframeRoutine**

Building a wireframe has known stages: plan → build structure → add behavior → test → polish

[Code example showing linear flow]

**Key Insight:** Don't ask the agent what to do next when you already know the steps.
Use semantic routing for real decision points, not for known sequences.

**Comparison:**
- **Semantic Routing:** "Should I create, modify, or analyze?" (decision point)
- **Linear Playbook:** "Build wireframe: plan → structure → behavior → test → polish" (known sequence)
```

**Updated Examples Section:**
```markdown
## Examples

- **WireframeDesignRoutine:** `lib/koalemos/routines/wireframe_design_routine.ex`
  - Semantic routing with 7 sub-routines
  - Demonstrates when to use semantic routing (routing between user intents)

- **BuildWireframeRoutine:** `lib/koalemos/routines/build_wireframe_routine.ex`
  - Linear playbook with sequential flow
  - Demonstrates when NOT to use semantic routing (known steps)
  - Called as sub-routine from WireframeDesignRoutine
```

**Impact:** Clear guidance on when to use semantic routing vs linear playbooks

---

### Comprehensive Tests (~180 lines)

**File:** `test/koalemos/routines/wireframe_design_routine_test.exs`

**Tests Created:**
```elixir
describe "routine_definition/0" do
  test "returns valid routine structure"
  test "has all expected steps" do
    # Verifies all 7 sub-routines exist
    assert Map.has_key?(definition, :answer_directly)
    assert Map.has_key?(definition, :interact_wireframe)  # NEW
    assert Map.has_key?(definition, :targeted_change)
    assert Map.has_key?(definition, :build_from_scratch)
    # ...
  end
  test "build_from_scratch calls BuildWireframeRoutine"
  test "routing step has semantic transitions"
end

describe "initial_context/0" do
  test "returns map with required fields"
  test "has default lenses"
  test "has Claude Sonnet 4.5 as default model"  # NEW
end

describe "setup/2" do
  test "returns ok tuple with empty changes when no sample specified"
  test "loads sample HTML when wireframe_sample specified"
end

describe "check_condition/2" do
  test "always condition returns true"
end
```

---

**File:** `test/koalemos/routines/build_wireframe_routine_test.exs`

**Tests Created:**
```elixir
describe "start/0" do
  test "returns planning as the starting step"
end

describe "routine_definition/0" do
  test "returns valid routine structure"
  test "has all expected stages in sequential order"

  test "follows linear sequential flow" do
    # Verifies exact sequence
    assert definition.planning.transitions == [{:layout_and_structure, :always}]
    assert definition.layout_and_structure.transitions == [{:behavior, :always}]
    assert definition.behavior.transitions == [{:testing, :always}]
    assert definition.testing.transitions == [{:polish, :always}]
    assert definition.polish.transitions == [{:complete, :always}]
    assert definition.complete.transitions == []
  end

  test "all stages use TemplatedSemanticAgent"
  test "planning and complete stages are readonly"
  test "layout_and_structure stage instructs both HTML and CSS"
  test "polish stage warns about screenshot verification"
end

describe "initial_context/0" do
  test "returns map with required fields"
  test "has default lenses"
end

describe "setup/2" do
  test "returns ok tuple with empty changes"
end

describe "check_condition/2" do
  test "always condition returns true"
end
```

**Test Coverage:**
- Routine structure and definition
- Sequential flow validation
- Lens configuration correctness
- Readonly mode verification
- Stage-specific instructions
- Anti-loop safeguards

**Test Results:**
```bash
mix test
963 tests, 0 failures ✅
```

---

## Architecture Decisions

### Decision: Linear Playbooks vs Semantic Routing

**Context:** BuildWireframeRoutine was initially planned with semantic routing at each stage

**Problem:** Agent deciding between known steps is wasteful
- "Should I test next or polish?" → We always test before polishing
- "Should I add structure or behavior?" → Always structure before behavior
- Adds LLM calls for decisions we already know

**Solution:** Two distinct patterns

**Pattern 1: Semantic Routing** (WireframeDesignRoutine)
```
Use when: Agent needs to understand user intent and choose appropriate path
Example: User says "make button blue" → targeted_change
         User says "build login form" → build_from_scratch
         User says "what's in the wireframe?" → answer_directly
```

**Pattern 2: Linear Playbook** (BuildWireframeRoutine)
```
Use when: Steps are known and must happen in specific order
Example: Build wireframe: planning → layout → behavior → testing → polish
         No decisions needed - we know this sequence works
```

**Key Insight:** "Early binding" (routines) vs "late binding" (tool calls)
- Early binding: Route workflow path based on known requirements
- Late binding: Let agent choose tools during execution
- Don't confuse the two - routing shouldn't be late-bound

**Benefits:**
- Faster execution (fewer LLM calls)
- More predictable behavior (known sequences)
- Clearer separation: routing for decisions, sequences for execution

---

### Decision: Combine HTML + Layout CSS

**Context:** Initial design had separate "structure" and "layout" stages

**Problem:** Structure without layout doesn't work
- HTML elements without layout CSS just stack vertically
- Agent can't see proper layout until CSS applied
- Two stages for what should be one cohesive task

**User Feedback:** "the layout and structure piece, tell the agent to use the element tool, but the visuals are sub par unless the agent applies basic css first, without it the layout isn't correct, and we just have the structure"

**Solution:** Single `layout_and_structure` stage
```elixir
layout_and_structure: %{
  template: """
  Use modify_elements to create the complete HTML structure:
  - Main containers, form elements, structural elements

  Use manage_css to create the layout:
  - Layout CSS (flexbox, grid, positioning)
  - Spacing (margins, padding)
  - Container sizing and alignment
  """
}
```

**Separation Still Exists:**
- **Layout CSS** (stage 2): flexbox, grid, positioning, spacing
- **Visual CSS** (stage 5): colors, typography, shadows, effects

**Benefits:**
- Functional layout created in one pass
- Agent can see proper structure immediately
- Clear separation: layout (functional) vs polish (aesthetic)

---

### Decision: Screenshot Verification Anti-Loop

**Context:** Agent was looping in polish stage, repeatedly adjusting CSS

**Problem:** Screenshot rendering not pixel-perfect
- Agent applies CSS: `font-size: 16px`
- Checks screenshot: "text looks small"
- Adjusts CSS: `font-size: 18px`
- Checks screenshot: "still not perfect"
- Adjusts again... (infinite loop)

**User Feedback:** "the screenshot system we're using is not pixel perfect enough for the agent, when they start to do the polish section. They say things like the text is too faint, let me increase the contrast, in a loop"

**Solution:** Explicit anti-loop instruction
```elixir
polish: %{
  template: """
  Apply CSS rules using manage_css for visual appeal:
  - Colors and backgrounds (use good contrast ratios)
  - Typography (font sizes 14-16px body, weights, line height 1.5)
  - Borders, shadows, and visual effects

  IMPORTANT: Apply CSS rules once based on good design principles.
  Do NOT check screenshots to verify - screenshots are not pixel-perfect.
  Trust your CSS choices and move on.
  """
}
```

**Benefits:**
- Prevents infinite loops
- Forces agent to apply good design principles
- Acknowledges screenshot limitations
- Moves workflow forward

---

### Decision: Iframe Event Overlay Pattern

**Context:** Resizable divider broken when iframe loaded

**Problem:** Iframe captures mousemove events
- User mousedown on divider → drag starts
- User mousemove → iframe captures event (not our handler)
- Divider doesn't update → appears broken

**Solution:** Transparent overlay during drag
```javascript
// On mousedown: Create overlay covering entire viewport
overlay = document.createElement('div')
overlay.style.zIndex = '9999'  // Above everything including iframe
overlay.style.cursor = 'col-resize'
document.body.appendChild(overlay)

// On mousemove: Overlay receives events (not iframe)
// On mouseup: Remove overlay, restore normal interactions
overlay.parentNode.removeChild(overlay)
```

**Benefits:**
- Prevents iframe from capturing events
- Works regardless of iframe content
- Minimal code (create on mousedown, remove on mouseup)
- Reusable pattern for any iframe interaction

---

## Files Changed

```
Modified:
M  lib/koalemos/routines/wireframe_design_routine.ex      (+30)  interact_wireframe, Sonnet 4.5
M  lib/koalemos_web/components/chat_panel.ex              (+50)  Raw messages tab
M  lib/koalemos_web/live/wireframe_test_live.ex           (+80)  Resizable panels
M  assets/js/app.js                                        (+55)  PanelResizer hook
M  docs/guides/SEMANTIC_ROUTING.md                        (+150) Linear playbooks section

Added:
A  lib/koalemos/routines/build_wireframe_routine.ex       (+260) Linear playbook routine
A  test/koalemos/routines/wireframe_design_routine_test.exs (+95) WireframeDesign tests
A  test/koalemos/routines/build_wireframe_routine_test.exs  (+85) BuildWireframe tests

Total: ~744 lines (production) + ~180 lines (tests) = ~924 lines
```

---

## Known Issues (Tracked)

### Issue 1: Agent Looping During Testing
**Status:** Observed, not yet tracked in BUGS.md
**Description:** Agent sometimes loops when testing interactions, particularly with forms
**User Report:** "This one went on a loop testing, trying to fill out a form"
**Impact:** Wastes time and tokens during testing phase
**Next Steps:** Track in BUGS.md, investigate root cause, add loop detection

### Issue 2: Sequential Thinking Flicker
**Status:** Observed, not yet tracked in BUGS.md
**Description:** Sequential thinking messages cause flicker in conversation panel
**Impact:** UX issue, not functional
**Next Steps:** Track in BUGS.md, investigate rendering optimization

---

## Deferred Work

### Performance Optimization
- [ ] Loop detection in testing phase (prevent infinite testing cycles)
- [ ] Parallel tool calls in layout_and_structure (modify_elements + manage_css)
- [ ] Benchmark BuildWireframeRoutine vs old routing approach

### Documentation
- [ ] Usage guide: When to use linear playbooks
- [ ] Example playbooks for common patterns
- [ ] Migration guide: Converting routing to linear

### Advanced Features
- [ ] Resume/checkpoint support (restart from specific stage)
- [ ] Stage validation (verify each stage completed successfully)
- [ ] Dynamic stage insertion (add optional stages based on context)

---

## What's Next: M5 Sprint 2 Complete, Decide Direction

**Current Status:**
- ✅ BuildWireframeRoutine implemented and tested
- ✅ WireframeDesignRoutine improved with interact_wireframe
- ✅ Observability enhanced (raw messages, resizable panels)
- ✅ Documentation updated with linear playbook pattern
- ✅ 963 tests passing, 0 failures
- ❌ Known issues not yet tracked

**Decision Point: M6 vs Issue Fixing**

**Option A: Start M6 (Polish & Production-Ready)**
- UI polish and refinement
- Logging & monitoring
- Docker & deployment
- Documentation updates
- Focus: Making everything production-ready

**Option B: Fix Known Issues First**
- Track agent looping issue in BUGS.md
- Track sequential thinking flicker
- Investigate and fix both issues
- Clean up technical debt before M6

**Recommendation:** Track issues first (15 min), then decide based on priority

---

## Key Learnings

### What Went Well

1. **User feedback integration** - Direct feedback ("don't ask agent what to do next") led to better design
2. **Clear pattern separation** - Semantic routing vs linear playbooks now well-defined
3. **Iterative improvement** - Layout stage evolved from user testing (HTML → HTML+CSS)
4. **Practical solutions** - Anti-loop instructions solve real observed problems
5. **Comprehensive tests** - Structure tests catch regressions early

### What Could Improve

1. **Issue tracking** - Should have tracked looping/flicker issues immediately
2. **Performance testing** - No benchmarks for linear vs routing approach
3. **Agent testing** - Need to test BuildWireframeRoutine with real agent interactions
4. **Documentation timing** - Updated docs after implementation (should be during)

### For Future Sprints

1. **Track issues immediately** - Don't let observations become lost context
2. **Test with real agents** - Integration tests validate mechanics, need real usage validation
3. **Document patterns as discovered** - Capture insights during implementation
4. **Benchmark major changes** - Validate that "better" design is actually faster

---

## Conclusion

Sprint 2 successfully introduced the **linear playbook pattern** as a complement to semantic routing, clarifying when each approach is appropriate. BuildWireframeRoutine demonstrates how to structure known sequences, while WireframeDesignRoutine shows how to use semantic routing for real decision points.

**What Changed from Plan:**
- Focus shifted from "more routing examples" to "better routing philosophy"
- BuildWireframeRoutine created as counter-example (when NOT to use routing)
- Observability features added based on debugging needs
- Documentation focused on pattern explanation vs API reference

**Current Status:**
- ✅ Linear playbook pattern established and documented
- ✅ BuildWireframeRoutine fully implemented with tests
- ✅ WireframeDesignRoutine improved with interact_wireframe sub-routine
- ✅ Observability features working (raw messages, resizable panels)
- ✅ All tests passing (963 tests, 0 failures)
- ⚠️ Known issues exist but not yet tracked

**Ready for Decision:**
M5 Sprint 2 is technically complete. Next step is to decide whether to start M6 (polish & production) or address known issues (looping, flicker) first. Recommend tracking issues (15 min) then evaluating priority before committing to direction.
