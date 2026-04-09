# Generic Work Item — Invocation Map

How skills and agents call each other across the full workflow. Indentation = called by the parent. `(agent)` = runs in isolated sub-agent context. `(skill)` = invoked via Skill tool. `(MCP)` = external tool call.

```
generic-work-item-worktree-setup  (skill — runs in MAIN REPO session)
│   git worktree add .worktrees/{name}
│   Write .claude/.workflow into worktree
│   osascript → opens iTerm tab:
│     claude --worktree {name} -p "/generic-work-item-full-implementation-workflow {TICKET}"
│
▼  (new independent session — worktree is project root)

generic-work-item-full-implementation-workflow  (skill — orchestrator, runs in WORKTREE session)
│
├── [startup] generic-work-item-workflow-state  (skill)  [operation: read]
│
├── [Phase 1]
│     generic-work-item-preparation  (skill)
│       ├── generic-jira-contributor-context  (skill)
│       ├── generic-work-item-feature-linker  (agent)
│       ├── generic-work-item-field-auditor   (agent)
│       ├── generic-work-item-title-improver  (agent)
│       ├── generic-work-item-intention-writer  (agent)
│       └── generic-spec  (skill)
│
├── [Phase 2]
│     generic-work-item-pre-implementation-tech-scope  (skill)
│       ├── generic-work-item-feature-technical-scope  (agent) ×N  [parallel]
│       │     └── generic-work-item-feature-technical-scope  (agent) ×M  [sub-areas, parallel]
│       └── generic-work-item-technical-reviewer  (agent)
│
├── [Phase 3]
│     generic-work-item-implementation-start  (skill)
│       ├── generic-work-item-impact-analyzer  (agent)
│       ├── generic-work-item-foundation-builder  (agent)
│       ├── generic-work-item-code-reviewer  (agent)  [scope: foundation]
│       │
│       ├── [serial loop — one area at a time]
│       │     generic-work-item-area-implementer  (skill)
│       │     generic-work-item-code-reviewer  (agent)  [scope: area:<name>]
│       │       └── generic-work-item-area-implementer  (skill)  [fix mode, if issues]
│       │
│       ├── generic-work-item-code-reviewer  (agent)  [scope: full]
│       │     └── generic-work-item-area-implementer  (skill)  [fix mode, if issues]
│       │
│       └── generic-work-item-isolation-reviewer  (agent) ×N  [parallel, read-only]
│
└── [Phase 4]
      generic-work-item-ship  (skill)
        └── slack_send_message  (MCP)  [conditional — if slack_notify_channel is set]
```

## Standalone entry points

Each phase skill can also be invoked directly, without going through the full workflow:

| Skill | Standalone invocation |
|---|---|
| `generic-work-item-preparation` | Prepare a single ticket or raw intent |
| `generic-work-item-worktree-setup` | Create the worktree for a ticket |
| `generic-work-item-pre-implementation-tech-scope` | Scope a ticket that already has an intention |
| `generic-work-item-implementation-start` | Implement a ticket that already has a Technical Scope |
| `generic-work-item-area-implementer` | Implement or fix a single area in isolation |
| `generic-work-item-ship` | Commit, push, and open a PR for a completed implementation |
