# Skills Guide

How skills work in the Waonder Claude Plugin, how they're organized, and how to reuse them across projects.

---

## What Is a Skill?

A skill is a markdown file that gives Claude a reusable workflow or domain-specific knowledge. When Claude detects a task matching a skill's description, it follows the skill's instructions. You can also invoke skills explicitly with `/skill-name`.

Skills are **not code** — they're structured instructions that Claude reads and follows.

---

## Naming Convention

Every skill follows this naming pattern:

```
<domain>-<platform>-<name>
```

- **Domain** (required): `mobile`, `backend`, or `generic`
- **Platform** (optional, depends on domain): see table below
- **Name** (required): kebab-case descriptor

| Domain | Platforms | Example |
|--------|-----------|---------|
| `mobile` | `ios`, `android`, `web` | `mobile-ios-navigation` |
| `backend` | `services`, `infrastructure`, `database` | `backend-services-auth` |
| `generic` | none | `generic-skill-creator` |

---

## Folder Structure

Skills are organized by domain and platform as folders. The file itself carries the full composite name:

```
skills/
├── mobile/
│   ├── ios/
│   │   └── mobile-ios-<name>.md
│   ├── android/
│   │   └── mobile-android-<name>.md
│   └── web/
│       └── mobile-web-<name>.md
├── backend/
│   ├── services/
│   │   └── backend-services-<name>.md
│   ├── infrastructure/
│   │   └── backend-infrastructure-<name>.md
│   └── database/
│       └── backend-database-<name>.md
├── generic/
│   └── generic-<name>.md
```

No extra wrapper folder per skill — the `.md` file IS the skill.

---

## Skill File Template

Every skill follows this structure:

```yaml
---
name: <domain>-<platform>-<name>
description: <one-line description — Claude uses this to decide when to auto-invoke>
type: <domain>
platform: <platform>          # omit for generic
---

# <domain>-<platform>-<name>

## Context
Why this skill exists and when to use it.

## Instructions
What Claude should do when this skill is invoked.

## Steps
1. First step
2. Second step
3. ...

## Constraints
- What to avoid
- Boundaries and limitations
```

### Frontmatter Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | Yes | Full composite name, becomes the `/command` |
| `description` | Yes | Claude reads this to decide when to auto-invoke |
| `type` | Yes | Domain — helps Claude scope the skill to relevant work |
| `platform` | For mobile/backend | Further scoping for Claude's context matching |
| `disable-model-invocation` | No | If `true`, only the user can invoke with `/name` |

### Body Sections

| Section | Purpose |
|---------|---------|
| **Context** | Why the skill exists, when it's relevant |
| **Instructions** | What Claude should do — the core behavior |
| **Steps** | Ordered sequence of actions |
| **Constraints** | Guardrails — what NOT to do |

---

## Creating New Skills

Use the built-in skill creator:

```
/generic-skill-creator
```

Or just tell Claude "create a new skill for X" — it will automatically use the skill creator, which asks clarifying questions before generating the file.

The skill creator enforces the naming convention, folder structure, and template format.

---

## Reusing Skills Across Projects with Symlinks

The plugin's `skills/` folder can be shared across multiple projects using symbolic links. This means you maintain skills in ONE place (this plugin) and every project gets them.

### Strategy 1: Link the Entire Skills Folder

```bash
# In any project, link to the plugin's skills
cd ~/Documents/WaonderApps/my-project
mkdir -p .claude
ln -s ~/Documents/WaonderApps/waonder-claude-pluggin/skills .claude/skills
```

Now `my-project/.claude/skills/` points to the plugin. All skills are available.

### Strategy 2: Link Individual Domains

If a project only needs certain domains:

```bash
cd ~/Documents/WaonderApps/my-project
mkdir -p .claude/skills

# Only link what this project needs
ln -s ~/Documents/WaonderApps/waonder-claude-pluggin/skills/generic .claude/skills/generic
ln -s ~/Documents/WaonderApps/waonder-claude-pluggin/skills/backend .claude/skills/backend
```

### Strategy 3: Link Specific Skills + Project-Specific Ones

```bash
cd ~/Documents/WaonderApps/my-project
mkdir -p .claude/skills/generic
mkdir -p .claude/skills/backend/services

# Shared from plugin
ln -s ~/Documents/WaonderApps/waonder-claude-pluggin/skills/generic/generic-skill-creator.md \
      .claude/skills/generic/generic-skill-creator.md

# Project-specific (not linked)
# Create directly in .claude/skills/backend/services/backend-services-my-api.md
```

### Strategy 4: User-Level Skills (All Projects, No Links)

For skills that should be available in EVERY project on your machine:

```bash
# Copy or link to user-level directory
mkdir -p ~/.claude/skills/generic
cp ~/Documents/WaonderApps/waonder-claude-pluggin/skills/generic/generic-skill-creator.md \
   ~/.claude/skills/generic/

# Or symlink
ln -s ~/Documents/WaonderApps/waonder-claude-pluggin/skills/generic \
      ~/.claude/skills/generic
```

User-level skills (`~/.claude/skills/`) are automatically available in every project without any per-project configuration.

### Which Strategy to Use

| Scenario | Strategy |
|----------|----------|
| All Waonder projects share all skills | Strategy 1: Link entire folder |
| Project only needs some domains | Strategy 2: Link by domain |
| Mix of shared + project-specific | Strategy 3: Link individual files |
| Skills needed everywhere on machine | Strategy 4: User-level |

### Important Notes on Symlinks

- Symlinks are **not portable** — they break if the target moves
- Symlinks are **platform-dependent** — macOS/Linux only (Windows uses junctions)
- Git does **not follow symlinks** by default — linked skills won't be in the project's git history
- If you need git-tracked shared skills, use git submodules instead:

```bash
cd ~/Documents/WaonderApps/my-project
git submodule add ../waonder-claude-pluggin .claude/plugins/waonder
```

---

## Scope and Precedence

When the same skill name exists at multiple levels, this is the precedence:

```
Enterprise (/Library/Application Support/ClaudeCode/) → highest
User (~/.claude/skills/)                               → medium
Project (.claude/skills/)                              → standard
```

A project-level skill with the same name as a user-level skill will be overridden by the user-level one.

---

## Skills vs Rules vs CLAUDE.md

| | Skills | Rules | CLAUDE.md |
|---|---|---|---|
| **Location** | `.claude/skills/` | `.claude/rules/` | `./CLAUDE.md` |
| **Loaded** | On demand | Every session | Every session |
| **Purpose** | Workflows and actions | Persistent guidelines | Project context |
| **Invocation** | `/name` or auto-detected | Always active | Always active |
| **Example** | "Generate a spec" | "Always use 2-space indent" | "Build with npm run build" |

Use **CLAUDE.md** for context Claude always needs.
Use **Rules** for conventions Claude must always follow.
Use **Skills** for specific workflows Claude should execute on demand.

---

## Current Skills Inventory

| Skill | Domain | Platform | Description |
|-------|--------|----------|-------------|
| `generic-skill-creator` | generic | — | Creates new skills following naming conventions |
| `generic-spec` | generic | — | Creates project specifications and milestones |
| `generic-help` | generic | — | Lists all available skills |
| `backend-services-waonder-reviewer` | backend | services | Reviews code for Waonder best practices |
