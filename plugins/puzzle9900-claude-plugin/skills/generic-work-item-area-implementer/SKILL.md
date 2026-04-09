---
name: generic-work-item-area-implementer
description: Implements a single area from the Technical Scope, building on top of foundation artifacts. Reads and applies a local feature expert file if one exists. Writes only production code — no tests. Produces a structured implementation report.
---

# generic-work-item-area-implementer

## Overview

Fully implements one area from the Technical Scope. Builds on top of the Foundation Manifest produced by `generic-work-item-foundation-builder`. Reads and applies a local feature expert file when one exists — extracting its code paths, patterns, and constraints directly into this session rather than launching it as a sub-agent. Writes only production code; never creates test files.

This skill is always invoked serially by `generic-work-item-implementation-start` — one area at a time, never in parallel with another area.

## When to Use

- Invoked by `generic-work-item-implementation-start` for each area in the Implementation Queue
- Invoked in fix mode by the same master skill when a code review returns issues for a specific area
- Can be run standalone: "Implement the [area name] area using this Technical Scope and Foundation Manifest"

## Steps

### Step 0: Read the expert file (if provided)

Before reading the codebase:

**If a `Feature expert file path` was provided (not `"none"`):**
1. Read the file at that path
2. Extract from it: code paths, architectural patterns, known conventions, constraints, integration points
3. Use this as the authoritative source for how this area works — it overrides any general convention inferred from the codebase later
4. Record which guidance came from the expert file, for the implementation report

**If `"none"`:**
- Proceed directly to Step 1

### Step 1: Read existing code in this area

1. Glob the module path from the area scope to enumerate all files in this area
2. Read the key interface, boundary, and model files for this area
3. Read any files identified as "likely touched" in the Implementation Queue
4. Do not read files outside this area's module path — except foundation artifacts and their direct dependencies
5. Build a clear picture of: what exists, what patterns are used, what the public entry points are

### Step 2: Plan the implementation

Before writing any code, produce an internal plan (not shown to the user):
- Which files will be created (new)?
- Which files will be modified (existing)?
- In what order should changes be made to avoid breaking intermediate states?
- Which foundation artifacts from the Foundation Manifest are used and how?
- Are there checklist items in the Area Impact Block that require special handling?

### Step 3: Implement

Execute the plan. For each file change:

**Creating new files:**
- Follow naming, packaging, and structural conventions observed in Step 1 or from the expert file
- Implement the full capability described in the area's "Needs" section
- Reference foundation artifacts by their actual paths from the Foundation Manifest
- Write clean, idiomatic production code — no TODOs, no placeholder implementations, no stub returns unless the interface explicitly requires it

**Modifying existing files:**
- Use Edit to make targeted, minimal changes
- Do not touch code outside the scope of this area's implementation
- Do not reformat, rename, or refactor anything not explicitly required by the Technical Scope
- Preserve all existing behavior — only add, not remove

**Cross-cutting concerns (if applicable to this area):**
- Analytics events: instrument following the pattern observed in existing analytics calls
- Auth/permissions: apply the same guard pattern observed elsewhere in the codebase
- Error states: define and propagate consistently with existing error handling patterns

### Step 4: Produce implementation report

After all files are written, output:

```
## Implementation Report: <Area Name>

### Files Created
- <file path>: <one-line description of what it implements>

### Files Modified
- <file path>: <what was changed and why>

### Checklist Coverage
- [x] <checklist item from area scope> — implemented in <file>
- [ ] <checklist item> — not implemented: <reason>

### Foundation Artifacts Used
- <ContractName> from <file path>

### Expert File Used
- <path, or "none">
- Key guidance applied: <one-line summary, or "n/a">

### Deferred Items
- <anything from the area scope not implemented, and why>

### Notes for Code Reviewer
- <any non-obvious implementation decision worth flagging>
```

## Constraints

- Do not end your response turn between steps — execute all steps (read expert file → read code → implement → produce report) in sequence without stopping
- All file reads and writes must be rooted at the worktree path passed in the invocation — never write to the main repo root or any path outside the worktree
- Implement only this area — do not touch files belonging to other areas in the Implementation Queue
- Never create test files — this workflow does not produce tests
- Never implement code outside the scope defined by the area's checklist items and "Needs" section
- Never remove or rename existing public interfaces or types — only add
- If a foundation artifact is missing from the Foundation Manifest, stop and report the gap — do not create it inline
- If the expert file's guidance conflicts with the Technical Scope, surface the conflict explicitly before proceeding
- Do not mark a checklist item as complete unless it is fully implemented — partial implementations must be flagged as deferred
- All produced code must be production-quality: no debug logs, no commented-out code, no hardcoded values that belong in configuration
