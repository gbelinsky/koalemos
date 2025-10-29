# M2 Sprint 1: Foundation

**Branch:** `feature/m2-1-foundation`
**Status:** Planning → Ready to Execute
**Goal:** Get basic Phoenix/LiveView infrastructure working

---

## Sprint Goal

Establish the foundation for all M2 components:
- Phoenix layouts render correctly
- Core components available
- Markdown rendering works
- Minimal JavaScript (LiveView + auto-scroll)
- Clean, simple base to build on

**No user-facing features yet** - just infrastructure.

---

## Components to Build (~400 lines)

### 1. Layouts (~130 lines)

**root.html.heex** (~50 lines)
- HTML shell (<!DOCTYPE>, <html>, <head>, <body>)
- Meta tags
- CSS/JS asset links
- Flash message container
- LiveView connection scripts

**app.html.heex** (~80 lines)
- Navigation (if any for M2)
- Flash message display
- Main content area
- Footer (if any)

**Decision:** Minimal for M2, can enhance in M6 (polish)

---

### 2. Core Components (~500 lines)

**core_components.ex**
- Phoenix defaults (button, input, label, error, header, etc.)
- Check Koalemos current version vs Flo version
- Update if Flo has improvements
- Ensure Tailwind classes work

**Already exists in Koalemos, may just need review**

---

### 3. Markdown Helper (~50 lines)

**MarkdownHelper** (new or port)
- Convert markdown → HTML
- Used by MessageCards.AssistantCard
- Check if Flo has one, or use Earmark directly

**Options:**
1. Port FloWeb.MarkdownHelper if exists
2. Create simple wrapper around Earmark
3. Use Earmark directly in components

**Decision needed:** Check Flo implementation

---

### 4. Minimal app.js (~100 lines)

**Extract from Flo app.js (2,197 lines total):**

**Include:**
- LiveView initialization (~30 lines)
- LiveSocket setup (~20 lines)
- Topbar (loading indicator) (~10 lines)
- ScrollToBottom hook (~40 lines) - For chat auto-scroll

**Exclude (defer to M3/M4+):**
- WireframeScriptHook (~1,770 lines) - Screenshot/preview specific
- WorkflowGraphHook (~100 lines) - Workflow builder specific
- WorkflowBuilderGraphHook (~100 lines) - Workflow builder specific
- Alpine.js (~50 lines) - Workflow builder specific
- DomAgentHook (~100 lines) - DOM agent specific

**Result:** ~100 lines of focused JavaScript

---

## Files to Review

**Before porting, we need to review:**

### Layouts

**Flo root.html.heex:**
```
Location: /home/gabe/projects/flo/lib/flo_web/components/layouts/root.html.heex
Size: ~100 lines (estimated)
Questions:
- What meta tags do we need?
- Any Flo-specific scripts to remove?
- Keep or simplify?
```

**Flo app.html.heex:**
```
Location: /home/gabe/projects/flo/lib/flo_web/components/layouts/app.html.heex
Size: ~150 lines (estimated)
Questions:
- Does it have navigation we need?
- Flash message handling approach?
- Any workflow-specific elements to remove?
```

**Koalemos current layouts:**
```
Location: lib/koalemos_web/components/layouts/
Files: root.html.heex, app.html.heex (Phoenix defaults)
Questions:
- Are current layouts sufficient?
- What improvements does Flo have?
- Merge or replace?
```

---

### JavaScript

**Flo app.js:**
```
Location: /home/gabe/projects/flo/assets/js/app.js
Size: 2,197 lines
Task: Extract minimal version
Questions:
- Verify ScrollToBottom hook works standalone
- Any other generic hooks needed?
- Remove workflow/wireframe specific code
```

**Koalemos current app.js:**
```
Location: assets/js/app.js
Size: ~50 lines (Phoenix default)
Questions:
- Replace or enhance?
- Merge Flo's improvements?
```

---

### Components

**Flo core_components.ex:**
```
Location: /home/gabe/projects/flo/lib/flo_web/components/core_components.ex
Size: 21,475 bytes
Questions:
- Any improvements over Phoenix defaults?
- Custom components to port?
- Tailwind classes compatible?
```

**Koalemos current core_components.ex:**
```
Location: lib/koalemos_web/components/core_components.ex
Size: ~20KB (Phoenix defaults)
Questions:
- What's different from Flo version?
- Worth updating?
```

---

### Markdown

**Check if Flo has MarkdownHelper:**
```
Location: /home/gabe/projects/flo/lib/flo_web/... (search needed)
If not found: Create simple wrapper around Earmark
```

---

## Port vs Build Matrix

| Component           | Decision | Lines | Source                        | Notes                                    |
|---------------------|----------|-------|-------------------------------|------------------------------------------|
| root.html.heex      | Review   | 50    | Flo → Koalemos (merge)        | Simplify, remove Flo-specific            |
| app.html.heex       | Review   | 80    | Flo → Koalemos (merge)        | Keep flash, remove nav if workflow-specific |
| core_components.ex  | Review   | 500   | Already in Koalemos           | Check for Flo improvements               |
| MarkdownHelper      | Check    | 50    | Find in Flo or create         | Wrapper around Earmark                   |
| app.js              | Extract  | 100   | Flo → Koalemos (minimal)      | LiveView + ScrollToBottom only           |

---

## Implementation Steps

### 1. Review Phase (with user)
- [ ] Review Flo root.html.heex - what to keep/skip?
- [ ] Review Flo app.html.heex - what to keep/skip?
- [ ] Review Flo app.js - confirm hook extraction plan
- [ ] Check if Flo has MarkdownHelper
- [ ] Decide: merge or replace Koalemos layouts?

### 2. Layout Updates
- [ ] Update/create root.html.heex
- [ ] Update/create app.html.heex
- [ ] Test: Layouts render without errors

### 3. JavaScript
- [ ] Extract minimal app.js from Flo
  - [ ] LiveView initialization
  - [ ] ScrollToBottom hook
  - [ ] Topbar (optional)
- [ ] Replace Koalemos app.js with minimal version
- [ ] Test: LiveView connects, no console errors

### 4. Markdown Support
- [ ] Find or create MarkdownHelper
- [ ] Add Earmark dependency if needed (mix.exs)
- [ ] Test: Markdown renders to HTML
- [ ] Test helper function: `MarkdownHelper.to_html("**bold**")`

### 5. Core Components (if needed)
- [ ] Review Flo core_components.ex
- [ ] Update Koalemos version if improvements found
- [ ] Test: Components render correctly

### 6. Testing
- [ ] Phoenix server starts (`mix phx.server`)
- [ ] Navigate to any page (even if 404)
- [ ] Layouts render
- [ ] No JavaScript errors
- [ ] Flash messages work
- [ ] Markdown helper works (in IEx)

### 7. Documentation
- [ ] Update M2-Sprint-1.md with decisions made
- [ ] Note any deviations from plan
- [ ] Document any issues encountered

### 8. Commit
```bash
git add .
git commit -m "M2 Sprint 1: Foundation - layouts, core components, minimal app.js

- Updated root and app layouts (minimal for M2)
- Extracted minimal app.js (LiveView + ScrollToBottom hook)
- Added/updated MarkdownHelper for message rendering
- Verified core components work
- Tests: Phoenix starts, layouts render, no errors"
```

---

## Decisions Log

### Layout Decisions
**Decision:** [TBD - review with user]
**Rationale:** [TBD]

**Options:**
1. Port Flo layouts as-is (keep everything)
2. Merge best of both (Flo improvements + Koalemos simplicity)
3. Minimal new layouts (just what M2 needs)

**Recommendation:** Option 2 - merge best of both

---

### app.js Decisions
**Decision:** [TBD - confirm with user]
**Rationale:** [TBD]

**Plan:**
- Include: LiveView, ScrollToBottom
- Exclude: WireframeScriptHook, WorkflowGraph, Alpine.js
- Result: ~100 lines

**Confirmed?** [Pending]

---

### Markdown Decisions
**Decision:** [TBD - after checking Flo]
**Rationale:** [TBD]

**Options:**
1. Port FloWeb.MarkdownHelper if exists
2. Create simple wrapper: `MarkdownHelper.to_html/1`
3. Use Earmark directly in components

**Recommendation:** Option 1 or 2 (helper function)

---

### Tailwind/Styling Decisions
**Decision:** [TBD]
**Rationale:** [TBD]

**Questions:**
- Keep Flo's Tailwind config?
- Any custom classes to port?
- Color scheme changes?

---

## Testing Checklist

### Basic Functionality
- [ ] `mix phx.server` starts without errors
- [ ] No compilation errors
- [ ] No dependency errors

### Layouts
- [ ] root.html.heex renders
- [ ] app.html.heex renders
- [ ] Flash messages display
- [ ] Page title shows

### JavaScript
- [ ] LiveView connects (green dot in corner if using dev tools)
- [ ] No console errors
- [ ] ScrollToBottom hook loaded (check in browser console)

### Components
- [ ] Core components render
- [ ] Buttons work
- [ ] Inputs work
- [ ] Form helpers work

### Markdown
- [ ] MarkdownHelper module exists
- [ ] Can render markdown to HTML
- [ ] Bold/italic/links work
- [ ] Code blocks work (optional for M2)

### Dependencies
- [ ] All mix deps installed
- [ ] Earmark added if needed
- [ ] No version conflicts

---

## Questions / Blockers

### Before Starting
1. **Layouts:** What specific elements from Flo layouts do we want?
2. **Navigation:** Do we need a nav bar in M2, or defer to M5/M6?
3. **Tailwind:** Any changes to color scheme or config?
4. **MarkdownHelper:** Does Flo have one we can port?

### During Implementation
[Document issues as they arise]

---

## Risks / Concerns

**Low Risk:**
- Layouts are straightforward
- Core components already exist
- Markdown is simple

**Medium Risk:**
- app.js extraction might miss dependencies
- ScrollToBottom hook might need other hooks
- Tailwind classes might not match

**Mitigation:**
- Review Flo app.js carefully
- Test ScrollToBottom hook in isolation
- Keep Flo Tailwind config initially

---

## Success Criteria

**Sprint 1 is complete when:**
1. ✅ Phoenix server starts without errors
2. ✅ Layouts render correctly
3. ✅ JavaScript loads without errors
4. ✅ LiveView connects and works
5. ✅ Markdown helper works
6. ✅ Core components available
7. ✅ Clean foundation for Sprint 2
8. ✅ Committed to feature branch

**Ready for Sprint 2:** Message cards can be built on this foundation

---

## Next Sprint Preview

**Sprint 2: Message Cards**
- Build UserCard, AssistantCard, ErrorCard, ImageGallery
- Depends on: Markdown rendering (from Sprint 1)
- Will use: Layouts, core components, CSS classes

**Blockers if Sprint 1 incomplete:**
- Can't render markdown in assistant messages
- Missing layout to display cards
- No styling foundation

---

## Notes

[Add notes during implementation]

**Helpful Commands:**
```bash
# Create feature branch
git checkout -b feature/m2-1-foundation develop

# Start Phoenix server
mix phx.server

# Run tests
mix test

# Check for JavaScript errors
# Open browser console at http://localhost:4000
```

**Files to Review Together:**
1. /home/gabe/projects/flo/lib/flo_web/components/layouts/root.html.heex
2. /home/gabe/projects/flo/lib/flo_web/components/layouts/app.html.heex
3. /home/gabe/projects/flo/assets/js/app.js (lines 1-200 especially)
4. Check for: lib/flo_web/helpers/markdown_helper.ex or similar

**Ready to start review!**
