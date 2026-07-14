# Performance Optimization

## Model Selection Strategy

Pick by tier, not pinned version (version names go stale; use `haiku` / `sonnet` / `opus` aliases in agent frontmatter):

**Haiku tier** (lightweight, fast, low-cost):
- Lightweight agents with frequent invocation
- Worker agents in multi-agent systems

**Sonnet tier** (balanced cost/quality):
- Main development work
- Orchestrating multi-agent workflows

**Opus tier and above** (deepest reasoning):
- Complex architectural decisions
- Large-context research and analysis

## Context Window Management

Avoid last 20% of context window for:
- Large-scale refactoring
- Feature implementation spanning multiple files
- Debugging complex interactions

Lower context sensitivity tasks:
- Single-file edits
- Independent utility creation
- Documentation updates
- Simple bug fixes

## Ultrathink + Plan Mode

For complex tasks requiring deep reasoning:
1. Use `ultrathink` for enhanced thinking
2. Enable **Plan Mode** for structured approach
3. "Rev the engine" with multiple critique rounds
4. Use split role sub-agents for diverse analysis

## Build Troubleshooting

If build fails:
1. Use **build-error-resolver** agent
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix
