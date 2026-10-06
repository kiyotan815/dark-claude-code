# Agent Orchestration

## Available Agents

Shipped by the `dcc@dark-claude-code` plugin, so their names carry the `dcc:`
prefix. Built-in agents (`Explore`, `Plan`, `general-purpose`) already cover
search and planning; the kit only adds review gates.

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| dcc:code-reviewer | Code review | After writing or modifying code |
| dcc:security-reviewer | Security analysis | Code touching auth, input, secrets, endpoints; before commits |
| dcc:spec-reviewer | Codex delegation spec review | /dcc:codex-flow design gate, before delegating |
| dcc:codex-auditor | Audit of Codex deliverables | After /dcc:codex-impl, before commit |

## Immediate Agent Usage

No user prompt needed:
1. Code just written/modified - Use **dcc:code-reviewer**
2. Security-sensitive diff - escalate to **dcc:security-reviewer**
3. Design doc ready for Codex - **dcc:spec-reviewer** before delegating,
   **dcc:codex-auditor** after implementation

## Parallel Task Execution

ALWAYS launch independent agents in one message so they run concurrently.
For large fan-out work (codebase-wide audits, 10+ independent items) prefer
the Workflow tool when the user has opted in (`ultracode` / "use a workflow").

## Multi-Perspective Analysis

For complex problems, use split role sub-agents (general-purpose with
distinct briefs):
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker
