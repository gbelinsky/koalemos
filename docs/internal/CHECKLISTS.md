# Pre-Release Checklists

A single place for validation checklists. Check these before commits and releases.

---

## Pages to Validate

Manual smoke test each page before release:

| Page | Route | What to Check |
|------|-------|---------------|
| Home | `/` | Loads, start session works |
| Wireframe Editor V4 | `/wireframe-editor-v4/:id` | Preview loads, chat works |
| Wireframe Editor V4 Production | `/wireframe-editor-v4-production` | Config modal, session start |
| Wireframe Preview V4 | `/wireframe-preview-v4/:id` | Renders in iframe correctly |
| Test Index | `/test` | All test links work |
| Wireframe Test | `/test/wireframe` | Sample loading, preview |

---

## Feature Validation Checklist

Before calling any feature "done":

### Wireframe Editor (V4 Production)
- [ ] Start new session from config modal
- [ ] Load sample wireframe (Login Form, Dashboard, Blank)
- [ ] Send a message, get response
- [ ] Agent adds an element (button, div, etc.)
- [ ] Agent adds a click handler - **handler fires when clicked**
- [ ] Agent modifies CSS
- [ ] Agent adds init script - **script runs on load**
- [ ] Save page works (downloads HTML)
- [ ] Screenshot capture works
- [ ] State capture shows current DOM

### Chat Interface
- [ ] Enter key submits message
- [ ] Shift+Enter adds newline
- [ ] Loading state shows while LLM thinking
- [ ] Error messages are user-friendly
- [ ] Multi-turn conversation works

### Providers
- [ ] Anthropic works with API key
- [ ] Ollama works (if server running)
- [ ] OpenAI works with API key

---

## Before Commit Checklist

- [ ] `mix test` passes (1000+ tests, 0 failures)
- [ ] Manual smoke test of changed features
- [ ] No debug logging left in code
- [ ] No hardcoded test values

---

## Before Release Checklist

- [ ] All "Pages to Validate" checked
- [ ] All "Feature Validation" items pass
- [ ] Docker build works: `docker build -t koalemos .`
- [ ] Docker run works: `docker run -p 4000:4000 -e SECRET_KEY_BASE=... koalemos`
- [ ] Fresh clone + setup works (README instructions)
- [ ] Credentials setup documented

---

## Known Working States

Reference points - if something breaks, compare to these:

| Commit | Date | What Works |
|--------|------|------------|
| `ca7008a` | Dec 8, 2025 | V4 with handler fix, 1003 tests pass |
| | | |

---

## Debugging Protocol

When something breaks:

1. **STOP** - Don't make speculative fixes
2. **Identify** - What exactly doesn't work? Be specific.
3. **Isolate** - Find minimal reproduction
4. **Compare** - Does it work in test page but not production? V3 vs V4?
5. **Trace** - Add temporary logging at each layer
6. **Fix** - Make minimal targeted change
7. **Verify** - Check fix in ALL contexts (test page AND production)
8. **Clean** - Remove debug logging before commit

---

## Current Focus

What we're working on RIGHT NOW (update this):

**Goal:** M6 Release - run-it-yourself demo

**Remaining:**
- [ ] docker-compose.yml
- [ ] Container publishing
- [ ] Usage guide
- [ ] Credentials setup guide
- [ ] Landing page polish
- [ ] Working example flow
- [ ] Error messages
- [ ] Loading states
- [ ] Final manual testing
