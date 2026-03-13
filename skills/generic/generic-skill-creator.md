---
name: generic-skill-creator
description: Creates new skills following the project's naming conventions and folder structure. Use this whenever the user asks to create, add, or define a new skill.
type: generic
---

# generic-skill-creator

## Context
This skill is the standard way to create new skills in this project. It enforces the naming convention, folder structure, and template format that all skills must follow.

## Instructions

When creating a new skill, you MUST gather the following information through clarifying questions before generating the file. Do not assume values — ask the user.

### Required Information

1. **Domain** (required): Which domain does this skill belong to?
   - `mobile` — platforms: `ios`, `android`, `web`
   - `backend` — platforms: `services`, `infrastructure`, `database`
   - `generic` — no platform

2. **Platform** (required for `mobile` and `backend`, omitted for `generic`):
   - If domain is `mobile`: ask if `ios`, `android`, or `web`
   - If domain is `backend`: ask if `services`, `infrastructure`, or `database`
   - If domain is `generic`: skip this question

3. **Name** (required): A short, descriptive kebab-case name for the skill (e.g., `auth-flow`, `skill-creator`, `deploy-check`)

4. **Description** (required): A one-line description of what the skill does. This is critical — Claude uses it to decide when to auto-invoke the skill.

5. **Purpose and behavior** (required): Ask the user to explain:
   - What should this skill do?
   - When should it be used?
   - What steps should it follow?
   - Are there any constraints or things to avoid?

### Naming Convention

The full skill name is a composite of domain, platform (if applicable), and name:
- With platform: `<domain>-<platform>-<name>`
- Without platform: `<domain>-<name>`

### Folder Structure

Place the generated file at:
- With platform: `.claude/skills/<domain>/<platform>/<domain>-<platform>-<name>.md`
- Without platform: `.claude/skills/<domain>/<domain>-<name>.md`

### File Template

Generate the skill file with this structure:

```yaml
---
name: <full-composite-name>
description: <one-line description>
type: <domain>
platform: <platform>          # omit this line entirely for generic domain
---

# <full-composite-name>

## Context
<Why this skill exists and when to use it. Populate based on the user's explanation.>

## Instructions
<What Claude should do when this skill is invoked. Populate based on the user's explanation.>

## Steps
<Numbered list of steps. Populate based on the user's explanation.>

## Constraints
<Bulleted list of things to avoid or boundaries. Populate based on the user's explanation.>
```

## Steps

1. Detect that the user wants to create a new skill.
2. Ask clarifying questions to gather: domain, platform, name, description, purpose/behavior.
3. Confirm the full skill name and file path with the user before creating.
4. Create the necessary directories if they don't exist.
5. Generate the skill file with all sections populated based on the conversation.
6. Show the user the created file path and a summary.

## Constraints
- Never guess the domain, platform, or name — always ask.
- Never skip the clarifying questions even if the user provides partial info upfront. Confirm what you have and ask for what's missing.
- Always use kebab-case for the name portion.
- Always populate the body sections (Context, Instructions, Steps, Constraints) from the conversation — never leave them as placeholders.
- If the user asks to create a skill and this skill exists, always use it. Do not create skills any other way.
