# WireframeEditor Manual Testing Guide - Feedback Loop Validation

**Version:** Sprint 8 (M4 Completion)
**Date:** November 10, 2025
**Purpose:** Validate complete feedback loop with real LLM agent through realistic scenarios

---

## Overview

This guide validates that agents can successfully:
1. **Build** interactive wireframes using all 9 tools
2. **Interact** with wireframes using `trigger_interaction`
3. **Observe** results via state capture (DOM, console, screenshots)
4. **Decide** next actions based on observed state

Unlike Sprint 6's tool-by-tool validation, this guide tests **complete workflows** that exercise the full agent feedback loop.

---

## Pre-Test Setup

### Prerequisites
- [ ] Server running: `mix phx.server`
- [ ] Navigate to: `http://localhost:4000/test/wireframe`
- [ ] Browser DevTools open (Console tab visible)
- [ ] Valid LLM API key configured (Anthropic or OpenAI)
- [ ] No errors in server logs

### Initial State
1. **Load Simple Wireframe**
   - Click "Load Sample" → Select "simple"
   - [ ] Preview shows basic page
   - [ ] No errors in console

2. **Start Agent**
   - Click "Start Agent"
   - [ ] Chat panel appears
   - [ ] Preview remains visible
   - [ ] Agent sends initial greeting/understanding message

3. **Verify Baseline Functionality**
   - Send test message: "What wireframe are you editing?"
   - [ ] Agent describes the simple wireframe structure
   - [ ] Agent can see DOM structure in context

---

## Scenario 1: Build Tic-Tac-Toe Game (Complete Workflow)

**Objective:** Agent builds a playable tic-tac-toe game from scratch and validates it works by playing moves

**Estimated Time:** 15-20 minutes

### Step 1.1: Build Game Structure

**Prompt:**
```
Build a tic-tac-toe game with the following requirements:
1. 3x3 grid of cells (9 total cells), each cell should be a div with id "cell-0" through "cell-8"
2. Each cell should have a click handler that calls handleCellClick(cellId)
3. Add a div with id "status" to show game status messages
4. Style the grid so cells are visible (borders, dimensions)
5. Add a reset button with id "reset-btn"
```

**Expected Results:**
- [ ] Agent uses multiple tools: `modify_elements`, `manage_handlers`, `manage_css`, `manage_functions`
- [ ] Agent confirms building the game structure
- [ ] Preview updates to show 3x3 grid
- [ ] Each cell is visibly bordered/styled

**Verify in Preview:**
- [ ] 3x3 grid visible
- [ ] 9 cells with IDs cell-0 through cell-8
- [ ] Status div present
- [ ] Reset button present

**Time to complete:** ~5-8 agent turns

### Step 1.2: Implement Game Logic

**Prompt:**
```
Now implement the game logic:
1. Track game state (current player X or O, board state)
2. handleCellClick should mark the clicked cell with current player's symbol
3. Check for winner after each move (3 in a row)
4. Update status div with current player or winner
5. Prevent clicking already-filled cells
```

**Expected Results:**
- [ ] Agent uses `manage_variables`, `manage_functions`, `manage_init_scripts`
- [ ] Agent explains the game logic being added
- [ ] No JavaScript errors in console

**Verify Implementation:**
1. Open Browser DevTools → Console
2. Type: `window.boardState`
   - [ ] Should show array of 9 empty values
3. Type: `window.currentPlayer`
   - [ ] Should show "X" or "O"

**Time to complete:** ~5-10 agent turns

### Step 1.3: Test Game Interactivity

**Prompt:**
```
Test the game by triggering a click on cell-0. What happens?
```

**Expected Results - First Move:**
- [ ] Agent uses `trigger_interaction` tool with action "click" and element_id "cell-0"
- [ ] Agent receives success confirmation
- [ ] Agent then uses state capture to see results
- [ ] Agent reports seeing:
  - Cell-0 now contains "X" (in DOM)
  - Console shows click event log
  - Status updated to show next player's turn

**Verify in Preview:**
1. Look at cell-0:
   - [ ] Should show "X"
2. Look at status div:
   - [ ] Should say something like "Player O's turn"
3. Browser console:
   - [ ] Should show log like "Cell 0 clicked by Player X"

**Manual Verification:**
- Manually click cell-1 in preview
- [ ] Cell-1 fills with "O"
- [ ] Status updates to "Player X's turn"
- [ ] Console logs the move

**Time to complete:** ~3-5 agent turns

### Step 1.4: Multi-Move Testing

**Prompt:**
```
Continue testing: trigger clicks on cell-4 and then cell-1. Report what you observe after each move.
```

**Expected Results - Second Move (cell-4):**
- [ ] Agent triggers cell-4 click
- [ ] Agent captures state and reports:
  - Cell-4 now has "O"
  - Board state updated
  - Status shows "Player X's turn"

**Expected Results - Third Move (cell-1):**
- [ ] Agent triggers cell-1 click
- [ ] Agent captures state and reports:
  - Cell-1 now has "X"
  - Board state: cell-0="X", cell-1="X", cell-4="O"
  - Game continues

**Verify Feedback Loop:**
- [ ] Agent sees DOM changes after each interaction
- [ ] Agent sees console output for each move
- [ ] Agent can describe current board state accurately
- [ ] Agent understands game is progressing

**Time to complete:** ~5 agent turns

### Step 1.5: Win Detection

**Prompt:**
```
Trigger a click on cell-2 to complete three X's in the top row. What happens?
```

**Expected Results:**
- [ ] Agent triggers cell-2 click
- [ ] Agent captures state and reports:
  - Cell-2 now has "X"
  - Top row complete: cell-0="X", cell-1="X", cell-2="X"
  - Status shows "Player X wins!"
  - Console shows winner announcement
- [ ] Agent understands the game is over

**Verify Win State:**
- [ ] Status div shows winner message
- [ ] Console shows win detection log
- [ ] Top row has three X's

**Time to complete:** ~2-3 agent turns

### Scenario 1 Success Criteria:
- [ ] ✅ Agent built complete game structure
- [ ] ✅ Agent implemented game logic
- [ ] ✅ Agent successfully tested interactions
- [ ] ✅ Agent observed DOM changes after each move
- [ ] ✅ Agent observed console output
- [ ] ✅ Agent detected win condition
- [ ] ✅ Complete feedback loop working (build → interact → observe → decide)

**Total Time:** 15-20 minutes

---

## Scenario 2: Form Validation Workflow

**Objective:** Agent builds a form with validation, tests it, encounters errors, and fixes them

**Estimated Time:** 10-15 minutes

### Step 2.1: Build Login Form

**Prompt:**
```
Build a login form with:
1. Email input (id: "email-input")
2. Password input (id: "password-input")
3. Submit button (id: "submit-btn")
4. Error message div (id: "error-msg")
5. Success message div (id: "success-msg")
```

**Expected Results:**
- [ ] Agent builds form structure using `modify_elements`
- [ ] Agent adds appropriate styling with `manage_css`
- [ ] Form appears in preview

**Verify in Preview:**
- [ ] Email input visible
- [ ] Password input visible (masked)
- [ ] Submit button visible
- [ ] Error and success divs present (likely empty)

**Time to complete:** ~3-5 agent turns

### Step 2.2: Add Validation Logic

**Prompt:**
```
Add form validation:
1. Email must contain @ symbol
2. Password must be at least 8 characters
3. Show error in error-msg div if validation fails
4. Show success in success-msg div if validation passes
5. Log validation results to console
```

**Expected Results:**
- [ ] Agent uses `manage_functions` for validation logic
- [ ] Agent uses `manage_handlers` for submit button
- [ ] Agent explains validation rules

**Verify JavaScript:**
1. Open DevTools → Console
2. Type: `window.validateEmail("test@example.com")`
   - [ ] Should return true
3. Type: `window.validateEmail("invalid")`
   - [ ] Should return false

**Time to complete:** ~5-8 agent turns

### Step 2.3: Test Invalid Submission

**Prompt:**
```
Test the form by triggering a click on the submit button with empty fields. What happens?
```

**Expected Results:**
- [ ] Agent uses `trigger_interaction` to click submit
- [ ] Agent captures state and reports:
  - Error message displayed: "Email and password required" (or similar)
  - Console shows validation error
  - Form did not submit (no success message)

**Verify in Preview:**
- [ ] Error message div shows error text
- [ ] Error message is visible/styled (red text, etc.)
- [ ] Success message remains empty
- [ ] Console shows error log

**Manual Test:**
- Type invalid email (no @) and short password
- Click submit button manually
- [ ] Error message shows specific validation failure
- [ ] Console logs the error

**Time to complete:** ~3-4 agent turns

### Step 2.4: Fix and Re-Test

**Prompt:**
```
The form validation works but the error message isn't very specific. Update it to show which field failed validation (email format or password length). Then test with invalid email.
```

**Expected Results:**
- [ ] Agent modifies validation function
- [ ] Agent tests with invalid email
- [ ] Agent reports seeing specific error: "Email must contain @ symbol"
- [ ] Agent observes error in DOM and console

**Verify:**
- [ ] Error message is more specific
- [ ] Console output is clearer
- [ ] Agent successfully fixed and validated the improvement

**Time to complete:** ~4-5 agent turns

### Scenario 2 Success Criteria:
- [ ] ✅ Agent built form with validation
- [ ] ✅ Agent tested form and observed validation errors
- [ ] ✅ Agent saw error messages in both DOM and console
- [ ] ✅ Agent iteratively improved validation
- [ ] ✅ Feedback loop enabled debugging and improvement

**Total Time:** 10-15 minutes

---

## Scenario 3: JavaScript Error Recovery

**Objective:** Agent introduces a bug, sees the error, diagnoses it, and fixes it

**Estimated Time:** 8-12 minutes

### Step 3.1: Build Simple Counter

**Prompt:**
```
Build a simple counter:
1. Display div (id: "counter-display") showing the count (start at 0)
2. Increment button (id: "inc-btn")
3. Function incrementCounter() that increases count and updates display
```

**Expected Results:**
- [ ] Agent builds counter structure
- [ ] Agent adds JavaScript function
- [ ] Counter appears in preview

**Verify:**
- [ ] Counter displays "0"
- [ ] Increment button visible
- [ ] Manual click on button increments counter

**Time to complete:** ~3-4 agent turns

### Step 3.2: Introduce Bug

**Prompt:**
```
Update the incrementCounter function to use `.value` property instead of `.textContent` for the display div.
```

**Expected Results:**
- [ ] Agent updates function with buggy code
- [ ] Agent confirms change made
- [ ] Preview updates (but function is now broken)

**Time to complete:** ~1-2 agent turns

### Step 3.3: Trigger Bug

**Prompt:**
```
Test the counter by clicking the increment button. What happens?
```

**Expected Results:**
- [ ] Agent triggers click
- [ ] Agent captures state and reports:
  - **JavaScript error in console**: "Cannot set property 'value' of null" or similar
  - Counter did NOT increment (still shows 0)
  - Error level in console output
- [ ] Agent recognizes there's a problem

**Verify in Preview:**
- [ ] Counter still shows "0"
- [ ] Browser console shows red error message
- [ ] Agent context shows console error (❌ marker)

**Critical Validation:**
- [ ] Agent **sees the error in console output**
- [ ] Agent **understands something went wrong**

**Time to complete:** ~2-3 agent turns

### Step 3.4: Diagnose and Fix

**Prompt:**
```
There's an error. Look at the console output and fix the bug.
```

**Expected Results:**
- [ ] Agent analyzes error message
- [ ] Agent identifies the issue: divs don't have `.value` property
- [ ] Agent updates function to use `.textContent` instead
- [ ] Agent explains the fix

**Time to complete:** ~3-4 agent turns

### Step 3.5: Verify Fix

**Prompt:**
```
Test the counter again. Does it work now?
```

**Expected Results:**
- [ ] Agent triggers click
- [ ] Agent captures state and reports:
  - Counter now shows "1"
  - No errors in console
  - Success log showing increment
- [ ] Agent confirms fix worked

**Verify:**
- [ ] Counter increments properly
- [ ] No errors in console
- [ ] Manual clicks continue to work

**Time to complete:** ~2-3 agent turns

### Scenario 3 Success Criteria:
- [ ] ✅ Agent introduced a bug
- [ ] ✅ Agent **saw JavaScript error in console output**
- [ ] ✅ Agent diagnosed the error from console message
- [ ] ✅ Agent fixed the bug
- [ ] ✅ Agent verified fix worked
- [ ] ✅ Error feedback loop enables debugging

**Total Time:** 8-12 minutes

---

## Scenario 4: Screenshot Feedback

**Objective:** Verify agent can see and interpret screenshot data

**Estimated Time:** 5-8 minutes

### Step 4.1: Build Visual Element

**Prompt:**
```
Create a large colored box:
1. Div with id "color-box"
2. 200px by 200px
3. Background color red
4. Centered on page with margin
```

**Expected Results:**
- [ ] Agent builds the box
- [ ] Red box appears in preview

**Time to complete:** ~2-3 agent turns

### Step 4.2: Request Screenshot Observation

**Prompt:**
```
Capture the current state. Can you see the red box in the screenshot?
```

**Expected Results:**
- [ ] Agent uses state capture (includes screenshot by default)
- [ ] Agent describes seeing a red box in the visual state
- [ ] Agent can describe approximate size and position

**Note:** This validates that:
- Screenshots are being captured
- Screenshots are being sent to agent in context
- Agent (multimodal LLM) can interpret screenshots

**Manual Verification:**
1. Click "Agent Context" button in preview
2. Scroll to bottom
3. [ ] Screenshot image should be visible showing the red box

**Time to complete:** ~2-3 agent turns

### Step 4.3: Visual Change Validation

**Prompt:**
```
Change the box color to blue and verify the change with a screenshot.
```

**Expected Results:**
- [ ] Agent updates CSS
- [ ] Agent captures state
- [ ] Agent confirms seeing blue box in screenshot (not red)

**Verify:**
- [ ] Box is blue in preview
- [ ] Agent correctly identified the color change
- [ ] Screenshot feedback working

**Time to complete:** ~2-3 agent turns

### Scenario 4 Success Criteria:
- [ ] ✅ Agent can request/receive screenshots
- [ ] ✅ Agent can interpret screenshot content
- [ ] ✅ Agent can verify visual changes via screenshots
- [ ] ✅ Screenshot feedback loop working

**Total Time:** 5-8 minutes

---

## Scenario 5: Console Output Tracking

**Objective:** Verify agent sees console logs, warnings, and errors distinctly

**Estimated Time:** 5-8 minutes

### Step 5.1: Generate Different Log Levels

**Prompt:**
```
Create three buttons that log different message types:
1. Button (id: "log-btn") that logs: console.log("This is a log message")
2. Button (id: "warn-btn") that logs: console.warn("This is a warning")
3. Button (id: "error-btn") that logs: console.error("This is an error")
```

**Expected Results:**
- [ ] Agent creates three buttons
- [ ] Agent adds click handlers with console calls
- [ ] Buttons appear in preview

**Time to complete:** ~3-4 agent turns

### Step 5.2: Test Log Levels

**Prompt:**
```
Trigger a click on each button and report what you see in the console output.
```

**Expected Results:**
- [ ] Agent clicks log-btn, sees: ℹ️ log message
- [ ] Agent clicks warn-btn, sees: ⚠️ warning message
- [ ] Agent clicks error-btn, sees: ❌ error message
- [ ] Agent distinguishes between log levels

**Verify in Preview:**
- Click each button manually
- [ ] Browser console shows each message with appropriate styling
- [ ] Agent context shows messages with visual indicators

**Critical Validation:**
- [ ] Agent sees different markers for log/warn/error
- [ ] Agent can distinguish severity levels
- [ ] Console integration working correctly

**Time to complete:** ~3-4 agent turns

### Scenario 5 Success Criteria:
- [ ] ✅ Agent sees console logs (ℹ️)
- [ ] ✅ Agent sees console warnings (⚠️)
- [ ] ✅ Agent sees console errors (❌)
- [ ] ✅ Agent can distinguish log levels
- [ ] ✅ Console feedback detailed and accurate

**Total Time:** 5-8 minutes

---

## Post-Test Validation

### Overall Feedback Loop Validation
- [ ] Agent successfully completed all 5 scenarios
- [ ] Agent used all 9 tools appropriately
- [ ] Agent saw DOM changes after interactions
- [ ] Agent saw console output consistently
- [ ] Agent saw screenshots when needed
- [ ] Agent made decisions based on observed state
- [ ] No critical bugs discovered
- [ ] Error messages were clear and actionable

### Integration Validation
- [ ] State capture worked reliably (no timeouts)
- [ ] Console interception captured user code (not infrastructure)
- [ ] Screenshots captured correctly
- [ ] PubSub coordination worked smoothly
- [ ] Cache persistence worked across interactions

### Performance Observations
- [ ] State capture latency acceptable (<2 seconds)
- [ ] Screenshot capture didn't hang or timeout
- [ ] No memory leaks or performance degradation
- [ ] Preview remained responsive throughout testing

---

## Issues Log

### Critical Issues (Block M4)
| # | Scenario | Description | Severity | Status |
|---|----------|-------------|----------|--------|
| 1 | | | | |

### Non-Critical Issues (Post-M4)
| # | Scenario | Description | Severity | Status |
|---|----------|-------------|----------|--------|
| 1 | | | | |

### Improvements Identified
| # | Area | Description | Priority |
|---|------|-------------|----------|
| 1 | | | |

---

## Success Criteria Summary

**M4 Manual Testing Complete** when:
- [ ] All 5 scenarios pass with real LLM agent
- [ ] Complete feedback loop validated: build → interact → observe → decide
- [ ] No critical bugs blocking agent workflows
- [ ] Agent can successfully debug and fix errors
- [ ] Console, DOM, and screenshot feedback all working
- [ ] Documentation updated with findings

**Estimated Total Time:** 45-60 minutes for complete validation

---

## Next Steps After Testing

1. **Document Results** - Fill in issues log and improvements
2. **Update Sprint 8 Summary** - Include manual testing results
3. **Fix Critical Issues** - Address any blocking bugs found
4. **Update M4.md** - Mark manual testing complete
5. **Proceed to Phase 2** - Developer documentation with validated examples

---

## Notes for Tester

- **Be Patient:** Real LLM responses take 10-30 seconds
- **Let Agent Lead:** Don't manually fix issues, let agent discover and resolve
- **Observe Closely:** Watch what agent sees vs what you see in preview
- **Document Everything:** Note any unexpected behavior
- **Trust the Process:** Agent may take longer paths, that's okay

**Remember:** The goal is to validate the **agent's experience**, not the fastest path to completion.
