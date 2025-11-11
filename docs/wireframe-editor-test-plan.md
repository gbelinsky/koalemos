# WireframeEditor Test Plan - Tool Validation

**Version:** Sprint 6
**Date:** November 6, 2025
**Completed:** November 7, 2025 ✅
**Purpose:** Systematic validation of all 9 WireframeEditor tools with agent interaction

## Pre-Test Setup

### Prerequisites
- [ ] Server running: `mix phx.server`
- [ ] Navigate to: `http://localhost:4000/wireframe-test`
- [ ] Browser DevTools open (Console tab visible)
- [ ] No errors in server logs

### Initial State
1. Load **complex** wireframe sample
2. Verify JavaScript works:
   - [ ] Click "New Project" button → Modal opens
   - [ ] Click "Refresh Data" → Button text changes to "Refreshing..."
   - [ ] Click sidebar menu items → Active state changes
   - [ ] No errors in console
3. Click "Start Agent"
4. Verify agent interface:
   - [ ] Chat panel appears on left
   - [ ] Preview stays full height on right
   - [ ] "Stop Agent" button visible in preview header
   - [ ] Agent sees wireframe context (initial message should show understanding)

---

## Tool Test Cases

### Test 1: modify_classes (BASELINE - Should work from Sprint 5)

**Objective:** Verify basic class modification works

**Test 1.1: Add Tailwind Classes**
```
Prompt: "Add the classes 'ring-4 ring-red-500' to the button with id 'refresh-btn'"
```

**Expected Results:**
- [ ] Preview updates immediately (no page reload)
- [ ] Red ring appears around "Refresh Data" button
- [ ] Agent confirms action
- [ ] No errors in console
- [ ] No errors in server logs

**Verify in Agent Context:**
1. Click "Agent Context" button (top right of preview)
2. Look for: `- refresh-btn: <button> .button .ring-4 .ring-red-500`
3. Close agent context

**Test 1.2: Remove Classes**
```
Prompt: "Remove the classes 'ring-4 ring-red-500' from the refresh button"
```

**Expected Results:**
- [ ] Red ring disappears
- [ ] Button returns to original appearance
- [ ] Agent confirms removal

**Issues Found:**
- [ ] None (baseline test)
- [ ] Issue: _________________________________

---

### Test 2: manage_attributes

**Objective:** Verify HTML attribute manipulation (NOT classes)

**Test 2.1: Add Data Attribute**
```
Prompt: "Add a 'data-test-id' attribute with value 'refresh-button-verified' to the element with id 'refresh-btn'"
```

**Expected Results:**
- [ ] Agent confirms action
- [ ] No visual change (data attributes are invisible)

**Verify in Browser:**
1. Right-click "Refresh Data" button → Inspect
2. Check for: `data-test-id="refresh-button-verified"`

**Verify in Agent Context:**
1. Open agent context
2. Look for attribute in button description

**Test 2.2: Add Disabled Attribute**
```
Prompt: "Add a 'disabled' attribute with value true to the button with id 'refresh-btn'"
```

**Expected Results:**
- [ ] "Refresh Data" button becomes disabled (grayed out)
- [ ] Button no longer clickable
- [ ] Agent confirms action
- [ ] Inspect element shows: `<button disabled>` (NOT `disabled="disabled"`)

**Note:** Only form elements (button, input, select, textarea) can be disabled.
The sidebar items are `<li>` elements and cannot be disabled.

**Test 2.3: Remove Attribute**
```
Prompt: "Remove the 'disabled' attribute from the refresh-btn"
```

**Expected Results:**
- [ ] Button becomes enabled again
- [ ] Returns to normal appearance
- [ ] Button is clickable

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 3: manage_variables

**Objective:** Verify JavaScript variable modification

**Test 3.1: Modify Numeric Variable**
```
Prompt: "Change the value of the variable 'projectCount' to 999"
```

**Expected Results:**
- [ ] Agent confirms variable change
- [ ] No console errors
- [ ] Console logs show: `[JavaScriptUpdater] Set window.projectCount = 999`

**Verify in Console:**
1. Type: `window.projectCount`
2. Should return: `999` ✅

**What DOESN'T Happen (By Design):**
- ❌ The "24" text on screen does NOT automatically change to "999"
- **Why:** Changing a variable doesn't automatically update DOM text
- **This is expected:** Variables aren't reactive. The wireframe would need code that reads the variable and updates the DOM.
- **To see it update:** You'd need to trigger the code that updates the display (like clicking a button that calls the update function)

**Test 3.2: Modify String Variable**
```
Prompt: "Change the 'currentView' variable to 'testing'"
```

**Expected Results:**
- [ ] Agent confirms change

**Verify in Console:**
1. Type: `window.currentView`
2. Should return: `"testing"`

**Test 3.3: Add New Variable**
```
Prompt: "Add a new variable called 'testMode' with value true"
```

**Expected Results:**
- [ ] Agent confirms addition

**Verify in Console:**
1. Type: `window.testMode`
2. Should return: `true`

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 4: manage_functions

**Objective:** Verify JavaScript function definition

**Test 4.1: Add Simple Function**
```
Prompt: "Add a new function called 'testFunc' that logs 'Hello from agent!' to the console"
```

**Expected Results:**
- [ ] Agent confirms function added
- [ ] No console errors

**Verify in Console:**
1. Type: `window.testFunc()`
2. Should see: `Hello from agent!` in console

**Test 4.2: Add Function with Parameters**
```
Prompt: "Add a function called 'greet' that takes a name parameter and logs 'Hello, ' plus the name"
```

**Expected Results:**
- [ ] Agent confirms addition

**Verify in Console:**
1. Type: `window.greet('Tester')`
2. Should see: `Hello, Tester`

**Test 4.3: Modify Existing Function**
```
Prompt: "Change the 'refreshData' function to also log 'Refresh triggered by agent' to the console"
```

**Expected Results:**
- [ ] Agent confirms modification
- [ ] Click "Refresh Data" button
- [ ] Should see "Refresh triggered by agent" in console
- [ ] Button should still show "Refreshing..." animation

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 5: manage_handlers

**Objective:** Verify event handler attachment

**Test 5.1: Add Click Handler**
```
Prompt: "Add a click event handler to the element with id 'total-projects' that logs 'Stats clicked!' to the console"
```

**Expected Results:**
- [ ] Agent confirms handler added
- [ ] Click the "24" (Total Projects stat)
- [ ] Should see "Stats clicked!" in console
- [ ] Original functionality still works

**Test 5.2: Add Handler that Calls Function**
```
Prompt: "Add a click handler to the element with id 'active-tasks' that calls the testFunc function"
```

**Expected Results:**
- [ ] Agent confirms handler added
- [ ] Click the "156" (Active Tasks stat)
- [ ] Should see "Hello from agent!" in console

**Test 5.3: Replace Handler**
```
Prompt: "Replace the click handler on refresh-btn to log 'Custom refresh' instead of doing the original refresh"
```

**Expected Results:**
- [ ] Agent confirms replacement
- [ ] Click "Refresh Data" button
- [ ] Should see "Custom refresh" in console
- [ ] Button should NOT show "Refreshing..." animation (original handler replaced)

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 6: manage_css

**Objective:** Verify custom CSS rule injection

**Test 6.1: Add CSS Rule for Class**
```
Prompt: "Add a CSS rule for the class 'stat-value' that makes the font-weight 900"
```

**Expected Results:**
- [ ] All big numbers (24, 156, 8, 87%) become extra bold
- [ ] Change is visible immediately
- [ ] Agent confirms CSS added

**Verify in Agent Context:**
1. Open agent context
2. Look for CSS rule in "Available CSS Rules" section

**Test 6.2: Add Hover Effect**
```
Prompt: "Add a CSS rule for '.stat-card:hover' that adds a shadow: box-shadow: 0 8px 16px rgba(0,0,0,0.2)"
```

**Expected Results:**
- [ ] Agent confirms CSS added
- [ ] Hover over any stat card
- [ ] Should see shadow appear on hover

**Test 6.3: Add Complex Rule**
```
Prompt: "Add a CSS rule for '.button' that makes the background color '#ff6600' and text color white"
```

**Expected Results:**
- [ ] All buttons change to orange background with white text
- [ ] Existing hover states may be affected

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 7: manage_init_scripts

**Objective:** Verify initialization script execution

**Test 7.1: Add Console Log**
```
Prompt: "Add an initialization script that logs 'Wireframe initialized by agent!' when the page loads"
```

**Expected Results:**
- [ ] Agent confirms script added
- [ ] Look in console - may not see message yet (script runs on DOMContentLoaded)

**Verify in Agent Context:**
1. Open agent context
2. Look for init script in "Available Init Scripts" section

**Note:** Init scripts only run on page load, so to test:
- Stop agent, reload page, start agent again
- OR check that script is in agent context for next load

**Test 7.2: Add DOM Manipulation**
```
Prompt: "Add an init script that changes the page title to 'Agent Modified Dashboard'"
```

**Expected Results:**
- [ ] Agent confirms addition
- [ ] Script won't run until page reload
- [ ] Check agent context shows the script

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 8: modify_elements (Add)

**Objective:** Verify element addition

**Test 8.1: Add Simple Element**
```
Prompt: "Add a new paragraph element with id 'agent-message' and text 'Added by agent!' after the 'Total Projects' stat card"
```

**Expected Results:**
- [ ] New paragraph appears below first stat card
- [ ] Text reads "Added by agent!"
- [ ] Element has id 'agent-message'

**Verify in Browser:**
1. Inspect element to confirm structure

**Test 8.2: Add Element with Classes**
```
Prompt: "Add a button with id 'test-button', text 'Test Button', and classes 'button secondary' after the refresh button"
```

**Expected Results:**
- [ ] New button appears after "Refresh Data"
- [ ] Button styled like other secondary buttons
- [ ] Has id 'test-button'

**Test 8.3: Add Nested Elements**
```
Prompt: "Add a div with id 'agent-panel' containing a heading 'Agent Panel' and a paragraph 'This was added dynamically' at the bottom of the main content area"
```

**Expected Results:**
- [ ] New panel appears at bottom
- [ ] Contains both heading and paragraph
- [ ] Proper parent-child structure

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 9: modify_elements (Remove)

**Objective:** Verify element removal

**Test 9.1: Remove Added Element**
```
Prompt: "Remove the element with id 'test-button'"
```

**Expected Results:**
- [ ] Test button disappears immediately
- [ ] No console errors
- [ ] Other elements unaffected

**Test 9.2: Remove Original Element**
```
Prompt: "Remove the stat card showing 'Completion Rate'"
```

**Expected Results:**
- [ ] Fourth stat card (87%) disappears
- [ ] Layout adjusts (grid should have 3 cards now)
- [ ] No console errors

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 10: modify_elements (Replace)

**Objective:** Verify element replacement

**Test 10.1: Replace Element**
```
Prompt: "Replace the element with id 'agent-message' with a button that says 'Replaced!' with id 'replaced-element'"
```

**Expected Results:**
- [ ] Paragraph disappears
- [ ] Button appears in same location
- [ ] New element has id 'replaced-element'

**Test 10.2: Replace with Complex Element**
```
Prompt: "Replace the 'Team Members' stat card with a div containing the text 'This stat was replaced by the agent'"
```

**Expected Results:**
- [ ] Stat card disappears
- [ ] New div appears in its place
- [ ] Text is visible

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

### Test 11: trigger_interaction (Ephemeral)

**Objective:** Verify testing-only tool for triggering interactions

**Note:** This tool is for testing only and doesn't persist changes

**Test 11.1: Trigger Click**
```
Prompt: "Use trigger_interaction to click the 'New Project' button"
```

**Expected Results:**
- [ ] Modal opens (as if user clicked)
- [ ] Agent sees any effects
- [ ] No permanent changes to wireframe

**Test 11.2: Trigger Event**
```
Prompt: "Trigger a click on the 'Refresh Data' button"
```

**Expected Results:**
- [ ] Button shows "Refreshing..." animation
- [ ] Console logs appear (if any handlers log)
- [ ] Agent can verify interaction happened

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

## Integration Tests

### Test 12: Multiple Tools in Sequence

**Test 12.1: Build Feature Step-by-Step**
```
Conversation:
1. "Add a new button with id 'feature-btn' and text 'New Feature' in the header"
2. "Add the classes 'bg-purple-600 text-white px-4 py-2 rounded' to feature-btn"
3. "Add a click handler to feature-btn that logs 'Feature clicked!'"
4. "Add a variable called 'featureClicks' with value 0"
5. "Change the click handler on feature-btn to increment featureClicks and log the count"
```

**Expected Results:**
- [ ] Each step completes successfully
- [ ] Final result: Styled button that counts clicks
- [ ] Clicking button increments counter and logs

### Test 12.2: Modify and Test Flow**
```
Conversation:
1. "Add a CSS rule for '.sidebar-menu li' that adds 'cursor: pointer'"
2. "Add a click handler to 'menu-projects' that logs 'Projects menu clicked'"
3. "Trigger a click on menu-projects to test it"
4. "Now remove the click handler from menu-projects"
```

**Expected Results:**
- [ ] Each modification works
- [ ] Agent can test changes with trigger_interaction
- [ ] Cleanup works (handler removed)

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

## Error Handling Tests

### Test 13: Invalid Operations

**Test 13.1: Target Non-Existent Element**
```
Prompt: "Add the class 'test' to the element with id 'nonexistent-element'"
```

**Expected Results:**
- [ ] Agent reports error (element not found)
- [ ] No console errors
- [ ] No preview changes

**Test 13.2: Invalid Syntax**
```
Prompt: "Add a function with invalid JavaScript syntax"
```

**Expected Results:**
- [ ] Agent may create the function
- [ ] JavaScript errors in console when function runs
- [ ] OR agent refuses to create invalid syntax

**Test 13.3: Replace Root Element**
```
Prompt: "Replace the root element of the wireframe"
```

**Expected Results:**
- [ ] Agent reports error (cannot replace root)
- [ ] No changes to wireframe

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

## Performance Tests

### Test 14: Batch Operations

**Test 14.1: Multiple Classes**
```
Prompt: "Add the class 'test-class' to all stat cards at once"
```

**Expected Results:**
- [ ] All 4 stat cards get the class
- [ ] Update happens in single operation
- [ ] Preview updates smoothly

**Test 14.2: Many Elements**
```
Prompt: "Add 10 new paragraph elements in the main content area, numbered 1 through 10"
```

**Expected Results:**
- [ ] All 10 paragraphs appear
- [ ] Preview updates once (not 10 times)
- [ ] No performance issues

**Issues Found:**
- [ ] None
- [ ] Issue: _________________________________

---

## Visual Regression Checklist

After all tests, verify:
- [ ] Original wireframe functionality still works (modals, forms, tabs)
- [ ] No memory leaks (check DevTools Memory)
- [ ] No orphaned event listeners
- [ ] Preview can be cleared and reloaded
- [ ] Stop/Start agent works reliably
- [ ] Agent context accurate reflects current state
- [ ] No errors in server logs
- [ ] No errors in browser console (except intentional test errors)

---

## Known Issues Log

**Document issues as you find them:**

### Issue #1
- **Test:** _______________________
- **Description:** _______________________
- **Reproduction:** _______________________
- **Severity:** Critical / High / Medium / Low
- **Status:** Open / Investigating / Fixed

### Issue #2
- **Test:** _______________________
- **Description:** _______________________
- **Reproduction:** _______________________
- **Severity:** Critical / High / Medium / Low
- **Status:** Open / Investigating / Fixed

---

## Test Summary

**Tests Completed:** 11 / 14 ✅
- Tests 1-10: ✅ Completed and validated
- Test 11 (trigger_interaction): ⏸️ DEFERRED - Needs client-side infrastructure
- Test 12 (Integration scenarios): ⏸️ DEFERRED - Better as separate sprint
- Test 13 (Validation): ✅ Completed

**Tools Validated:** 8 / 9 ✅
- ✅ modify_classes
- ✅ modify_elements
- ✅ manage_attributes
- ✅ manage_handlers
- ✅ manage_functions
- ✅ manage_variables
- ✅ manage_css
- ✅ manage_init_scripts
- ⏸️ trigger_interaction (deferred - needs infrastructure)

**Issues Found:** 6 critical bugs discovered and fixed
**Critical Issues:** All resolved ✅
**Test Duration:** 2 days (November 6-7, 2025)

**Overall Assessment:**
- [x] Ready for production (8 of 9 tools)
- [ ] Needs minor fixes
- [ ] Needs major fixes
- [ ] Not ready

**Critical Bugs Fixed During Testing:**
1. Observer boolean serialization (false → "false")
2. Nested children not being added to DOM
3. Replacement elements missing auto-generated IDs
4. Init scripts not running after page reload
5. Invalid JavaScript syntax accepted without validation
6. Tool argument parsing errors (BitString enumeration)

**Test Suite Results:**
- 937 of 939 tests passing (2 pre-existing failures unrelated to Sprint 6)
- All new code tested with comprehensive unit and integration tests
- No regressions introduced

**Notes:**
- CSS work already complete (manage_css functional in Sprint 5)
- JavaScript rendering fully working (variables, functions, handlers, init scripts)
- Dynamic updates via LiveView hooks working correctly
- Deferred items tracked in BACKLOG.md for future sprints
- Console and screenshot integrations still needed
- See `docs/sprints/sprint-6-summary.md` for complete details
