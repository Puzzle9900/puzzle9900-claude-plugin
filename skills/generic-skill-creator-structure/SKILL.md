---
name: generic-skill-creator-structure
description: Reference for skill file structure, naming conventions, and folder placement. Use this whenever creating or validating a skill file.
type: generic
---

# generic-skill-creator-structure

## Context
This skill defines the canonical structure all skill files must follow. Use it as the authoritative reference when creating, reviewing, or updating any skill in this project.

## Skill File Structure

Every skill is a **folder** named after the skill, containing a single `SKILL.md` file:

```
skills/
  <full-composite-name>/
    SKILL.md
```

The `SKILL.md` file has a YAML frontmatter block followed by content sections:

### Frontmatter

```yaml
---
name: <full-composite-name>
description: <one-line description — Claude uses this to decide when to auto-invoke>
type: <domain>
platform: <platform>          # omit this line entirely for generic domain
disable-model-invocation: true  # omit unless skill must only be user-invoked
---
```

### Content Sections

```markdown
# <full-composite-name>

## Context
<Why this skill exists and when to use it.>

## Instructions
<What Claude should do when this skill is invoked.>

## Steps
<Numbered list of steps.>

## Constraints
<Bulleted list of boundaries and things to avoid.>
```

---

## Naming Convention

The full skill name is a composite of domain, platform (if applicable), and name:

| Domain | Platform | Full name pattern | Example |
|--------|----------|-------------------|---------|
| `generic` | — | `generic-<name>` | `generic-spec` |
| `mobile` | `ios` / `android` / `web` | `mobile-<platform>-<name>` | `mobile-android-auth-flow` |
| `backend` | `services` / `infrastructure` / `database` | `backend-<platform>-<name>` | `backend-services-waonder-reviewer` |

- Always **kebab-case** for the name portion
- The folder name and the `name` field in frontmatter must always match exactly

---

## Folder Structure

```
skills/
  generic-<name>/
    SKILL.md
  mobile-ios-<name>/
    SKILL.md
  mobile-android-<name>/
    SKILL.md
  mobile-web-<name>/
    SKILL.md
  backend-services-<name>/
    SKILL.md
  backend-infrastructure-<name>/
    SKILL.md
  backend-database-<name>/
    SKILL.md
```

Each skill is a flat folder at the root of `skills/` — no domain or platform subfolders.

---

## Constraints
- Each skill lives in its own folder: `skills/<name>/SKILL.md`
- The folder name and the `name` frontmatter field must match exactly
- Never nest skill folders inside domain or platform subfolders
- The `description` must be specific enough for Claude to decide auto-invocation — avoid vague descriptions
- All four content sections (Context, Instructions, Steps, Constraints) must be present and populated
- `platform` must be omitted entirely (not left blank) for `generic` domain skills
- Add `disable-model-invocation: true` only when the skill must be explicitly user-invoked
