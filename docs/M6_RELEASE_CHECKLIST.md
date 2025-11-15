# M6 Pre-Release Checklist

**Target:** Run-it-yourself demo (not deployed production)
**Goal:** Anyone can clone, setup, and run Koalemos locally

---

## Critical Path (Must Have)

### Bug Fixes
- [x] **BUG-004: Sequential thinking flicker** - Most visible UX issue (FIXED: StatusBar component)
- [x] **BUG-003: Agent looping during testing** - Wastes time/tokens, bad demo experience (FIXED: Improved testing template)
- [x] **BUG-001: OAuth invalid_grant** - Simplified credential refresh (always reload from disk)

### Documentation
- [ ] **README Quick Start** - Clear setup instructions (deps, credentials, run)
- [ ] **Usage Guide** - How to use the wireframe editor demo
- [ ] **Credentials Setup** - How to add API keys to `.koalemos/.credentials.json`

### Demo Experience
- [ ] **Landing Page** - Clear, polished first impression with quick start options
- [ ] **Working Example** - One demo flow that always works (e.g., "build a login form")
- [ ] **Error Messages** - User-friendly errors (not stack traces)
- [ ] **Loading States** - Show when LLM is thinking

### Routine Improvements
- [x] **Debug subroutine** - Add debug subroutine to WireframeDesignRoutine (DONE: Systematic debugging with full tool access)
- [x] **Play subroutine** - Add play subroutine to WireframeDesignRoutine (DONE: Tight interaction loop via PlayRoutine)
- [x] **Replace answer_directly** - Remove routing overhead, just answer directly with instructions (DONE: Removed step, added routing prompt comment)
- [x] **Simplify BuildWireframeRoutine** - Remove complete step, parent's show_result handles explanation (DONE)

### UI/UX Polish
- [x] **Rework StatusBar component** - Refine design and behavior based on feedback (DONE: Fixed sizing, execution chain, identity detection)
- [x] **Thinking card markdown** - Render thought content as markdown (not plain text) (DONE: Reused MarkdownHelper with prose classes)
- [x] **Variable rendering** - Show both initial and current values in wireframe lens context (DONE: JavaScript captures, cache stores, agent sees current values)
- [x] **Save page feature** - Allow users to save/export the wireframe HTML (DONE: Blob download, works via localhost/HTTPS)
- [x] **Return key submit** - Make return key work on user input component (DONE: Enter submits, Shift+Enter newline)

### Docker Container (Production-Ready)
- [ ] **Dockerfile** - Multi-stage build for production
- [ ] **docker-compose.yml** - Easy local development setup
- [ ] **Container Publishing** - Publish to Docker Hub/GHCR for one-command quick start
- [ ] **Credentials Handling** - Document how to pass API keys to container (env vars or volume mount)
- [ ] **Build & Test** - Verify container builds and runs successfully

### Quality
- [ ] **All Tests Passing** - No failures, 1,000+ tests
- [ ] **Manual Testing** - Full workflow tested end-to-end (both local and containerized)
- [ ] **No Obvious Bugs** - Clean first impression

---

## Nice to Have (If Time)

### Polish
- [ ] Smooth UI transitions
- [ ] Better error handling (retry, graceful failures)

### Developer Experience
- [ ] CONTRIBUTING.md (how to add routines/lenses)
- [ ] Code examples in docs
- [ ] Architecture diagrams updated

### Optional Infrastructure
- [ ] Logging configuration (reduce noise)

---

## Explicitly Out of Scope

**Not needed for run-it-yourself demo:**
- ❌ Deployment to Fly.io/cloud
- ❌ Production logging infrastructure
- ❌ Error tracking (Sentry/AppSignal)
- ❌ SSL/Domain setup
- ❌ Production secrets management
- ❌ CI/CD pipeline
- ❌ Performance optimization
- ❌ Load testing
- ❌ Security hardening beyond basics

---

## Post-Demo Work (Future Improvements)

**Technical debt and improvements to address after demo:**
- **Robust user step detection** - Currently hardcoded to check if `step_module == Koalemos.Steps.User.ChatUserInput`. Should detect by checking `waiting_for` state and event types (e.g., `:user_input`) instead of hardcoding step modules.
- **StatusBar polish** - Review StatusBar behavior with multiple routine types and edge cases
- **Integrate Persona lens** - Add persona/agent configuration system to routines for customizable agent behavior and tone

---

## Progress Tracking

**M6 Started:** 2025-11-14
**Current Status:** In Progress
**Completed:** 12/21 critical items

### Sprint 1: Bug Fixes & Core Docs
- [x] Fix flicker (BUG-004)
- [x] Fix looping (BUG-003)
- [ ] README Quick Start
- [ ] Credentials setup guide

### Sprint 2: Demo Polish
- [ ] Working example flow
- [ ] Error messages
- [ ] Loading states
- [ ] Manual testing

### Sprint 3: Final Polish (if needed)
- [ ] Nice-to-have items
- [ ] Final QA
- [ ] Release!

---

## Definition of Done

**Ready to release when:**

### Quick Start Path (Docker - Primary)
1. ✅ Run `docker run -e ANTHROPIC_API_KEY=xxx koalemos/koalemos:latest`
2. ✅ Open browser to localhost:4000
3. ✅ Build a wireframe successfully

### Developer Path (Clone & Build)
1. ✅ Clone repo
2. ✅ Run `mix deps.get`
3. ✅ Add API key to `.koalemos/.credentials.json`
4. ✅ Run `mix phx.server`
5. ✅ Build a wireframe successfully

### Both Paths
6. ✅ No confusing errors or bugs
7. ✅ Clear next steps if something goes wrong
8. ✅ Landing page clearly explains quick start options

**That's it - we ship when this works smoothly!** 🚀

---

## Notes

- This is M6 (final milestone before release)
- Focus on local development experience
- Don't over-engineer - production comes later
- Goal: Impressive demo that "just works"
- Keep it simple, keep it working
