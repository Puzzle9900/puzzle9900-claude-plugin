---
name: generic-skill-tester
description: Iteratively tests, verifies, and improves a skill definition through 3 execution cycles, then documents all improvements inside the skill folder.
type: generic
---

## Context

This skill activates the `generic-skill-tester` agent to validate and improve any skill in the plugin. It is useful when a skill is newly created, recently modified, or suspected to produce inconsistent results. The agent executes the skill, compares outcomes against the skill definition, and improves the definition over three iterations, leaving a documented improvement trail.

## Instructions

When invoked, ask the user for the target skill name or path if not already provided. Then delegate all work to the `generic-skill-tester` agent, passing the resolved skill path as input.

If the user invokes this skill as `/generic-skill-tester <skill-name>`, resolve the path automatically to `skills/<skill-name>/SKILL.md` and proceed without asking.

## Steps

1. **Resolve skill path** — Determine the full path to the target `SKILL.md`. Accept either a full path or a short name (e.g., `generic-spec` → `skills/generic-spec/SKILL.md`). If not provided, ask the user.

2. **Delegate to agent** — Invoke the `generic-skill-tester` agent with the resolved skill path. The agent owns all subsequent execution. **Important:** The agent must run its 3 iterations sequentially (one after the other), never in parallel. Each iteration depends on the output and improvements from the previous one.

3. **Report outcome** — Once the agent completes, summarize:
   - The 3 iterations and what changed in each
   - The final state of the skill
   - The path to the improvements document created inside the skill folder

## Constraints

- Do not modify any skill file directly from this skill — all edits are delegated to the agent.
- Do not skip the agent invocation and attempt to inline the testing logic here.
- If the skill path does not exist, report the error clearly and stop.
