# Known Bugs

This document tracks known bugs in Koalemos. Each bug should have:
- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Linked test case (when fixed)
- Status

---

---

## BUG-002: Empty Text Blocks in Image-Only User Input

**Status:** 🔴 Open
**Priority:** Medium
**Discovered:** 2025-10-29
**Component:** User input formatting (likely `lib/koalemos/steps/user_input/*.ex`)

### Description
When user submits only images (no text), the message formatting adds an empty text content block. Anthropic API rejects this with "text content blocks must be non-empty" error.

### Steps to Reproduce
1. Start chat routine
2. Submit message with only images, no text
3. API returns error: `API error 400: messages: text content blocks must be non-empty`

### Expected Behavior
- User can submit image-only messages
- No empty text blocks in formatted message
- API accepts the message

### Actual Behavior
- Empty text block added: `%{type: "text", text: ""}`
- API rejects the message
- User cannot send image-only messages

### Proposed Fix
Filter out empty text blocks in message formatting:

```elixir
# In ChatUserInput or message builder
content_blocks = [
  %{type: "text", text: user_text},
  ...images
]
|> Enum.reject(fn block ->
  block[:type] == "text" && (block[:text] == "" || block[:text] == nil)
end)
```

### Test Coverage
- [ ] Test image-only user input (no text)
- [ ] Test that empty text blocks are filtered
- [ ] Test mixed text + images still works

### Related Issues
- Blocks image-only user input functionality

---

---

## Bug Report Template

When adding new bugs, use this template:

```markdown
## BUG-XXX: [Short Description]

**Status:** 🔴 Open / 🟡 In Progress / 🟢 Fixed
**Priority:** High / Medium / Low
**Discovered:** YYYY-MM-DD
**Component:** `path/to/file.ex`

### Description
[Clear description of the bug]

### Steps to Reproduce
1. Step one
2. Step two
3. Step three

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Proposed Fix
[How to fix it]

### Test Coverage
- [ ] Test case 1
- [ ] Test case 2

### Related Issues
- Links to related bugs or features
```

---

## Fixed Bugs

### BUG-001: OAuth "invalid_grant" from Stale Cache ✅ FIXED

**Status:** 🟢 Fixed (2025-11-14)
**Priority:** High (Causes complete auth failure after long runtime)
**Discovered:** 2025-10-29
**Fixed:** 2025-11-14 (M6 Phase 1)
**Component:** `lib/koalemos/simple_credential_manager.ex`

### Description
After running for a long time (two OAuth refresh cycles), the second refresh would fail with "invalid_grant" error. The credentials file on disk had the correct (new) refresh token, but the in-memory cache had a stale (old) refresh token. This caused the refresh attempt to use an already-consumed token, which the OAuth API rejected.

### Root Cause
**Cache/disk synchronization issue:**

The GenServer cached credentials in state, but after the first refresh, something was preventing the cache from being updated with the new refresh token. On the next refresh attempt:
1. Cache still has old (consumed) refresh token
2. Disk has new (valid) refresh token
3. Refresh uses cached token → "invalid_grant" error
4. System stuck until server restart reloads from disk

**Evidence from logs:**
```
[debug] Starting refresh with cached refresh_token: sk-ant-ort01-ri_...  (OLD)
[debug] Disk file has refresh_token: sk-ant-ort01-skm...  (NEW)
[error] Failed to refresh token: invalid_grant
[error] Attempted with refresh_token: sk-ant-ort01-ri_...  (OLD cached token)
```

### Solution Implemented
**Always reload credentials from disk before refreshing:**

Since refresh token updates are infrequent and caching provides minimal benefit, the simplest solution is to always use the latest refresh token from disk:

1. **Before refresh** - Reload credentials from disk
2. **Use disk token** - Refresh with the token from disk (guaranteed fresh)
3. **Save new tokens** - Write new tokens back to disk
4. **Update cache** - Update in-memory cache with new tokens

This eliminates any cache/disk sync issues since we always read from the source of truth (disk) before refreshing.

**Implementation:**
```elixir
def handle_info(:do_refresh, state) do
  # Always reload from disk before refreshing
  credentials_to_use =
    if state.file_path do
      case load_oauth_file(state.file_path) do
        {:ok, disk_creds} -> disk_creds
        {:error, _} -> state.credentials  # Fallback to cache
      end
    else
      state.credentials
    end

  case refresh_token(credentials_to_use) do
    {:ok, new_credentials} ->
      save_credentials_to_file(new_credentials, state.file_path)
      # Update cache with new credentials
    {:error, reason} ->
      # Handle error
  end
end
```

**Files Changed:**
- Modified: `lib/koalemos/simple_credential_manager.ex` (simplified refresh logic)

### Benefits
- ✅ Simple, straightforward solution
- ✅ Always uses latest refresh token from disk
- ✅ Eliminates cache/disk sync issues
- ✅ No complex recovery logic needed
- ✅ Easy to understand and maintain

### Test Coverage
- [x] Compiles without errors
- [ ] Manual test: Run for multiple refresh cycles (pending)
- [ ] Manual test: Verify no invalid_grant errors (pending)

---

### BUG-003: Agent Looping During Testing Phase ✅ FIXED

**Status:** 🟢 Fixed (2025-11-14)
**Priority:** Medium
**Discovered:** 2025-11-14 (M5 Sprint 2)
**Fixed:** 2025-11-14 (M6 Phase 1)
**Component:** `lib/koalemos/routines/build_wireframe_routine.ex` (testing stage)

### Description
Agent entered a loop when testing wireframe interactions, particularly with forms. The agent repeatedly tried to fill out and submit forms without making progress toward completion, wasting time and tokens.

### Root Cause
- Testing stage template was too open-ended: "test all interactive elements"
- No explicit completion criteria or stopping condition
- No limit on attempts per element
- Agent interpreted instructions as "exhaustively test everything"
- With forms, agent would retry submissions multiple times thinking more testing was needed

### Solution Implemented
**Improved testing stage template with clear boundaries and completion criteria:**

**Key Changes:**
1. **Test each element ONCE** - Explicit instruction to verify each element once only
2. **One verification is sufficient** - No need for exhaustive testing
3. **Don't retry** - Explicit: "Don't retry or re-test elements that already responded correctly"
4. **Specific form testing** - "fill in ONE field and submit ONCE" (not multiple attempts)
5. **Clear completion criteria** - "Each interactive element tested once → Done"
6. **Move on immediately** - Explicit instruction to proceed to polish stage after verification

**Template improvements:**
```elixir
TESTING APPROACH - Keep it focused and efficient:
- Test each interactive element ONCE to verify it works
- One successful verification per element is sufficient
- Don't retry or re-test elements that already responded correctly
- Move on immediately after basic verification

COMPLETION CRITERIA:
- Each interactive element tested once → Done
- Basic functionality verified → Move to polish stage
- Don't aim for exhaustive testing - one verification per element is enough
```

**Files Changed:**
- Modified: `lib/koalemos/routines/build_wireframe_routine.ex` (testing stage template)

### Benefits
- ✅ Prevents infinite testing loops
- ✅ Saves time and tokens during testing phase
- ✅ Clear expectations for agent behavior
- ✅ Focused, efficient testing approach
- ✅ Simple solution (no complex loop detection needed)

### Test Coverage
- [x] Compiles without errors
- [ ] Manual test: Build form-based wireframe (pending)
- [ ] Manual test: Verify testing phase completes quickly (pending)
- [ ] Manual test: Verify agent doesn't retry form submissions (pending)

---

### BUG-004: Sequential Thinking Flicker in Conversation Panel ✅ FIXED

**Status:** 🟢 Fixed (2025-11-14)
**Priority:** Low (UX issue, not functional)
**Discovered:** 2025-11-14 (M5 Sprint 2)
**Fixed:** 2025-11-14 (M6 Phase 1)
**Component:** `lib/koalemos_web/components/status_bar.ex` (new component)

### Description
Sequential thinking messages caused visible flicker as the conversation panel rapidly shrank/expanded when the "...thinking" indicator appeared and disappeared during tool execution loops.

### Root Cause
- The "...thinking" indicator only showed when `current_step == :llm_request`
- Between LLM calls during sequential thinking, the step briefly changed to `parse_response` → `tool_execution` → `build_tool_schema`
- This caused the indicator to disappear and reappear rapidly
- Panel height changed, causing visible flicker and unnecessary scrolling

### Solution Implemented
Created a new **StatusBar component** that replaces the old "...thinking" indicator:

**Features:**
- Fixed position between conversation and input panels (no resize/flicker)
- Shows breadcrumb: "RoutineName → current_step"
- Shows identity icon: 👤 User | 🤖 Agent | ⚙️ System
- Auto-hides when idle
- Prominently highlights when waiting for user input
- More informative than generic "thinking..." message

**Files Changed:**
- Created: `lib/koalemos_web/components/status_bar.ex` (~150 lines)
- Modified: `lib/koalemos_web/components/chat_panel.ex` (added StatusBar integration)
- Modified: `lib/koalemos_web/components/message_feed.ex` (removed old "thinking" indicator)
- Modified: `lib/koalemos_web/live/wireframe_test_live.ex` (pass routine_module to ChatPanel)

### Benefits
- ✅ No more flicker (fixed position, no height changes)
- ✅ More informative (shows routine context, not just "thinking")
- ✅ Better UX (clear indication when user input needed)
- ✅ Future-proof (works with any routine, no hardcoded step lists)

### Test Coverage
- [x] Compiles without errors
- [ ] Manual test: Start routine with sequential thinking (pending)
- [ ] Manual test: Verify no flicker during thinking chain (pending)
- [ ] Manual test: Verify clear "User" indicator when waiting for input (pending)
