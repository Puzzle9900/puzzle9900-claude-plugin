---
name: generic-skill-structure
description: Reference for skill file structure, naming conventions, and folder placement. Use this whenever creating or validating a skill file.
type: generic
---

# generic-skill-structure

## Context
This skill defines the canonical structure all skill files must follow. Use it as the authoritative reference when creating, reviewing, or updating any skill in this project.

## Skill File Structure

Every skill file is a Markdown file with a YAML frontmatter block followed by content sections.

### Frontmatter

```yaml
---
name: <full-composite-name>
description: <one-line description — Claude uses this to decide when to auto-invoke>
type: <domain>
platform: <platform>          # omit this line entirely for generic domain
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
- The filename must match the `name` field in frontmatter exactly (plus `.md`)

---

## Folder Structure

```
skills/
├── generic/
│   └── generic-<name>.md
├── mobile/
│   ├── ios/
│   │   └── mobile-ios-<name>.md
│   ├── android/
│   │   └── mobile-android-<name>.md
│   └── web/
│       └── mobile-web-<name>.md
└── backend/
    ├── services/
    │   └── backend-services-<name>.md
    ├── infrastructure/
    │   └── backend-infrastructure-<name>.md
    └── database/
        └── backend-database-<name>.md
```

---

## Constraints
- The `name` in frontmatter and the filename (without `.md`) must always match
- The `description` must be specific enough for Claude to decide auto-invocation — avoid vague descriptions like "helps with tasks"
- All four content sections (Context, Instructions, Steps, Constraints) must be present and populated — never leave placeholders
- `platform` must be omitted entirely (not left blank) for `generic` domain skills
