# Wireframe Test Environment - Manual Validation Checklist

**M4 Sprint 1: Test Infrastructure Foundation**

This checklist provides a systematic way to manually validate the wireframe test infrastructure. Use this to ensure all components are working correctly before building the WireframeEditor lens in future sprints.

## Pre-Test Setup

- [ ] Server is running (`mix phx.server`)
- [ ] No compilation errors or warnings
- [ ] Test pages accessible at `/test`

---

## Validation Goal: Complex Wireframe as Target

**Primary Goal:** By the end of M4, we should be able to fully parse and edit `wireframe_complex.html`.

**Current State (Sprint 1):**
- Parsing test page cannot extract much from complex wireframe
- Reveals gaps in current HTMLParser and JavaScriptParser capabilities

**Target State (Sprint 8):**
- WireframeEditor lens fully parses complex wireframe
- Can extract complete DOM structure, all JavaScript functions/events, all CSS rules
- Can demonstrate full editing workflow on complex wireframe in demo

This validation checklist will be expanded in each sprint to track progress toward this goal.

---

## Part 1: Sample HTML Files

### Simple Wireframe (wireframe_simple.html)
- [ ] File exists at `test/fixtures/wireframe_simple.html`
- [ ] File contains valid HTML5 structure
- [ ] Contains expected elements:
  - [ ] Header with h1 "Welcome"
  - [ ] Main section with paragraph
  - [ ] Button with id "test-button"
  - [ ] Footer with text

### Medium Wireframe (wireframe_medium.html)
- [ ] File exists at `test/fixtures/wireframe_medium.html`
- [ ] File contains valid HTML5 structure
- [ ] Contains expected elements:
  - [ ] Header with title and description
  - [ ] Navigation menu with 4 links
  - [ ] 4 content sections (home, about, services, contact)
  - [ ] Contact form with inputs
  - [ ] Styled cards for services
- [ ] Contains internal CSS styles
- [ ] Styles applied correctly (colors, borders, spacing)

### Complex Wireframe (wireframe_complex.html)
- [ ] File exists at `test/fixtures/wireframe_complex.html`
- [ ] File contains valid HTML5 structure
- [ ] Contains expected elements:
  - [ ] Dashboard layout with sidebar and main content
  - [ ] 4 stat cards with dynamic values
  - [ ] Tabs with switching functionality
  - [ ] Data table with project information
  - [ ] Modal dialog for new projects
- [ ] Contains internal CSS styles with:
  - [ ] Grid layout
  - [ ] Animations and transitions
  - [ ] Responsive design patterns
- [ ] Contains JavaScript with:
  - [ ] Tab switching event listeners
  - [ ] Modal open/close functionality
  - [ ] Form submission handling
  - [ ] Console logging

---

## Part 2: WireframeTestLive Page

### Navigation
- [ ] Test index page lists "Wireframe Test Environment"
- [ ] Clicking the card navigates to `/test/wireframe`
- [ ] Back button on wireframe test page returns to `/test`

### Page Layout
- [ ] Page loads without errors
- [ ] Header displays correct title: "Wireframe Test Environment"
- [ ] Subtitle mentions "M4 Sprint 1"
- [ ] Instructions panel explains how to use the page
- [ ] Page split into left control panel (1/3) and right preview (2/3)

### Control Panel (Left Side)
- [ ] "Sample HTML Files" section visible
- [ ] 3 sample buttons displayed:
  - [ ] Simple Wireframe
  - [ ] Medium Wireframe
  - [ ] Complex Wireframe
- [ ] "Actions" section visible with:
  - [ ] "Clear Preview" button (disabled when no wireframe loaded)
- [ ] "Status" section shows:
  - [ ] Current Sample: None (initially)
  - [ ] HTML Size (when wireframe loaded)
- [ ] "Coming in Future Sprints" section lists:
  - [ ] WireframeEditor lens integration
  - [ ] Real-time HTML editing
  - [ ] DOM manipulation tools
  - [ ] JavaScript handler testing
  - [ ] CSS modification tools

### Preview Panel (Right Side)
- [ ] Empty state displayed initially:
  - [ ] Document icon
  - [ ] "No wireframe loaded" message
  - [ ] Instructions to select a sample
- [ ] Preview header shows "HTML Preview (Iframe)"

### Loading Sample Wireframes

#### Simple Wireframe
- [ ] Click "Simple Wireframe" button
- [ ] Button becomes highlighted (blue border)
- [ ] Status updates:
  - [ ] Current Sample: "simple"
  - [ ] HTML Size displayed (should be < 1 KB)
- [ ] Header shows "Loaded: Simple Wireframe"
- [ ] Preview panel displays HTML in iframe:
  - [ ] Header, main content, and footer visible
  - [ ] Button rendered correctly
  - [ ] Basic layout works

#### Medium Wireframe
- [ ] Click "Medium Wireframe" button
- [ ] Button becomes highlighted
- [ ] Status updates to "medium"
- [ ] HTML Size displayed (should be ~2-3 KB)
- [ ] Preview panel displays HTML with:
  - [ ] Styled header and navigation
  - [ ] Multiple sections visible
  - [ ] Cards with proper styling
  - [ ] Form elements rendered
  - [ ] CSS styles applied correctly
  - [ ] Scrolling works if content overflows

#### Complex Wireframe
- [ ] Click "Complex Wireframe" button
- [ ] Button becomes highlighted
- [ ] Status updates to "complex"
- [ ] HTML Size displayed (should be ~10-15 KB)
- [ ] Preview panel displays dashboard with:
  - [ ] Sidebar with menu items
  - [ ] 4 stat cards with values
  - [ ] Tabs (All Projects, Active, Completed, Archived)
  - [ ] Data table with projects
  - [ ] Gradient background
  - [ ] All CSS styles applied
- [ ] JavaScript functionality works:
  - [ ] Clicking tabs switches content
  - [ ] Tab animations visible
  - [ ] Sidebar "New Project" button opens modal
  - [ ] Modal close button works
  - [ ] Clicking outside modal closes it
  - [ ] Form buttons functional
  - [ ] Refresh button shows loading state

### Switching Between Samples
- [ ] Can switch from simple to medium
- [ ] Can switch from medium to complex
- [ ] Can switch from complex to simple
- [ ] Only one button highlighted at a time
- [ ] Status updates correctly on each switch
- [ ] Preview updates immediately

### Clear Functionality
- [ ] "Clear Preview" button enabled when wireframe loaded
- [ ] Clicking "Clear Preview" button:
  - [ ] Removes preview from iframe
  - [ ] Shows empty state again
  - [ ] Resets status to "None"
  - [ ] Removes "Loaded:" indicator from header
  - [ ] Disables "Clear Preview" button
  - [ ] Deselects sample button

### Error Handling
- [ ] No console errors when loading any sample
- [ ] No warnings in Phoenix logs
- [ ] If sample file missing, error message displayed
- [ ] Page doesn't crash on errors

---

## Part 3: WireframeTestRoutine

### Routine Definition
- [ ] Module exists at `lib/koalemos/routines/wireframe_test_routine.ex`
- [ ] `routine_definition/0` returns valid routine structure
- [ ] Routine includes required steps:
  - [ ] start (ChatUserInput)
  - [ ] render_lens (LensRendering)
  - [ ] llm_request (LLMRequest)
  - [ ] parse_response (ResponseParsing)
- [ ] All transitions defined correctly

### Initial Context
- [ ] `initial_context/0` returns map with defaults:
  - [ ] messages: []
  - [ ] active_lenses: []
  - [ ] llm_provider: "anthropic"
  - [ ] llm_model: "claude-haiku-4-5"
  - [ ] max_tokens: 2000
  - [ ] temperature: 0.7
  - [ ] wireframe_html: nil
  - [ ] wireframe_sample: nil

### Sample Loading
- [ ] Can initialize with wireframe_sample: "simple"
- [ ] Sample HTML loaded into wireframe_html context
- [ ] Can initialize with wireframe_sample: "medium"
- [ ] Can initialize with wireframe_sample: "complex"
- [ ] Invalid sample logs warning but doesn't crash
- [ ] Can provide custom HTML via wireframe_html parameter

### Integration (Manual Test via IEx)
```elixir
# In iex -S mix:
alias Koalemos.Routines.WireframeTestRoutine
alias Koalemos.EngineManager

# Test 1: Default initialization
context1 = WireframeTestRoutine.initial_context()
{:ok, _pid} = EngineManager.start_routine("test-1", WireframeTestRoutine, context1)

# Test 2: With sample
context2 = WireframeTestRoutine.initial_context(%{wireframe_sample: "simple"})
{:ok, _pid} = EngineManager.start_routine("test-2", WireframeTestRoutine, context2)

# Test 3: With custom HTML
context3 = WireframeTestRoutine.initial_context(%{wireframe_html: "<html><body>Test</body></html>"})
{:ok, _pid} = EngineManager.start_routine("test-3", WireframeTestRoutine, context3)
```

- [ ] Test 1: Routine starts without errors
- [ ] Test 2: Routine starts with sample loaded
- [ ] Test 3: Routine starts with custom HTML
- [ ] All routines can be listed via `EngineManager.list_routines()`
- [ ] No crashes or error logs

---

## Part 4: Documentation

### M4.md File
- [ ] File exists at `docs/milestones/M4.md`
- [ ] Sprint 1 section complete with:
  - [ ] Goal clearly stated
  - [ ] Components list with line estimates
  - [ ] Testing section
  - [ ] Success criteria
- [ ] All 8 sprints documented
- [ ] WireframeEditor modular architecture explained
- [ ] Attribution section for SequentialThinking
- [ ] Line count summary table accurate

---

## Part 5: Parsing Test Validation

### Test with Existing Parsing Infrastructure
Validate current parsing capabilities against our samples to establish baseline:

#### Load Complex Wireframe in Parsing Test Page
- [ ] Navigate to `/test/parsing`
- [ ] Load `wireframe_complex.html` file
- [ ] Verify parsing results:
  - [ ] DOM extraction results visible
  - [ ] JavaScript parsing results visible
  - [ ] Note what's extracted vs. what's missed

#### Expected Current State (Sprint 1)
- [ ] Basic DOM structure extracted but incomplete
- [ ] Some JavaScript functions found but not all
- [ ] Event listeners may be missed
- [ ] CSS parsing limited or absent
- [ ] Complex nested structures not fully captured

#### Document Gaps
Create notes on what parsing improvements are needed:
- [ ] Which DOM elements are missed?
- [ ] Which JavaScript patterns aren't detected?
- [ ] Which event handlers aren't found?
- [ ] What CSS information is lost?

These gaps will guide Sprint 4-7 implementation priorities.

---

## Part 6: Code Quality

### Code Style
- [ ] All modules have @moduledoc documentation
- [ ] All public functions have @doc documentation
- [ ] Code follows Elixir formatting conventions
- [ ] No compiler warnings
- [ ] No credo warnings (if running credo)

### File Organization
- [ ] Sample HTML files in `test/fixtures/`
- [ ] WireframeTestLive in `lib/koalemos_web/live/`
- [ ] WireframeTestRoutine in `lib/koalemos/routines/`
- [ ] Validation checklist in `test/fixtures/`
- [ ] M4.md in `docs/milestones/`

---

## Success Criteria Summary

✅ Sprint 1 is considered successful when:

1. **Infrastructure Complete:**
   - All 3 sample HTML files created and valid
   - WireframeTestLive page fully functional
   - WireframeTestRoutine can start and run
   - Manual validation checklist comprehensive

2. **User Experience:**
   - Can navigate to test page easily
   - Can load and preview all samples
   - UI is clean and functional
   - No errors or crashes

3. **Foundation for Future:**
   - Clear extension points for WireframeEditor lens
   - Documented architecture for modular development
   - Test infrastructure ready to expand

4. **Documentation:**
   - M4.md complete with all sprint plans
   - Code well-documented
   - Validation checklist comprehensive

---

## Notes for Future Sprints

### Sprint 2 (PersonaLens)
- Will add persona testing to this environment
- May need additional test routines

### Sprint 3 (SequentialThinking)
- Will add thinking step visualization
- May need additional UI components

### Sprints 4-7 (WireframeEditor)
- Will integrate WireframeEditor lens with this test page
- Will add real-time editing capabilities
- Will expand validation checklist with:
  - DOM manipulation tests
  - JavaScript modification tests
  - CSS modification tests
  - Integration tests across all handlers

### Sprint 8 (Integration)
- Final validation of all lenses working together
- Performance testing
- Complete documentation review

---

**Last Updated:** November 2, 2025
**Sprint:** M4 Sprint 1 - Test Infrastructure Foundation
**Validator:** [Name]
**Date Validated:** [Date]
**Result:** [ ] Pass / [ ] Fail
**Notes:**
