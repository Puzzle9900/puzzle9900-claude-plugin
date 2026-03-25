---
name: generic-agent-best-practices
description: Best practices and quality guidelines for writing effective agent definitions. Use this before or during agent creation to ensure the agent is well-designed, maintainable, and useful.
type: generic
---

# generic-agent-best-practices

## Context

This skill provides quality and design guidance for writing agent definitions. It complements `generic-agent-creator-structure`, which covers file format and naming. This skill covers what makes an agent actually effective: clear identity, smart knowledge design, runtime behaviors, and long-term maintainability.

Use this skill when:
- You are about to create a new agent and want to ensure quality
- You are reviewing or improving an existing agent
- You need guidance on whether an agent is the right solution for a problem

## Instructions

Apply these best practices when creating, reviewing, or improving any agent definition. Each practice addresses a specific failure mode observed in real agent usage. When reviewing an existing agent, check each practice and flag violations.

## Steps

### 1. One agent, one concern

Each agent should own a single, well-defined domain or feature. An agent that tries to cover multiple concerns becomes a generalist that adds little value over the base model.

- **Good**: `mobile-android-push-notifications-expert` — owns one feature completely
- **Bad**: `mobile-android-expert` — too broad to provide meaningful expertise

If you find yourself listing more than two unrelated areas in the Identity section, split into multiple agents.

### 2. Write the Identity section as a clear mandate

The Identity section should answer three questions in this order:
1. What domain or feature does this agent own?
2. What is its role (expert, reviewer, guardian, generator)?
3. What authority does it have (advisory, blocking, autonomous)?

Avoid aspirational language. State what the agent does, not what it aspires to be.

### 3. Design Knowledge as expertise plus pointers, not expertise plus data

The Knowledge section is where most agents fail. Follow the "thin agent, thick context" principle:

**Include:**
- Pointers to authoritative sources: glob patterns (`src/feature/**/*.ts`), directory paths, doc URLs, ticket project keys
- Non-obvious expertise: trade-offs, gotchas, constraints not visible in code
- Conventions and patterns that a newcomer would miss
- Integration boundaries: what other systems or features this domain touches

**Do not include:**
- Inline summaries of code, class hierarchies, or function signatures
- Static ticket summaries or sprint histories
- Architectural details that are visible by reading the source files

**Why:** Static knowledge snapshots go stale as the codebase evolves. Pointers to where the data lives remain accurate. An agent that reads current state at runtime is always correct; one with embedded summaries gives false confidence after the first code change.

### 4. Use dynamic context sources

Every Knowledge section should include a "Context Sources" subsection listing where the agent should look at runtime:

```markdown
### Context Sources
- Code: `src/feature-name/**/*.ts`, `src/shared/feature-name-*`
- Tests: `tests/feature-name/`
- Docs: `docs/feature-name/` or external doc URL
- Tickets: Project key `FEAT`, epic `FEAT-100`
```

These are the agent's "refresh points" — it reads them before answering to ensure its responses reflect the current codebase.

### 5. Include runtime verification in Instructions

The Instructions section must include behaviors that keep the agent honest at runtime:

1. **Read before answering** — Always read Context Sources before responding to any question
2. **Flag divergence** — If the code contradicts the Knowledge section, say so explicitly
3. **Request missing context** — If a question falls outside loaded knowledge, ask for what is needed before guessing
4. **Guard scope boundaries** — Flag when proposed changes cross into another agent's domain

An agent without runtime verification is just a static document with extra formatting.

### 6. Define consistent output format

The Output Format section should specify response structure by request type. Common patterns:

- **Implementation requests**: approach, affected files, key decisions, risks
- **Review requests**: pattern consistency check, scope violations, suggested improvements
- **Questions**: direct answer with file/ticket references as evidence

Consistency in output format makes agents predictable and trustworthy. Users learn what to expect.

### 7. Choose the right model

Use the `model` frontmatter field intentionally:

| Model | Use when | Example agents |
|-------|----------|---------------|
| `haiku` | Fast, low-complexity tasks — formatting, simple lookups, routing | Triage agents, format checkers |
| `sonnet` | Balanced tasks — code review, implementation guidance, feature work | Feature experts, reviewers (default) |
| `opus` | Deep reasoning — architecture decisions, complex debugging, cross-system analysis | Architecture agents, root-cause analyzers |

Omitting `model` defaults to the parent model, which is correct for most agents. Only override when you have a clear reason.

### 8. Scope tools deliberately

If an agent has access to tools, only provision the ones it actually needs. An agent with access to every tool is an agent that can cause unexpected side effects.

- A reviewer agent needs read-only file access, not write access
- A ticket-aware agent needs search and read, not create and update (unless that is its explicit purpose)

State tool expectations in the Constraints section so consumers know what the agent requires.

### 9. Write the Known Constraints and Gotchas subsection first

This is the highest-value content in any agent. It captures what a new developer would get wrong — the things that are not obvious from reading the code.

Examples of high-value gotchas:
- "This service has a 5-second timeout that is not configurable — design accordingly"
- "The payload format changed in v3 but the legacy endpoint still accepts v2 — always check which version the caller expects"
- "Tests in this module require a running local database — they are not pure unit tests"

If you cannot identify at least two non-obvious constraints, the agent may not have enough domain expertise to justify its existence.

### 10. Add staleness tracking

Include `last_reviewed: YYYY-MM-DD` in the agent's frontmatter. This enables consumers to know when the agent's knowledge was last verified against the codebase.

An agent that has not been reviewed in 90 days should be treated as potentially stale. The `generic-skill-tester` agent can be used to validate agents periodically.

### 11. Plan for testing and refinement

A new agent should go through at least one testing cycle before being considered reliable:

1. Create the agent with the best available knowledge
2. Run it against 2-3 realistic prompts that a user would actually ask
3. Identify gaps — questions it cannot answer, incorrect assumptions, missing context sources
4. Update the Knowledge and Instructions sections based on findings
5. Repeat until the agent handles common scenarios without hallucinating

Use the `generic-skill-tester` skill to automate this process when possible.

## Constraints

- This skill provides guidance only — it does not create or modify agent files directly
- Do not duplicate content from `generic-agent-creator-structure` — that skill covers format and naming; this skill covers quality and design
- All examples must remain generic and project-agnostic per the repository's generic-only policy
- Do not recommend embedding static data in Knowledge sections — always prefer pointers to sources
- Do not suggest model selection without explaining the reasoning — model choice has cost and latency implications
