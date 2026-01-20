# Retrospective Analysis

The Retrospective Analysis feature allows you to analyze completed tasks and extract learnings, insights, and recommendations.

## Overview

After completing a task with any routine (like `ContextAgentRoutine`), you can run a retrospective analysis to extract:

- **What was learned** - Insights that emerged during the task
- **Prerequisites** - Knowledge that would have helped beforehand
- **Patterns** - What worked well and what didn't
- **Recommendations** - Advice for similar future tasks

## Components

### RetrospectiveLens

A context-only lens that loads and formats conversation history from a completed routine.

**Features:**
- Loads complete message history
- Formats tool calls and results
- Provides task metadata
- Supports context snapshots (future enhancement)

**Configuration:**
```elixir
["Koalemos.Lenses.RetrospectiveLens", %{
  source_routine_id: "task-123"
}]
```

### RetrospectiveRoutine

A single-step routine that uses the RetrospectiveLens and StructuredResponseAgent to analyze a completed task.

**Flow:**
1. Loads source routine history via RetrospectiveLens
2. Agent analyzes using SequentialThinking (optional)
3. Agent produces structured markdown document
4. Document stored in `context[:structured_output]`

## Usage

### Step 1: Complete a Task

First, run any routine that performs a task:

```elixir
# Start a coding task
{:ok, task_id} = Koalemos.EngineManager.start_routine(
  Koalemos.Routines.ContextAgentRoutine,
  %{
    working_directory: ".",
    system_prompt: "You are a helpful coding assistant"
  },
  "task-#{System.unique_integer([:positive])}"
)

# ... interact with the agent to complete the task ...
```

### Step 2: Run Retrospective Analysis

Once the task is complete, analyze it:

```elixir
{:ok, retro_id} = Koalemos.EngineManager.start_routine(
  Koalemos.Routines.RetrospectiveRoutine,
  %{source_routine_id: task_id},
  "retro-#{System.unique_integer([:positive])}"
)

# Wait for analysis to complete
# The agent will automatically analyze and produce a document
```

### Step 3: Retrieve Results

Get the knowledge document:

```elixir
{:ok, info} = Koalemos.EngineManager.get_routine(retro_id)
knowledge_doc = info.context[:structured_output]["knowledge_document"]

# Save to file
File.write!("retrospective-#{task_id}.md", knowledge_doc)
```

## Example Output

The agent produces a structured markdown document like:

```markdown
# Retrospective Analysis: Task XYZ

## What Was Learned

During this task, we discovered that...

## Prerequisites That Would Have Helped

Before starting, it would have been valuable to know...

## Patterns That Emerged

### Effective Approaches
- Pattern 1: ...
- Pattern 2: ...

### Ineffective Approaches
- Anti-pattern 1: ...

## Key Recommendations

For similar tasks in the future:
1. Start by...
2. Ensure that...
3. Avoid...
```

## Configuration

### Model Selection

The routine uses `claude-sonnet-4-5` by default for high-quality analysis. You can override:

```elixir
%{
  source_routine_id: task_id,
  llm_model: "claude-opus-4",  # For even deeper analysis
  max_tokens: 32000,           # For longer documents
  temperature: 0.2             # For more focused output
}
```

### Prompt Customization

The analysis prompt is embedded in the routine but can be customized by modifying `RetrospectiveRoutine`.

## Future Enhancements

- **Context Snapshots**: Capture rendered context at each turn for deeper analysis
- **Multi-Task Analysis**: Aggregate learnings across multiple similar tasks
- **Knowledge Base Integration**: Store insights for future task planning
- **Automated Triggers**: Run retrospectives automatically on task completion
- **Comparative Analysis**: Compare approaches across different task attempts

## Implementation Notes

### Why a Custom Lens?

We use a custom lens (RetrospectiveLens) rather than injecting messages because:
1. Lenses provide clean context injection via system prompt
2. Separates "current conversation" from "analyzed conversation"
3. Reusable across different analysis routines
4. Follows Koalemos architectural patterns

### Why StructuredResponseAgent?

StructuredResponseAgent provides:
1. Multi-turn agent loop (can use tools to explore)
2. Structured output format (markdown string)
3. Automatic exit when analysis complete
4. Integration with SequentialThinking for complex reasoning

## Testing

To test the retrospective analysis:

1. Run a simple task with ContextAgentRoutine
2. Note the routine ID
3. Run RetrospectiveRoutine with that ID
4. Examine the generated knowledge document

Example test scenario:
```elixir
# 1. Create a simple file
{:ok, task_id} = start_routine(ContextAgentRoutine, ...)
# User: "Create a hello.txt file with 'Hello World'"
# Agent uses Write tool

# 2. Analyze the task
{:ok, retro_id} = start_routine(RetrospectiveRoutine, %{source_routine_id: task_id})
# Agent analyzes: "Learned that Write tool auto-opens files..."

# 3. Review insights
{:ok, info} = get_routine(retro_id)
IO.puts(info.context[:structured_output]["knowledge_document"])
```
