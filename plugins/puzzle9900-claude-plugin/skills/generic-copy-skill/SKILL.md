---
name: generic-copy-skill
description: List all skills in a given plugin repository and copy selected ones (or all) into the current project's skills folder
type: generic
---

# generic-copy-skill

## Context
Use this skill when you want to import skills from another Claude Code plugin repository into the current project. It discovers all available skills in the source repository, presents the list, and copies the ones you select — or all of them at once.

## Instructions

You are a skill migration assistant. Your job is to:
1. Inspect a source plugin repository for skills
2. Present the full list to the user
3. Ask which skills to copy (individual selection or all)
4. Copy the chosen skills into the current project's `skills/` folder without overwriting existing ones unless the user confirms

## Steps

1. **Resolve the source repository path** — Ask the user for the path to the source plugin repository if it was not provided as an argument.

2. **Discover available skills** — List all folders under `<source-repo>/skills/` that contain a `SKILL.md` file. For each, extract the `name` and `description` from the frontmatter so the user can make an informed choice.

3. **Present the skill list** — Display the skills in a numbered table:

   ```
   #   Name                          Description
   ─── ───────────────────────────── ──────────────────────────────────────────
   1   generic-spec                  Create or update project specifications…
   2   generic-pr-merge              Create branch, open PR, wait for CI…
   …
   ```

4. **Ask the user what to copy** — Prompt:
   > Which skills would you like to copy? Enter numbers separated by commas, a range (e.g. 1-3), or **all** to copy everything.

5. **Resolve the selection** — Parse the user's input into a concrete list of skill folder names.

6. **Check for conflicts** — For each selected skill, check whether a folder with the same name already exists in the current project's `skills/` folder.
   - If conflicts exist, list them and ask: *Overwrite, skip, or cancel?*

7. **Copy the skills** — For each skill to copy:
   - Read `<source-repo>/skills/<skill-name>/SKILL.md`
   - Write it to `<current-project>/skills/<skill-name>/SKILL.md`
   - Preserve any additional files inside the skill folder (e.g. `IMPROVEMENTS.md`)

8. **Report results** — List every skill that was copied, skipped, or failed.

## Constraints
- Never modify the source repository
- Never overwrite an existing skill without explicit user confirmation
- Only copy folders that contain a valid `SKILL.md` with frontmatter
- Keep skill folder names unchanged — do not rename during copy
- If the source `skills/` folder does not exist or is empty, report it clearly and stop
