# Agent Orchestration

## Available Agents

Located in `.claude/agents/` (project) or `~/.claude/agents/` (user-global). dark-claude-code ships these in `agents/`:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| planner | Implementation planning | Complex features, refactoring |
| architect | System design | Architectural decisions |
| tdd-guide | Test-driven development | New features, bug fixes |
| code-reviewer | Code review | After writing code |
| security-reviewer | Security analysis | Before commits |
| database-reviewer | PostgreSQL/SQL review | SQL, migrations, schema design |
| build-error-resolver | Fix build errors | When build fails |
| e2e-runner | E2E testing | Critical user flows |
| refactor-cleaner | Dead code cleanup | Code maintenance |
| doc-updater | Documentation | Updating docs |
| spec-pragmatic | MVP-focused spec proposal (提案A) | Multi-perspective spec drafting |
| spec-architect | Extensibility-focused spec proposal (提案B) | Multi-perspective spec drafting |
| spec-ux | UX-focused spec proposal (提案C) | Multi-perspective spec drafting |
| spec-reviewer | Codex delegation spec review | /codex-flow design gate, before delegating |
| codex-auditor | Audit of Codex deliverables | After /codex-impl, before commit |

## Immediate Agent Usage

No user prompt needed:
1. Complex feature requests - Use **planner** agent
2. Code just written/modified - Use **code-reviewer** agent
3. Bug fix or new feature - Use **tdd-guide** agent
4. Architectural decision - Use **architect** agent

## Parallel Task Execution

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth.ts
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utils.ts

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Multi-Perspective Analysis

For complex problems, use split role sub-agents:
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker
