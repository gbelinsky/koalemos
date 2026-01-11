# Code Comprehension System

Design document for a codebase understanding feature that generates structured documentation from source code, useful for human onboarding and agent context.

## Use Cases

1. **Onboarding** - Understanding a new codebase (joining a team, exploring open source)
2. **Documentation generation** - Automated, maintainable docs that stay close to code
3. **Agent context** - Providing structure and understanding when agents are asked about or modify code
4. **Sync on demand** - Re-evaluate existing documentation against current code state

## Design Philosophy

Mirrors how a human approaches understanding a new codebase:

1. **Orientation** - README, entry points, what's the shape
2. **Map the territory** - directories, key files, what goes where
3. **Identify abstractions** - core concepts, where they live
4. **Trace flows** - pick something concrete, follow it end-to-end
5. **Extract patterns** - conventions that repeat, what's idiomatic
6. **Build mental model** - how pieces connect, the architecture

## Phased Approach

### Phase 1: Orientation (mostly programmatic)

- Read README, docs/
- List directory structure
- Identify language, framework, build system
- Find entry points (main, config, tests)

**Output:** `orientation.md`, `file_tree.json`

### Phase 2: Module Mapping (programmatic + light LLM)

- Group files by directory/namespace
- Extract imports/dependencies
- LLM: one-line purpose for each module

**Output:** `modules.md`, `dependency_graph.json`

### Phase 3: Deep Summaries (LLM per file, batched)

For each key file:
- Read file content
- LLM: what does this do, key functions, relationships
- Store summary

**Output:** `summaries/{module_name}.md`

### Phase 4: Pattern Extraction (LLM synthesis)

- Input: summaries + code samples
- LLM: identify recurring patterns, conventions

**Output:** `patterns.md`

### Phase 5: Architecture (LLM reasoning)

- Input: all above + selective code reads
- LLM: how pieces fit together, data flow, control flow

**Output:** `architecture.md`

## Output Structure

```
.koalemos/comprehension/
├── orientation.md       # Quick start, entry points
├── architecture.md      # High-level how it fits together
├── modules.md           # Module-by-module breakdown
├── patterns.md          # Recurring patterns and conventions
├── summaries/
│   ├── engine.md
│   ├── lenses.md
│   └── ...
├── file_tree.json       # Structured file listing
├── dependency_graph.json # Import/dependency relationships
└── index.json           # Metadata for programmatic access
```

**Format decision:** Markdown primary (human and agent readable), structured JSON where there's inherent structure (graphs, indexes, relationships).

## Routine Structure

### Option A: Single Routine

```
comprehend(path: "/project") → runs all phases sequentially
```

### Option B: Composable Routines (preferred)

```
orient(path: "/project")     → orientation.md, file_tree.json
map_modules(path: "/project") → modules.md, dependency_graph.json
summarize(path: "/project")   → summaries/*.md
synthesize(path: "/project")  → patterns.md, architecture.md
```

Option B is more flexible:
- Run just orientation for a quick overview
- Re-run synthesize without re-summarizing
- Parallel execution of independent phases

## Implementation Considerations

### File Prioritization

Can't summarize every file in a large codebase. Prioritization heuristics:

| Priority | File Type |
|----------|-----------|
| High | Entry points |
| High | Files with many dependents (imported often) |
| Medium | Files with complex logic (high line count, many functions) |
| Low | Test files (reveal intent, but secondary) |
| Skip/Minimal | Config, boilerplate, generated code |

A `PrioritizeFilesStep` scores files and produces a processing queue.

### Loop Structure for Summaries

```elixir
%{
  prioritize: %{
    type: PrioritizeFilesStep,
    transitions: [{:summarize_next, :always}]
  },
  summarize_next: %{
    type: SummarizeFileStep,
    transitions: [
      {:summarize_next, :when_more_files},
      {:extract_patterns, :always}
    ]
  },
  extract_patterns: %{
    type: ExtractPatternsStep,
    transitions: [{:build_architecture, :always}]
  }
}
```

### Context for Summarization

When summarizing a file, what context does the LLM need?

| Approach | Pros | Cons |
|----------|------|------|
| Just the file | Simple | Loses relationships |
| File + imports | Better context | Imports might be huge |
| File + orientation | Provides framing | Still isolated |
| File + dependency summaries | Ideal | Creates ordering dependency |

**Proposed:** Two-pass approach
1. First pass: summarize each file in isolation
2. Second pass: enrich summaries with cross-references

### Large File Handling

Files exceeding context limits need chunking:
- Summarize by section/class/function
- Or truncate with note about what was omitted

### Progress and Resumability

For large codebases, track progress for resumability:

```elixir
%{
  status: :in_progress,
  phase: :summarize,
  completed_files: ["lib/engine.ex", ...],
  remaining_files: [...],
  started_at: ~U[...],
  last_updated: ~U[...]
}
```

### Sync Routine

Smart update when code changes:

1. Diff current files against last comprehension timestamp
2. Re-run summaries only for changed files
3. If enough changed (threshold), re-run pattern/architecture phases
4. Update timestamps, mark potentially stale sections

## Agent Integration (Lens)

```elixir
defmodule CodeComprehensionLens do
  def provide_context(context, config) do
    project_path = config[:project_path]
    comprehension = load_comprehension(project_path)

    # Always include orientation + architecture
    base = [
      comprehension.orientation,
      comprehension.architecture
    ]

    # Add relevant module summaries based on files being touched
    relevant = context[:files_mentioned]
    |> Enum.flat_map(&find_related_summaries(&1, comprehension))

    format_as_context(base ++ relevant)
  end
end
```

## Open Questions

1. **Parallelization** - Should module summarization run in parallel sub-routines?

2. **Incremental vs full** - When does a sync require full re-comprehension vs incremental updates?

3. **Depth control** - Should there be a "quick" vs "thorough" mode?

4. **Language-specific parsing** - How much should we leverage AST parsing vs treating code as text?

5. **Cross-project patterns** - Could pattern extraction learn from multiple codebases?

6. **Staleness indicators** - How to surface when documentation might be out of date?

## Related: Memory System

This design shares patterns with the proposed memory system:

| Aspect | Memory | Code Comprehension |
|--------|--------|-------------------|
| Intake | Extract from conversation | Extract from code |
| Storage | Short-term → Long-term | Summaries → Patterns → Architecture |
| Retrieval | Entity match + embedding | File match + module relationship |
| Staleness | Time-based decay | Git diff based |

Both could share infrastructure for storage, retrieval, and lens integration.
