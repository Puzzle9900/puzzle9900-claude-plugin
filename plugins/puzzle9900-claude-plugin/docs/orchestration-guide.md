# Claude Code Orchestration Guide

How agents, skills, hooks, and configuration work together to build automated pipelines.

---

## The Mental Model

```
You (or CI) → Claude (conductor) → Agents (specialists)
                    ↓
              Skills (workflows)
              Hooks (enforcement)
              CLAUDE.md (context)
              MCP (external tools)
```

Claude is always the orchestrator. Agents don't talk to each other — they report to Claude, who decides what to do next.

---

## 1. Agents

### What They Are

Agents are specialized subprocesses Claude spawns with isolated context windows. Think of them as specialists the conductor brings in for specific parts of the work.

Each agent:
- Gets its own isolated context (separate memory/conversation)
- Has a restricted set of tools (some read-only, others can write)
- Runs a specific model (Haiku for speed, Opus for depth)
- Returns a single result back to the main session

### Built-in Types

| Type | Model | Can Write? | Best For |
|------|-------|------------|----------|
| **Explore** | Haiku (fast) | No | Codebase search, understanding code |
| **Plan** | Inherits parent | No | Architecture, implementation strategy |
| **general-purpose** | Inherits parent | Yes | Multi-step tasks needing read + write |

### Lifecycle

```
DETECTION  →  Claude matches task to agent type
SPAWNING   →  Fresh context, no inherited history
EXECUTION  →  Agent works with its tools
REPORTING  →  Results summarized back to main session
CLEANUP    →  Context discarded (unless resumed)
```

**Key constraint**: Agents cannot spawn other agents. Only the main Claude session orchestrates.

### Worktree Isolation

Agents can work in isolated git worktrees — separate repo copies on different branches:

```
Main session  →  branch "main"
Agent A       →  branch "feature-a" (separate directory)
Agent B       →  branch "feature-b" (separate directory)
```

Multiple agents can edit files simultaneously without conflicts.

---

## 2. Connecting Agents

### Sequential (A → B → C)

```
Claude:
  1. Spawns Explore agent → gets research
  2. Reads results, spawns Plan agent → gets plan
  3. Reads plan, spawns general-purpose agent → implements
```

### Parallel (A + B + C simultaneously)

```
Claude:
  Agent A (worktree) → investigates bug #1
  Agent B (worktree) → investigates bug #2
  Agent C (worktree) → investigates bug #3
  All run concurrently. Claude collects all results.
```

### Background Agents

Agents can run in background while you keep working. You get notified when they finish.

### How Data Flows

1. **Claude's context** — Claude summarizes Agent A's output, passes to Agent B
2. **Files on disk** — Agent A writes a file, Agent B reads it
3. **Git branches** — Agent A commits, Agent B checks it out

No direct agent-to-agent communication. Claude is always the intermediary.

---

## 3. Retrying

### What Happens on Failure

- **Tool failure** → agent tries to recover
- **Permission denied** → agent adjusts approach
- **Timeout** → agent exits, main Claude gets failure notice
- **Context exhaustion** → auto-compacts or stops

### Retry Strategies

**Let Claude manage it** (recommended):
```
"Run tests. If they fail, debug and fix. Retry up to 3 times."
```

**Resume a failed agent**:
Every agent gets a unique ID. Resume it with full context preserved — picks up exactly where it stopped.

**Retry with different approach**:
```
"That didn't work. Try using the REST API instead."
```

**In CI/CD**:
```bash
for attempt in 1 2 3; do
  result=$(claude -p "Fix failing tests" --output-format json)
  if echo "$result" | jq -e '.result == "success"'; then break; fi
done
```

---

## 4. Reviewing

### Agent Reviewing Agent

Use one agent to implement, another to review:

```
1. general-purpose agent → implements feature
2. Explore agent → reviews for security issues
3. Issues found? → general-purpose fixes them
4. Repeat until reviewer approves
```

### Review Patterns

| Pattern | How It Works |
|---------|-------------|
| **Implement + Test** | Agent A writes code, Agent B writes/runs tests, fix loop |
| **Implement + Security Audit** | Agent A builds, Agent B audits OWASP top 10 |
| **Implement + Style Review** | Hooks auto-lint, Agent B checks architecture |
| **Multi-reviewer** | Agents A/B/C review security/performance/tests, Claude synthesizes |

---

## 5. Hooks: Automated Enforcement

Hooks are shell commands that run automatically at lifecycle points. Unlike skills (Claude decides), hooks are **deterministic** — they always execute.

### Key Events

| Event | When | Use |
|-------|------|-----|
| `PreToolUse` | Before a tool runs | Block dangerous commands |
| `PostToolUse` | After a tool succeeds | Auto-lint, auto-format |
| `SubagentStart` | Agent spawned | Setup resources |
| `SubagentStop` | Agent completed | Cleanup |
| `Stop` | Claude finishes responding | Post-response validation |

### Configuration (.claude/settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {"type": "command", "command": "npm run lint --fix"}
        ]
      }
    ]
  }
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Allow — stdout added to Claude's context |
| `2` | Block — stderr becomes Claude's feedback |

---

## 6. Building Pipelines

### The Pipeline Pattern

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ RESEARCH │ →  │   PLAN   │ →  │  BUILD   │ →  │  TEST    │ →  │  SHIP    │
│ (Explore)│    │  (Plan)  │    │(general) │    │  (Bash)  │    │ (Skill)  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
     ↑                                               │
     └───────────── retry on failure ────────────────┘
```

### Minimizing Manual Intervention

| Layer | What It Automates |
|-------|-------------------|
| **CLAUDE.md** | Claude knows build commands, architecture, rules without asking |
| **Skills** | Predefined workflows triggered with one command |
| **Hooks** | Linting, formatting, type-checking run automatically |
| **Self-healing loops** | "Fix and retry until tests pass" |
| **Agent review** | Second agent catches issues without human review |
| **Headless mode** | Run entire pipelines from CI without any human |

### The Automation Spectrum

```
Manual ──────────────────────────────────────── Fully Automated

"fix this    "/skill-name   "claude -p      Scheduled
 bug"         args"          'do X'"        CI pipeline

 ↑             ↑              ↑              ↑
 You type    One command    No UI at all   No human
 each step   full pipeline  CLI only       at all
```

---

## 7. Headless Mode and CI/CD

```bash
# One-shot task
claude -p "Fix the failing test" --allowedTools "Read,Edit,Bash"

# JSON output
claude -p "List all endpoints" --output-format json

# Continue previous session
claude -p "Continue" --continue

# Resume specific session
claude -p "Apply fixes" --resume "$SESSION_ID"
```

### GitHub Actions

```yaml
name: AI Code Review
on: [pull_request]
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          claude -p "Review this PR for security issues" \
            --allowedTools "Read,Bash(git diff*)" \
            --output-format json > review.json
```

---

## 8. MCP Servers

MCP servers give Claude access to external systems:

```bash
claude mcp add github -- npx @modelcontextprotocol/server-github
claude mcp add postgres -- python /path/to/postgres_mcp.py
```

In pipelines:
```
Research agent  → GitHub MCP to read issues
Build agent     → filesystem tools to write code
Deploy agent    → AWS MCP to push changes
Monitor agent   → Grafana MCP to check metrics
```

---

## 9. CLAUDE.md and Persistent Context

### Where They Live

| Location | Scope | Shared? |
|----------|-------|---------|
| `./CLAUDE.md` | This project | Yes (commit it) |
| `~/.claude/CLAUDE.md` | All your projects | No (personal) |
| `.claude/rules/*.md` | Path-specific rules | Yes |

### What Goes Where

- **CLAUDE.md** → Context Claude always needs (build commands, architecture)
- **Rules** → Conventions Claude must always follow (style, patterns)
- **Skills** → Workflows Claude executes on demand (see [Skills Guide](skills-guide.md))

---

## 10. Putting It All Together

The layers work together:

```
CLAUDE.md        → Claude knows your project before you say anything
Rules            → Claude follows your conventions automatically
Skills           → One command triggers a multi-phase pipeline
Hooks            → Quality gates enforce themselves
Agents           → Specialists handle research, review, parallel work
MCP              → Claude reaches external systems
Headless mode    → No human needed at all
```

Start small: CLAUDE.md + one skill. Add hooks for enforcement. Graduate to multi-agent pipelines as confidence grows.
