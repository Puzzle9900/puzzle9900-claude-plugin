---
name: generic-help
description: List all available skills organized by domain and platform
type: generic
disable-model-invocation: true
---

# generic-help

## Context
This skill provides a quick reference of all available skills in this project. Use it to discover what skills exist and how to invoke them.

## Instructions

When invoked, scan the `.claude/skills/` directory and list all available skills organized by domain and platform.

## Steps

1. Scan `.claude/skills/` for all `.md` files recursively using Glob.
2. Read the frontmatter of each file to extract `name`, `description`, `type`, and `platform`.
3. Group skills by domain (type), then by platform within each domain.
4. Display them in a formatted table with these columns:

| Domain | Platform | Skill | Description |
|--------|----------|-------|-------------|
| `<type>` | `<platform>` or — | `/<name>` | `<description>` |

This table must be generated dynamically every time — never use a cached or hardcoded list.

## Constraints
- Always scan the actual directory — do not hardcode the list.
- Group by domain first, then platform.
- Show skills without a platform under "—" in the platform column.
