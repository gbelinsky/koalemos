# Koalemos - Production Deployment Example

**Last Updated:** November 11, 2025
**Status:** ⚠️ REFERENCE ONLY - Not Koalemos Goals

---

## ⚠️ Important Notice

**This document describes what a SaaS production deployment would require.**

**This is NOT the direction for Koalemos.** Koalemos is a **developer framework and demo** meant to be run locally or self-hosted, not a SaaS product.

**See the [Actual M5/M6 Goals](#actual-koalemos-goals-m5m6) section at the bottom for what we're actually building.**

---

## What This Document Is

This is an **example reference** of considerations for deploying an Elixir/Phoenix LiveView application as a production SaaS service. It covers:
- Multi-user authentication
- Session persistence
- Cloud deployment (Fly.io)
- Monitoring and observability
- Security hardening
- Cost analysis

Keep this for reference if you want to turn Koalemos (or a fork) into a SaaS product.

---

## Example: Production SaaS Deployment

### What a SaaS Deployment Would Need

Koalemos has completed M4 with a solid foundation:
- ✅ Engine architecture (GenServer-based, 92.4% test coverage)
- ✅ Three production-ready lenses (PersonaLens, SequentialThinking, WireframeEditor)
- ✅ Tool execution infrastructure
- ✅ Multi-provider LLM support
- ✅ Comprehensive developer documentation

**If you were building a SaaS, you would need:**
- **Authentication:** User accounts, login/logout, session management
- **Persistence:** PostgreSQL for user data, sessions, projects
- **Deployment:** Docker, Fly.io/AWS/GCP, CI/CD pipeline
- **Monitoring:** Sentry, metrics, logs, health checks
- **Security:** Rate limiting, input sanitization, secrets management
- **Performance:** Caching, connection pooling, optimization

**Estimated effort for SaaS:** 4-6 weeks additional development

---

## Current State (M4)

### What Works Well

**Core Engine:**
- Stable GenServer architecture
- Robust state management (context diff pattern)
- Event system with PubSub broadcasting
- Sub-routine support
- External event handling

**Lenses:**
- Context-only pattern proven (PersonaLens)
- Tool-providing pattern proven (SequentialThinking, WireframeEditor)
- Lens state management works reliably
- Tool schemas validated with real LLM usage

**Infrastructure:**
- Three LLM providers working (Anthropic, OpenAI, Ollama)
- HTML/JavaScript/CSS parsing functional
- Screenshot capture reliable
- Console integration working
- Real-time preview via LiveView-in-iframe

**Developer Experience:**
- Comprehensive documentation (4,100+ lines)
- Clear patterns and examples
- Good test coverage (782 tests, 92.4%)
- Interactive test pages
- Manual test guide

### Known Gaps for Production

**Functionality:**
- ❌ No persistent storage (sessions are ephemeral)
- ❌ No user authentication/authorization
- ❌ No session management (can't resume/save)
- ❌ No multi-user support
- ❌ No export capabilities (download wireframes)
- ❌ Limited error recovery

**Performance:**
- ❌ No rate limiting
- ❌ No caching strategy
- ❌ Large lens states in memory
- ❌ No connection pooling for LLM APIs
- ❌ No request queuing

**Reliability:**
- ❌ No health checks
- ❌ Limited error handling in some areas
- ❌ No circuit breakers for external services
- ❌ No graceful degradation

**Observability:**
- ❌ Basic logging only
- ❌ No metrics/telemetry
- ❌ No error tracking (Sentry, etc.)
- ❌ No performance monitoring
- ❌ No distributed tracing

**Security:**
- ❌ Credentials stored in plain JSON file
- ❌ No input sanitization in some areas
- ❌ No rate limiting (DoS vulnerability)
- ❌ No CORS configuration
- ❌ No CSP headers

**Deployment:**
- ❌ No Docker configuration
- ❌ No CI/CD pipeline
- ❌ No environment configuration management
- ❌ No deployment documentation
- ❌ No backup/restore procedures

---

## Milestone 5: End-to-End Application

**Goal:** Complete the wireframe design workflow with all phases.

**Estimated effort:** 2-3 weeks

### 5.1 WireframeDesign Routine (~1 week)

**Port the phased workflow from Flo:**

1. **Discovery Phase**
   - Gather requirements through conversation
   - Understand user intent
   - Clarify constraints

2. **Structure Phase**
   - Design HTML layout
   - Build semantic structure
   - Organize content hierarchy

3. **Behavior Phase**
   - Add interactivity
   - Implement JavaScript logic
   - Handle user inputs

4. **Polish Phase**
   - Refine styling
   - Improve UX
   - Final adjustments

**Implementation:**
- Phase transitions based on completion conditions
- Agent-driven routing between phases
- Context maintenance across phases
- Undo/redo support (optional)

**Files to create:**
- `lib/koalemos/routines/wireframe_design_routine.ex` (~600 lines)
- Tests (~200 lines)

### 5.2 HTML Upload/Download (~3 days)

**Features:**
- Upload existing HTML wireframes
- Parse and initialize editor state
- Download/export completed wireframes
- Save/load session state (optional)

**Implementation:**
- File upload component (LiveView)
- HTML validation and sanitization
- Export to clean HTML/CSS/JS files
- Zip archive creation for multi-file projects

**Files:**
- Upload handling in WireframeTestLive
- Export functions in WireframeEditor lens
- Download controller

### 5.3 Enhanced UI/UX (~4 days)

**Improvements:**
- Landing page with clear value proposition
- Better session management UI
- Phase indicator/progress bar
- Improved error messages
- Loading states polish
- Mobile responsiveness (basic)

**Implementation:**
- New LiveView for landing page
- Enhanced WireframeTestLive UI
- CSS improvements
- Better state visualization

### 5.4 Integration Testing (~2 days)

**Comprehensive end-to-end tests:**
- Complete workflow from start to finish
- All phase transitions
- Tool execution in each phase
- Error recovery scenarios
- Real API integration tests

---

## Milestone 6: Production Hardening

**Goal:** Make Koalemos production-ready with proper infrastructure.

**Estimated effort:** 2-3 weeks

### 6.1 Persistence Layer (~1 week)

**Add PostgreSQL + Ecto for:**
- User accounts (authentication)
- Session storage (resume conversations)
- Wireframe projects (save/load)
- Usage tracking

**Schema design:**
```
users
  - id, email, encrypted_password, created_at

sessions
  - id, user_id, routine_id, context (jsonb), created_at, updated_at

projects
  - id, user_id, name, html_content, css_content, js_content, created_at

api_usage
  - id, user_id, provider, model, tokens, cost, created_at
```

**Implementation:**
- Ecto schemas and migrations
- Session persistence functions
- Background context serialization
- Session restoration logic

**Considerations:**
- Context JSONB storage (compress if large)
- Cleanup old sessions (TTL)
- User data privacy

### 6.2 Authentication & Authorization (~4 days)

**Features:**
- User registration/login
- Session management
- API key per-user storage (encrypted)
- Basic RBAC (admin/user roles)

**Implementation:**
- Use `bcrypt_elixir` for password hashing
- Phoenix.Token for session tokens
- Encrypted API key storage (Cloak or similar)
- Auth plugs for protected routes

**Files:**
- User context + schema
- Auth controller + LiveView
- Auth plugs
- Tests

### 6.3 Deployment (~5 days)

**Docker + Fly.io setup:**

**Docker:**
- Multi-stage Dockerfile (build + runtime)
- docker-compose for local development
- Postgres, Redis (future)
- Volume mounts for credentials

**Fly.io deployment:**
- fly.toml configuration
- Secret management (API keys)
- Database setup (Fly Postgres)
- SSL/TLS (automatic)
- Auto-scaling configuration

**Environment management:**
- `.env.example` with all required vars
- Config.exs updates for runtime config
- Secret key generation scripts
- Migration running in releases

**Files:**
- `Dockerfile`
- `docker-compose.yml`
- `fly.toml`
- `.env.example`
- `docs/DEPLOYMENT.md`

### 6.4 Monitoring & Observability (~4 days)

**Logging:**
- Structured logging (JSON format)
- Log levels (debug/info/warning/error)
- Request IDs for tracing
- PII redaction

**Metrics:**
- Telemetry events throughout codebase
- Prometheus metrics export
- Key metrics:
  - Request rate/latency
  - LLM API call counts/latency
  - Tool execution counts/errors
  - Active sessions/routines
  - Memory usage

**Error Tracking:**
- Sentry integration
- Error grouping and alerts
- Source maps for JavaScript
- Release tracking

**Health Checks:**
- `/health` endpoint
- Database connectivity
- LLM provider reachability
- Disk space checks

**Implementation:**
- Add `telemetry` and `telemetry_metrics`
- Add `sentry` package
- Custom telemetry events in Engine/Steps/Lenses
- Prometheus exporter
- Health check controller

### 6.5 Performance Optimization (~3 days)

**Caching:**
- Tool schema caching (don't rebuild every request)
- Lens context caching (when appropriate)
- HTTP response caching (static assets)
- ETS for hot data

**Connection Pooling:**
- Finch for HTTP requests (already using Req which uses Finch)
- Database connection pool tuning
- LLM API connection pooling

**Rate Limiting:**
- Per-user rate limits (Phoenix.Token + ETS)
- Per-IP rate limits (Plug.Cowboy)
- LLM API rate limiting (token bucket algorithm)
- Graceful backoff

**Optimizations:**
- Lazy loading for large contexts
- Streaming responses (where possible)
- Message array trimming (keep last N only)
- GenServer pool for routine execution (if needed)

### 6.6 Security Hardening (~3 days)

**Input Sanitization:**
- HTML sanitization for user content
- JavaScript validation (already have)
- SQL injection prevention (Ecto handles)
- XSS prevention (Phoenix handles)

**Secrets Management:**
- Encrypted credential storage (Cloak)
- Environment variable validation
- Secret rotation procedures
- No secrets in logs

**Headers:**
- CSP (Content Security Policy)
- CORS configuration
- Security headers (helmet-style)
- HTTPS enforcement

**Rate Limiting:**
- Per-endpoint limits
- Distributed rate limiting (Redis + Hammer)
- DDoS mitigation

**Audit:**
- Security dependencies check
- OWASP top 10 review
- Penetration testing (basic)

### 6.7 Documentation & Polish (~3 days)

**New Documentation:**
- `docs/DEPLOYMENT.md` - How to deploy to Fly.io
- `docs/OPERATIONS.md` - How to operate in production
- `docs/SECURITY.md` - Security practices and considerations
- Update README with production features

**UI Polish:**
- Loading state animations
- Error message improvements
- Responsive design fixes
- Accessibility audit (basic)
- Dark mode support (optional)

**Bug Fixes:**
- Address all known issues
- Fix flaky tests
- Resolve console warnings
- Clean up debug code

---

## Infrastructure Recommendations

### Deployment Architecture

**Fly.io (Recommended for MVP):**
```
[Load Balancer] → [Elixir App Instances (2+)]
                          ↓
                  [Fly Postgres]
                          ↓
              [Fly Volumes for persistent data]
```

**Scaling:**
- Start with 2 instances (HA)
- Auto-scale based on CPU/memory
- Postgres with automatic backups
- Volume snapshots for safety

**Alternative: AWS/GCP/Azure:**
- ECS/EKS for container orchestration
- RDS for Postgres
- S3 for file storage
- CloudWatch/Stackdriver for monitoring

### Monitoring Stack

**Recommended:**
- **Sentry** - Error tracking ($26/month for 50k errors)
- **Fly.io Metrics** - Built-in (free)
- **Logflare** - Log aggregation (free tier available)
- **AppSignal or Scout APM** - Performance monitoring ($49-99/month)

**Alternative (self-hosted):**
- Prometheus + Grafana
- Loki for logs
- Jaeger for tracing
- More ops overhead but free

### Costs Estimate (Monthly)

**Hosting (Fly.io):**
- 2x shared-cpu-1x instances: $7/month each = $14
- Postgres (1GB): $6/month
- Volumes: $0.15/GB/month
- **Total: ~$25/month base + LLM API usage**

**LLM API Costs:**
- Anthropic: ~$3-15 per 1M tokens (input/output)
- OpenAI: ~$2.50-30 per 1M tokens
- Ollama: Free (self-hosted)
- **Estimate: $50-500/month depending on usage**

**Monitoring:**
- Sentry: $26/month (50k errors)
- APM: $49-99/month
- **Total: ~$75-125/month**

**Grand Total: ~$150-650/month for production**

---

## Risk Assessment

### High Priority Risks

**1. LLM API Rate Limits**
- **Risk:** Provider rate limits hit, service degraded
- **Mitigation:**
  - Implement request queuing
  - Multi-provider fallback
  - User rate limits
  - Ollama as backup

**2. Cost Runaway**
- **Risk:** LLM API costs spiral unexpectedly
- **Mitigation:**
  - Per-user quotas
  - Cost tracking and alerts
  - Token usage optimization
  - Billing caps

**3. Data Loss**
- **Risk:** Session data lost due to crash
- **Mitigation:**
  - Automatic session saving
  - Postgres with backups
  - Export functionality
  - Routine state checkpointing

**4. Security Breach**
- **Risk:** API keys leaked, user data exposed
- **Mitigation:**
  - Encrypted credential storage
  - No secrets in logs
  - Regular security audits
  - Penetration testing

### Medium Priority Risks

**5. Performance Degradation**
- **Risk:** App becomes slow with many users
- **Mitigation:**
  - Load testing
  - Performance monitoring
  - Horizontal scaling
  - Caching strategy

**6. Dependency Vulnerabilities**
- **Risk:** Security vulnerabilities in dependencies
- **Mitigation:**
  - Regular `mix deps.audit`
  - Dependabot alerts
  - Timely updates
  - Security scanning in CI/CD

---

## Timeline & Phases

### Phase 1: M5 Completion (Weeks 1-3)

**Week 1:**
- WireframeDesign routine implementation
- Phase transitions and routing
- Basic testing

**Week 2:**
- HTML upload/download
- Session state export
- UI improvements

**Week 3:**
- Integration testing
- Bug fixes
- Documentation updates

**Deliverable:** Complete end-to-end wireframe design workflow

### Phase 2: M6 Production Prep (Weeks 4-6)

**Week 4:**
- Persistence layer (Postgres + Ecto)
- Authentication/authorization
- Session save/restore

**Week 5:**
- Deployment setup (Docker, Fly.io)
- Monitoring integration (Sentry, metrics)
- Security hardening

**Week 6:**
- Performance optimization
- Final polish and testing
- Production documentation
- Soft launch

**Deliverable:** Production-ready Koalemos

### Phase 3: Post-Launch (Ongoing)

**Month 1:**
- Monitor production metrics
- Fix critical bugs
- Gather user feedback
- Iterate on UX

**Month 2-3:**
- Performance tuning based on real usage
- Add requested features
- Improve documentation
- Build community

**Month 4+:**
- Advanced features (see Future Enhancements)
- Scaling as needed
- New lenses and routines
- Partner integrations

---

## Future Enhancements (Post-M6)

### Advanced Features

**1. Collaborative Editing**
- Multiple users on same wireframe
- Real-time synchronization
- Presence indicators
- Conflict resolution

**2. Template Library**
- Pre-built wireframe templates
- Community templates
- Template marketplace
- Version control for templates

**3. Component System**
- Reusable UI components
- Component library
- Drag-and-drop interface
- Component composition

**4. Export Targets**
- React/Vue/Svelte code generation
- Figma/Sketch export
- PDF documentation
- Storybook generation

**5. Advanced Lenses**
- **DatabaseLens** - Query and manage database schemas
- **APILens** - Design and test API endpoints
- **CodeReviewLens** - Review code with AI assistance
- **TestGenerationLens** - Generate tests automatically
- **DocumentationLens** - Generate docs from code

**6. Routine Marketplace**
- Share custom routines
- Community contributions
- Routine versioning
- Documentation templates

### Platform Improvements

**7. Multi-Model Support**
- Use different models for different tasks
- Cost optimization (cheap models for simple tasks)
- Model routing based on task complexity
- A/B testing different models

**8. Plugin System**
- Third-party lens development
- Custom step implementations
- Hook system for extensions
- Plugin marketplace

**9. Enterprise Features**
- SSO integration (SAML, OAuth)
- Team workspaces
- Admin dashboard
- Audit logs
- Custom model deployment

**10. Developer Tools**
- Routine visual editor (no-code)
- Lens testing framework
- Debugging tools (time-travel)
- Performance profiler

---

## Success Metrics

### M5 Success Criteria

- ✅ Complete wireframe can be created through conversation
- ✅ All 4 phases working (discovery, structure, behavior, polish)
- ✅ HTML upload/download functional
- ✅ Session state can be saved/restored
- ✅ Integration tests pass
- ✅ Manual testing successful
- ✅ User can build a working prototype end-to-end

### M6 Success Criteria

- ✅ Deployed to production (Fly.io)
- ✅ User authentication working
- ✅ Sessions persist across restarts
- ✅ Health checks green
- ✅ Monitoring dashboards live
- ✅ Error tracking operational
- ✅ Security audit passed
- ✅ Performance targets met:
  - P95 response time < 2s
  - LLM API calls < 5s P95
  - Uptime > 99%
- ✅ Documentation complete
- ✅ 10 beta users can use successfully

### Post-Launch Metrics

**Adoption:**
- Active users (DAU/MAU)
- Sessions per user
- Retention (day 1, 7, 30)
- Referrals/invites

**Engagement:**
- Messages per session
- Tool executions per session
- Session duration
- Completion rate (finish wireframe)

**Quality:**
- Error rate
- LLM API success rate
- User-reported bugs
- NPS score

**Business:**
- Cost per user
- API cost as % of revenue
- Conversion rate (free → paid)
- Churn rate

---

## Decision Points

### Before M5

**Q: Support multiple wireframes per session?**
- **Option A:** One wireframe per session (simpler)
- **Option B:** Multiple wireframes (more complex but better UX)
- **Recommendation:** Start with A, add B in post-M6

**Q: Real-time preview updates or on-demand?**
- **Option A:** Update on every tool execution (real-time)
- **Option B:** Update on user request (manual)
- **Recommendation:** A (already working, better UX)

**Q: Phase transitions automatic or manual?**
- **Option A:** Agent decides when to switch phases
- **Option B:** User manually advances phases
- **Recommendation:** A with B as override (best of both)

### Before M6

**Q: Self-hosted vs managed services?**
- **Option A:** All managed (Fly.io, Sentry, etc.)
- **Option B:** Self-hosted (Prometheus, Grafana, etc.)
- **Recommendation:** A for MVP, evaluate B at scale

**Q: Freemium model or paid-only?**
- **Option A:** Free tier with limits
- **Option B:** Paid from day one
- **Recommendation:** A (free with 10 sessions/month limit)

**Q: Support Ollama in production?**
- **Option A:** Yes (let users bring their own)
- **Option B:** No (too many support issues)
- **Recommendation:** A but clearly marked as experimental

---

## Summary

**Current State:** Solid M4 foundation with comprehensive documentation

**Path to Production:**
1. **M5 (2-3 weeks):** Complete end-to-end workflow
2. **M6 (2-3 weeks):** Production hardening and deployment
3. **Post-launch:** Monitor, iterate, improve

**Total Time:** 4-6 weeks to production-ready

**Key Focus Areas:**
- Persistence and authentication (must-have)
- Deployment and monitoring (must-have)
- Performance and security (must-have)
- Polish and UX (important)
- Advanced features (post-M6)

**Estimated Costs:** $150-650/month for production infrastructure

**Next Immediate Steps:**
1. Complete Sprint 8 (documentation done ✅)
2. Tag M4 release
3. Begin M5 planning
4. Start WireframeDesign routine implementation

Koalemos has a clear path to production. The architecture is solid, the patterns are proven, and the documentation is comprehensive. With focused execution on M5 and M6, we can have a production-ready conversational AI development framework in 4-6 weeks.

---

## Actual Koalemos Goals (M5/M6)

**Koalemos Philosophy:** A developer framework and demo for building conversational AI applications. Users clone it, run it locally, and extend it for their own use cases.

---

### Milestone 5: Complete Demo Workflow

**Goal:** End-to-end wireframe design workflow with multiple stages.

**Estimated effort:** 2-3 weeks

#### 5.1 WireframeDesign Routine with Stages

**Multi-stage workflow (~5 stages):**

1. **Requirements Stage** - Gather requirements, understand user intent
2. **Design Stage** - Plan structure, layout, components
3. **Implementation Stage** - Build HTML/CSS/JS using WireframeEditor tools
4. **Test Stage** - Test interactions, verify functionality
5. **Refine Stage** (optional) - Polish and iterate

**Implementation:**
- State machine with stage transitions
- Agent-driven routing between stages
- Clear stage indicators in UI
- Ability to jump between stages
- **Ephemeral state only** - no database, sessions exist only in memory

**Files:**
- `lib/koalemos/routines/wireframe_design_routine.ex`
- Stage-specific step modules (if needed)
- Tests

#### 5.2 HTML Upload/Download

**Features:**
- Upload existing HTML to start from
- Export/download completed wireframes
- Clean HTML/CSS/JS file generation

**No persistence needed** - just file upload/download, no saving to database.

#### 5.3 Demo Polish

**Improvements:**
- Better landing page (showcase the demo)
- Stage progress indicator
- Cleaner UI for stage transitions
- Improved error messages
- Loading states

**Success Criteria:**
- ✅ Can build a complete wireframe from conversation
- ✅ All stages functional and demonstrated
- ✅ Upload/download works
- ✅ Demo is impressive and clear
- ✅ No database required

---

### Milestone 6: Framework Release Polish

**Goal:** Make Koalemos easy for developers to clone, run, and extend.

**Estimated effort:** 1-2 weeks

#### 6.1 Clean Repository

**Clean up for public release:**
- Proper `.gitignore` (no secrets, no build artifacts)
- Remove any experimental/WIP code
- Consistent code style
- Remove commented-out code
- Clean up TODO comments
- Organize file structure

**Documentation review:**
- Ensure all docs are accurate
- Fix any broken links
- Update examples to match current code
- Add missing docstrings

#### 6.2 Docker Container

**Pre-built Docker image:**
- Multi-stage Dockerfile (build + runtime)
- Optimized image size
- Includes Node.js for JavaScript parsing
- Published to Docker Hub or GitHub Container Registry
- Tagged releases (v0.4.0, v0.5.0, etc.)

**Quick start with Docker:**
```bash
docker pull koalemos/koalemos:latest
docker run -p 4000:4000 -v $(pwd)/.koalemos:/app/.koalemos koalemos/koalemos
```

#### 6.3 Docker Compose Setup

**Complete docker-compose.yml:**
- Koalemos service
- No database (not needed)
- Volume mounts for credentials
- Port mappings
- Environment variables

**Use case:**
```bash
git clone https://github.com/user/koalemos
cd koalemos
cp .env.example .env  # Configure API keys
docker-compose up
```

#### 6.4 Setup Instructions

**Three deployment paths:**

**Path 1: Pre-built Docker (Easiest)**
```markdown
# Quick Start with Docker

1. Pull the image:
   docker pull koalemos/koalemos:latest

2. Create credentials file:
   mkdir .koalemos
   echo '{"providers": {...}}' > .koalemos/.credentials.json

3. Run:
   docker run -p 4000:4000 -v $(pwd)/.koalemos:/app/.koalemos koalemos/koalemos

4. Open http://localhost:4000
```

**Path 2: Local Build (Development)**
```markdown
# Local Development

1. Install prerequisites:
   - Elixir 1.14+
   - Node.js 18+
   
2. Clone and setup:
   git clone https://github.com/user/koalemos
   cd koalemos
   mix setup

3. Configure credentials:
   cp .env.example .env

4. Run:
   mix phx.server

5. Open http://localhost:4000
```

**Path 3: Docker Compose (Recommended for Self-Hosting)**
```markdown
# Self-Hosting with Docker Compose

1. Clone:
   git clone https://github.com/user/koalemos
   cd koalemos

2. Configure:
   cp .env.example .env
   # Edit .env with your API keys

3. Run:
   docker-compose up -d

4. Open http://localhost:4000
```

#### 6.5 Developer Experience

**Make it easy to extend:**
- Clear CONTRIBUTING.md
- Code examples in docs (already done ✅)
- Template files for new lenses/routines
- VSCode settings (optional)
- Development scripts (seeds, reset, etc.)

**Example: Create new lens**
```bash
mix koalemos.gen.lens MyLens --type tool
# Creates template with TODOs filled in
```

**Example: Create new routine**
```bash
mix koalemos.gen.routine MyRoutine
# Creates template with basic structure
```

#### 6.6 Release Assets

**GitHub Release Package:**
- Docker images (automatically built)
- Release notes
- Migration guide (if breaking changes)
- Demo video/GIF
- Screenshots

**Documentation site (optional):**
- GitHub Pages with docs
- Searchable documentation
- API reference
- Tutorial videos

#### 6.7 Additional Polish

**Nice-to-haves:**
- Health check endpoint (`/health`)
- Version endpoint (`/version`)
- Example .env.example with all options
- Troubleshooting guide
- FAQ
- Demo deployment guide (for those who want to deploy publicly)

**Success Criteria:**
- ✅ Can pull and run Docker container in < 5 minutes
- ✅ Can clone and run locally in < 10 minutes
- ✅ Clear documentation for all three paths
- ✅ Easy for developers to create new lenses/routines
- ✅ Clean, professional repository
- ✅ Tagged release ready (v0.5.0 or v1.0.0)

---

## Timeline: Actual M5/M6

**M5 (2-3 weeks):**
- Week 1: WireframeDesign routine with stages
- Week 2: Stage transitions, UI polish
- Week 3: Testing, refinement

**M6 (1-2 weeks):**
- Week 1: Docker setup, clean repository
- Week 2: Documentation, release preparation

**Total: 3-5 weeks to framework release**

---

## Success Metrics

**M5 Success:**
- Complete wireframe built through conversation
- All stages demonstrated
- Impressive demo
- Ephemeral state works well

**M6 Success:**
- 5-minute Docker quick start works
- 10-minute local setup works
- Developers can create custom lenses easily
- Repository is clean and professional
- Documentation is complete and accurate
- Ready to tag v1.0.0 and announce

---

## What We're NOT Building

To be clear, we are **not** building:
- ❌ Multi-user authentication
- ❌ Session persistence/databases
- ❌ Cloud deployment infrastructure
- ❌ Payment/billing systems
- ❌ SaaS monitoring/alerting
- ❌ Multi-tenancy
- ❌ Admin dashboards
- ❌ User management

Koalemos is a **framework for developers**, not a hosted service. If someone wants to build a SaaS on top of Koalemos, they can (see the earlier parts of this document for guidance), but that's not our goal.

---

## Summary

**Koalemos = Framework + Demo**

**M5:** Complete the impressive demo (multi-stage workflow)
**M6:** Make it ridiculously easy to run and extend

That's it. Simple, focused, and achievable.
