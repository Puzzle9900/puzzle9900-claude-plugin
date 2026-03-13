---
name: generic-spec-capture
description: Synthesize a project spec from existing information (code, docs, conversations, PRDs) and save it into projectspecs using the standard numbering convention
type: generic
disable-model-invocation: true
---

# generic-spec-capture

## Context
Use this skill when there is already existing information — code, product docs, conversation history, PRDs, design notes, or any other context — and the goal is to capture and preserve it as a structured specification inside `projectspecs/`. Nothing is invented or assumed. Everything written into the spec must be derived from the provided material. This is the single source of truth capture skill, not a planning skill.

## Instructions

You are a specification synthesizer. Your job is to read and understand existing information, extract the product and technical intelligence embedded in it, and write it into a structured spec document. Do not invent requirements, goals, or tasks that are not supported by the source material. If something is ambiguous in the source, note it explicitly in the spec rather than filling in the gap.

---

## Steps

1. **Identify the source material** — Confirm what information is being captured. It may be one or more of:
   - Files in the codebase (read them)
   - A conversation or description the user has provided inline
   - External documents or URLs the user has shared
   - A mix of the above

2. **Extract the intelligence** — From the source material, identify and separate:
   - **Product definition**: what the feature/system does, who it is for, why it exists
   - **Functional behavior**: what it does, how it behaves, edge cases mentioned
   - **Technical approach**: architecture, data flow, key implementation decisions, patterns used
   - **Constraints and non-goals**: what is explicitly out of scope or bounded
   - **Open questions or ambiguities**: anything unclear in the source that should be flagged

3. **Find the next milestone number** — Scan `projectspecs/` for folders matching `###_*`, find the highest number, increment by 1, zero-padded to 3 digits (001, 002, ... 010, ... 100)

4. **Derive the milestone name** — Use a short kebab-case name that reflects the feature or system being captured (e.g., `location-cache`, `auth-refresh-flow`, `trip-summary-widget`)

5. **Create the folder and spec file**:
   - Folder: `projectspecs/{number}_{kebab-case-name}/`
   - File: `projectspecs/{number}_{kebab-case-name}/spec.md`

6. **Write the spec** using this template, populated entirely from the source material:

```markdown
# {Feature or System Title}

**Milestone**: {number}_{name}
**Created**: {YYYY-MM-DD}
**Status**: Captured
**Source**: {Brief description of what was used as input — e.g., "Synthesized from codebase files and inline description"}

## Overview
{What this feature or system is, in 2–4 sentences. Derived from source.}

## Product Definition
{Who is this for and why does it exist? What problem does it solve?}

## Functional Behavior
{What does it do? How does it behave? Include edge cases if present in the source.}
- {Behavior 1}
- {Behavior 2}

## Technical Approach
{How is it built? Key architecture decisions, patterns, data flow, dependencies.}

## Constraints & Non-Goals
{What is explicitly out of scope or bounded by the source material.}
- {Constraint 1}

## Open Questions
{Anything ambiguous or unresolved in the source material that should be revisited.}
- {Question 1}

## References
{Files read, URLs, or documents used as input for this capture.}
- {Reference 1}
```

7. **Report** the created file path to the user and summarize what was captured in 2–3 sentences.

---

## Constraints
- Never invent information not present in the source material
- If the source is ambiguous, document the ambiguity in **Open Questions** rather than assuming
- Status must always be `Captured` — not `Draft`, since this is a synthesis, not a plan
- Use the same numbering sequence as `generic-spec` — they share the same `projectspecs/` folder
- Always populate **References** with the actual files or inputs used
- Do not ask the user clarifying questions unless the source material is insufficient to derive even a basic overview
