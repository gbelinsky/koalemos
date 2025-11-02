# Known Bugs

This document tracks known bugs in Koalemos. Each bug should have:
- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Linked test case (when fixed)
- Status

---

## BUG-001: OAuth "invalid_grant" from Race Condition

**Status:** 🟢 No Fix Needed (Existing Code Correct)
**Priority:** Low (Only with multiple processes)
**Discovered:** 2025-10-29
**Resolved:** 2025-10-29
**Component:** `lib/koalemos/simple_credential_manager.ex`

### Description
Experienced "invalid_grant" error when both Koalemos and Flo tried to refresh OAuth tokens simultaneously. This is a race condition where one process consumes the refresh_token before the other can use it.

### What Happened
1. Both Koalemos and Flo cached the same refresh_token
2. One process (Flo) refreshed successfully → got new tokens → wrote to file
3. Other process (Koalemos) tried with OLD refresh_token → "invalid_grant"
4. Server restart loaded fresh credentials → worked again

### Root Cause
**OAuth refresh_token race condition** between multiple processes.

When an OAuth refresh_token is used, it's consumed and replaced. If two processes try to use the same refresh_token, only the first succeeds.

### Investigation Status
**Added comprehensive debug logging to diagnose next occurrence.**

The existing code should work correctly:
1. Refreshes token when needed
2. Writes new tokens to file via `save_credentials_to_file`
3. Updates GenServer state with new credentials
4. Next refresh uses updated credentials from cache

However, to diagnose the actual failure, added debug logging that shows:
- What refresh_token from cache is being used
- What refresh_token is currently on disk
- Whether save succeeds
- What was actually written to disk
- Critical warnings if cache/disk get out of sync

### Recommendation
If running multiple processes:
- Use separate credential files for each process, OR
- Use direct API keys instead of OAuth, OR
- Accept occasional race conditions on refresh

### Test Coverage
- [x] All existing tests pass (15 tests)
- [x] Verified code writes refreshed tokens to file
- [x] Verified code updates cache after refresh

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

(Bugs will be moved here when fixed and tested)
