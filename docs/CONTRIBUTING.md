# Contributing to Koalemos

**Status:** Active development (Milestone 2+)

---

## Development Workflow

### Branch Strategy

We use Git Flow for structured development:

- **`main`** - Production-ready code, tagged milestone releases
- **`develop`** - Integration branch for completed features
- **`feature/*`** - Feature branches for active development

### Process

1. **Create Feature Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/m2-ui-foundation
   ```

2. **Develop and Test**
   - Write code
   - Add tests (maintain >85% coverage)
   - Run full test suite: `mix test`
   - Update documentation as needed

3. **Commit Guidelines**
   - Write clear, concise commit messages
   - Format: `<component>: <change>`
   - Examples:
     ```
     LiveView: Add basic chat interface
     TemplatedSemanticAgent: Port from Flo
     Tests: Add integration tests for agent loop
     ```

4. **Create Pull Request**
   - Target: `develop` branch
   - Title: Descriptive (e.g., "M2: Add basic LiveView chat interface")
   - Description: What changed, why, test results
   - Link to milestone/issue if applicable

5. **Code Review**
   - At least one approval required
   - Address feedback
   - Update PR as needed

6. **Merge to Develop**
   - Squash commits if many small ones
   - Delete feature branch after merge

7. **Milestone Release**
   - When milestone complete, merge `develop` → `main`
   - Tag release: `git tag v2.0.0-milestone2`
   - Push tags: `git push --tags`

---

## Milestone Structure

See [BACKLOG.md](./BACKLOG.md) for detailed milestone breakdown.

**Current Milestones:**
- ✅ M1: Foundation (complete)
- 🚧 M2: UI Foundation + Simple Agent Loop (in progress)
- ⏳ M3: Infrastructure Layer
- ⏳ M4: WireframeEditor Lens
- ⏳ M5: WireframeDesign Routine (MVP complete)
- ⏳ M6: Polish & Production-Ready

---

## Code Standards

### Elixir

**Style:**
- Follow [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Run `mix format` before committing
- Use `@moduledoc` and `@doc` for all public modules/functions

**Testing:**
- Unit tests for all modules
- Integration tests for workflows
- Target: >85% test coverage
- Run: `mix test` or `mix coveralls.detail`

**Naming:**
- See [NAMING.md](./NAMING.md) for conventions
- Modules: `PascalCase`
- Functions: `snake_case`
- Atoms: `:snake_case`

### LiveView/JavaScript

**Style:**
- Semantic HTML
- Tailwind CSS for styling
- Minimal JavaScript (use LiveView where possible)
- Document JavaScript hooks

---

## Testing

### Running Tests

```bash
# All tests
mix test

# Specific file
mix test test/koalemos/engine_test.exs

# Specific test
mix test test/koalemos/engine_test.exs:42

# With coverage
mix coveralls.detail

# Real API tests (requires credentials)
mix test --include real_api
```

### Writing Tests

**Unit Tests:**
```elixir
defmodule Koalemos.MyModuleTest do
  use ExUnit.Case, async: true

  describe "function_name/2" do
    test "handles normal case" do
      assert MyModule.function_name(arg1, arg2) == expected
    end

    test "handles error case" do
      assert {:error, _} = MyModule.function_name(bad_arg1, bad_arg2)
    end
  end
end
```

**Integration Tests:**
```elixir
defmodule Koalemos.Integration.MyFlowTest do
  use Koalemos.IntegrationTestCase, async: false

  test "complete workflow", %{routine_id: routine_id} do
    {:ok, pid} = EngineManager.start_routine(routine_id, MyRoutine, %{})

    assert_receive {:routine_event, %{event_type: "routine_completed"}}, 1000

    state = :sys.get_state(pid)
    assert state.routine_status == :completed
  end
end
```

---

## Documentation

### When to Update Docs

- **BACKLOG.md** - When completing milestones, marking todos done
- **COVERAGE_LOG.md** - After each phase/milestone, log test coverage
- **ARCHITECTURE.md** - When adding major components or changing design
- **NAMING.md** - When establishing new naming conventions
- **README.md** - When changing setup, requirements, or usage

### Documentation Style

- Clear, concise explanations
- Code examples where helpful
- Link to relevant files/modules
- Keep it up-to-date (docs rot quickly!)

---

## Getting Help

- **Questions:** Open an issue with `question` label
- **Bugs:** Open an issue with `bug` label
- **Discussions:** Use GitHub Discussions for design questions

---

## Development Setup

See [README.md](../README.md) for setup instructions.

**Quick Start:**
```bash
git clone https://github.com/gbelinsky/koalemos.git
cd koalemos
mix deps.get
mix test
mix phx.server
```

---

## Release Process

**Milestone Release:**
1. Complete all milestone todos
2. Run full test suite: `mix test`
3. Update COVERAGE_LOG.md with final stats
4. Update BACKLOG.md (mark milestone complete)
5. Merge `develop` → `main`
6. Tag release: `git tag v2.0.0-milestone2 -m "Milestone 2: UI Foundation + Simple Agent Loop"`
7. Push: `git push origin main --tags`
8. Create GitHub release with changelog

---

## Code of Conduct

Be respectful, constructive, and collaborative.

---

**Questions?** Open an issue or discussion on GitHub.
