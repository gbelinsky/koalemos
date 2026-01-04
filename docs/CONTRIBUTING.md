# Contributing to Koalemos

## Development Workflow

### Branch Strategy

- `main` - Stable releases
- `develop` - Integration branch for completed features
- `feature/*` - Active development

### Process

1. Create a feature branch from `develop`
2. Write code and tests (maintain >85% coverage)
3. Run `mix test` and `mix format`
4. Open a pull request to `develop`
5. Address review feedback
6. Merge when approved

### Commit Messages

Use the format: `<component>: <change>`

Examples:
```
Engine: Fix state transition edge case
WireframeEditor: Add CSS grid support
Tests: Add lens integration tests
```

## Code Standards

### Elixir

- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Run `mix format` before committing
- Add `@moduledoc` and `@doc` to public modules and functions
- Use descriptive variable names

### Testing

```bash
# Run all tests
mix test

# Run with coverage
mix coveralls.detail

# Run specific file
mix test test/koalemos/engine_test.exs

# Include real API tests (requires credentials)
mix test --include real_api
```

Write tests for new functionality:

```elixir
defmodule Koalemos.MyModuleTest do
  use ExUnit.Case, async: true

  describe "my_function/2" do
    test "returns expected result" do
      assert MyModule.my_function(arg1, arg2) == expected
    end

    test "handles errors" do
      assert {:error, _} = MyModule.my_function(bad_arg)
    end
  end
end
```

### LiveView and JavaScript

- Use semantic HTML
- Style with Tailwind CSS
- Prefer LiveView over JavaScript where possible
- Document JavaScript hooks in the module they support

## Documentation

Update docs when you change:

- Setup or requirements: update README.md
- Architecture or major components: update docs/ARCHITECTURE.md
- Features or usage: update the relevant guide in docs/guides/

Keep documentation concise. Include code examples where they help.

## Getting Help

Open a GitHub issue for bugs or questions.

## Development Setup

See [README.md](../README.md) for setup instructions.

```bash
git clone https://github.com/gbelinsky/koalemos.git
cd koalemos
mix deps.get
mix test
mix phx.server
```
