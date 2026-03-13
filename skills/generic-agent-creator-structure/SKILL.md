---
name: generic-agent-creator-structure
description: Reference for agent file structure, naming conventions, and file placement. Use this whenever creating or validating an agent file.
type: generic
---

# generic-agent-creator-structure

## Context
This skill defines the canonical structure all agent files must follow. Use it as the authoritative reference when creating, reviewing, or updating any agent in this project.

## Agent File Structure

Every agent is a **flat `.md` file** placed directly in `agents/` — no per-agent subfolders:

```
agents/
  <full-composite-name>.md
```

The agent file has a YAML frontmatter block followed by content sections:

### Frontmatter

```yaml
---
name: <full-composite-name>
description: <one-line description — Claude uses this to decide when to auto-invoke>
model: sonnet          # optional: sonnet | opus | haiku
color: blue            # optional: blue | green | yellow | red | purple | gray | orange
---
```

### Content Sections

```markdown
# <full-composite-name>

## Identity
<Who this agent is and what domain it owns>

## Knowledge
<What this agent knows — the feature, system, or domain expertise it carries>

## Instructions
<How this agent behaves and responds>

## Output Format
<How it structures its responses>

## Constraints
<What it avoids or never does>
```

---

## Naming Convention

The full agent name is a composite of domain, platform (if applicable), and concern:

| Domain | Platform | Full name pattern | Example |
|--------|----------|-------------------|---------|
| `generic` | — | `generic-<concern>` | `generic-spec-reviewer` |
| `mobile` | `ios` / `android` / `web` | `mobile-<platform>-<concern>` | `mobile-android-ui-expert` |
| `backend` | `services` / `infrastructure` / `database` | `backend-<platform>-<concern>` | `backend-services-auth-expert` |

- Always **kebab-case** for the concern portion
- The file name (without `.md`) and the `name` field in frontmatter must always match exactly

---

## Folder Structure

```
agents/
  generic-<concern>.md
  mobile-ios-<concern>.md
  mobile-android-<concern>.md
  mobile-web-<concern>.md
  backend-services-<concern>.md
  backend-infrastructure-<concern>.md
  backend-database-<concern>.md
```

Each agent is a flat file at the root of `agents/` — no domain or platform subfolders.

---

## Constraints
- Each agent lives as a flat file: `agents/<full-composite-name>.md`
- The file name (without `.md`) and the `name` frontmatter field must match exactly
- Never nest agent files inside domain or platform subfolders
- The `description` must be specific enough for Claude to decide auto-invocation — avoid vague descriptions
- All five content sections (Identity, Knowledge, Instructions, Output Format, Constraints) must be present and populated
- `model` and `color` are optional — omit entirely if defaults are acceptable
- Use `concern` (not `name`) as the final composite segment — it should describe what the agent does or knows
