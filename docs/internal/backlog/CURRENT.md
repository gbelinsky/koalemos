# Current Focus

**Last Updated:** December 8, 2025

---

## Milestone 6: Polish & Production-Ready

**Goal:** Ship production-ready MVP!

**Why This Scope:**
- MVP complete from M5, now make it production-worthy
- UX polish for real users
- Deployment infrastructure
- Complete documentation

### Components

- [ ] **UI Polish** (~200 lines)
  - [ ] Landing page (start session, upload wireframe)
  - [ ] Loading states (LLM thinking, file upload)
  - [ ] Error handling (graceful failures, network errors)
  - [ ] Smooth transitions

- [ ] **Logging & Monitoring** (~100 lines)
  - [ ] Make debug logging configurable
  - [ ] Clean up excessive logs
  - [ ] Production-level logging
  - [ ] Error tracking setup

- [ ] **Docker & Deployment** (~200 lines)
  - [ ] Dockerfile (multi-stage build)
  - [ ] docker-compose.yml (easy local dev)
  - [ ] Environment configuration (.env.example)
  - [ ] Deploy to Fly.io

- [ ] **Documentation** (update existing docs)
  - [x] V4 Architecture documentation
  - [ ] README with quick start
  - [ ] CONTRIBUTING.md (branch workflow)
  - [ ] DEPLOYMENT.md (how to deploy)
  - [ ] Update ARCHITECTURE.md

### Test Criteria

- [ ] Landing page looks professional
- [ ] No rough edges in UX
- [ ] Can deploy in < 5 minutes
- [ ] Docker container works
- [ ] Deployed app works in production
- [ ] Documentation is clear and complete

**Lines:** ~500
**Status:** In Progress

---

## Recent Work (December 2025)

### V4 Architecture Complete

Fixed init script timing issues by replacing PubSub-based V3 architecture with direct Registry communication:
- StateServer as single source of truth
- Blocking operations (capture_state, execute_interaction)
- No adapters, simpler timing model

**Schema fix:** Updated V4 lens tool schemas to properly document handler format `{event: {params: [], body: "code"}}` - this was causing handlers not to fire in production.

---

## Active Bugs

See `docs/internal/BUGS.md` for tracked issues.

---

## Next Steps

1. UI polish for production use
2. Docker deployment setup
3. Final documentation pass
4. Release v0.6.0
