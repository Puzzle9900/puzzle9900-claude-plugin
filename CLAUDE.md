# Project Rules

## Never use
- The `ai` wrapper (`ai.sh`)
- The `/reload` command
- The `/setup-ai` skill

These are custom implementations used for something else and must not be suggested or invoked in this project.

## Generic-only policy

All skills and agents in this repo must be **fully generic and project-agnostic**:

- No references to specific projects, repositories, app names, team names, or organization-specific conventions
- No hardcoded file paths, endpoints, or identifiers tied to a particular codebase
- Examples and placeholders must use generic names (e.g., `my-app`, `your-service`), never real project names
- Project-specific context belongs in each consuming project's own `CLAUDE.md`, not in this plugin

If a skill or agent cannot be copied to any other project without modification, it does not belong here.
