# Feature Expert Guide

When to use a Skill, an Agent, or a Document to make Claude an expert on a feature you built.

---

## The Question

You've built a feature. You want Claude to deeply understand it — its architecture, decisions, edge cases, product intent — so that any time you work on it, Claude can describe it, guide implementation, review code for it, or answer questions about it.

What's the right container for that knowledge?

---

## The Three Options

### Option 1: Skill

A skill defines **what to do** — a repeatable workflow with steps. It tells Claude *how to behave* when a task matches.

```
Good for: "Every time I ask you to write release notes for this feature, do it this way"
Not for:  Storing knowledge about what the feature actually is
```

A skill carries **no memory of the feature itself**. It just encodes a procedure. If you put feature knowledge inside a skill, it only activates when that specific skill is invoked.

**Verdict**: Use a skill when you have a *repeatable task* tied to a feature, not when you need an *expert* on it.

---

### Option 2: CLAUDE.md (Always-loaded context)

`CLAUDE.md` is loaded into every conversation automatically. Any knowledge you put there is always present.

```
Good for: Core architecture that affects every conversation
Not for:  Deep feature-specific knowledge — it bloats every session,
          even when the feature is irrelevant
```

If you have 10 features and each needs 500 words of context, putting all of them in `CLAUDE.md` means 5,000 words of context loaded for every conversation about anything — including unrelated work.

**Verdict**: Use `CLAUDE.md` for project-wide fundamentals. Use it sparingly for feature knowledge, only if the feature is central to everything.

---

### Option 3: Agent ✓ Recommended

An agent defines **who to be and what to know**. A custom agent file (`.claude/agents/<name>.md`) gives Claude a persona, domain knowledge, behavioral instructions, and optionally a restricted set of tools — all activated on demand.

```
Good for: A dedicated expert you invoke when working on that feature
Not for:  Automated pipelines (use skills for that)
```

An agent for a feature can carry:
- What the feature does and why it exists
- Architectural decisions and their rationale
- Key files, entry points, and data flows
- Edge cases and known limitations
- How to describe it to different audiences (product, engineering, QA)
- What to watch for when reviewing code changes to it

The agent only loads when invoked, so it adds zero overhead to unrelated sessions.

**Verdict**: For "an expert on a feature", create an agent.

---

## The Mental Model

```
CLAUDE.md    →  What Claude always knows          (always loaded, project-wide)
Rules        →  How Claude always behaves         (always enforced)
Skill        →  What Claude does on a task        (on demand, procedural)
Agent        →  Who Claude becomes for a domain   (on demand, expert persona)
```

Think of it this way:
- A **skill** is a recipe — it tells Claude the steps to follow
- An **agent** is a specialist — it tells Claude who to be and what it already knows

---

## How to Build a Feature Agent

Create a file at:
```
.claude/agents/<feature-name>.md
```

Or in the plugin's agents folder for sharing across projects:
```
agents/<feature-name>.md
```

### Agent File Structure

```markdown
---
name: <feature-name>
description: <one-line — Claude uses this to decide when to invoke automatically>
---

# <Feature Name> Expert

## Identity
You are the resident expert on <feature name>. You know its full history,
architecture, decisions, edge cases, and product intent.

## What This Feature Is
<2–4 paragraphs: what it does, who uses it, why it was built, what problem it solves>

## Architecture
<Key components, data flow, entry points, major files/modules>

## Key Decisions
<The "why" behind non-obvious choices — what was tried, what was rejected, why>

## Edge Cases & Known Limitations
<What breaks, what's deferred, what needs care>

## How to Talk About It
<Product framing vs engineering framing. What matters to each audience.>

## When Reviewing Code Changes
<What to check for. Anti-patterns. Invariants that must be preserved.>
```

---

## Combining Both

The most powerful pattern is **Agent + Skill**:

```
Agent  →  knows the feature deeply (the expert)
Skill  →  knows how to perform tasks on it (the workflow)
```

Example for a "Location Cache" feature:

```
agents/location-cache.md         → expert on what location cache is and why
skills/mobile-android-location-cache-review/SKILL.md  → how to review a PR touching it
```

When you open a PR touching the cache, the skill guides the review procedure. The agent provides the domain knowledge to make that review meaningful.

---

## Decision Tree

```
Do you need Claude to follow a repeatable procedure?
  └─ Yes → Skill

Do you need a piece of context to always be present?
  └─ Yes → CLAUDE.md

Do you need Claude to deeply understand a domain and be an expert on demand?
  └─ Yes → Agent

Do you need both expertise AND a repeatable task?
  └─ Yes → Agent + Skill (they compose naturally)
```

---

## Summary

| | Skill | CLAUDE.md | Agent |
|---|---|---|---|
| **Contains** | Workflow steps | Always-on context | Persona + domain knowledge |
| **Loaded** | On demand | Every session | On demand |
| **Best for** | Repeatable tasks | Project-wide fundamentals | Feature expertise |
| **Overhead** | Zero when idle | Always present | Zero when idle |
| **Invoke with** | `/skill-name` | Automatic | Automatic or `@agent-name` |

For feature expertise: **create an agent**.
