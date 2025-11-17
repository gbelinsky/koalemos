# Contributing to Koalemos

**Status:** Active development - M6 (Demo Release)

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
   git checkout -b feature/my-feature-name
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
   - Title: Descriptive (e.g., "Add persona configuration to chat interface")
   - Description: What changed, why, test results
   - Link to issue if applicable

5. **Code Review**
   - At least one approval required
   - Address feedback
   - Update PR as needed

6. **Merge to Develop**
   - Squash commits if many small ones
   - Delete feature branch after merge

7. **Release**
   - When release ready, merge `develop` → `main`
   - Tag release: `git tag v1.0.0`
   - Push tags: `git push --tags`

---

## Project Status

**Current Status:** M6 Demo Release
- ✅ M1-M5: Core framework complete (Engine, Lenses, Routines, Wireframe Editor)
- 🚧 M6: Demo polish and documentation (in progress)

See `docs/internal/` for detailed milestone history and development tracking.

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

**Naming Conventions:**
- Modules: `PascalCase` (e.g., `Koalemos.Lenses.PersonaLens`)
- Functions: `snake_case` (e.g., `provide_context/2`)
- Atoms: `:snake_case` (e.g., `:llm_provider`)

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

- **README.md** - When changing setup, requirements, or usage
- **ARCHITECTURE.md** - When adding major components or changing design
- **guides/** - When adding new lenses, routines, or features
- **CHANGELOG.md** - For any user-facing changes

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

**Creating a Release:**
1. Ensure all tests pass: `mix test`
2. Update CHANGELOG.md with changes
3. Merge `develop` → `main`
4. Tag release: `git tag v1.0.0 -m "Release v1.0.0: Description"`
5. Push: `git push origin main --tags`
6. Create GitHub release with changelog

---

## Code of Conduct

Be respectful, constructive, and collaborative.

---

**Questions?** Open an issue or discussion on GitHub.
