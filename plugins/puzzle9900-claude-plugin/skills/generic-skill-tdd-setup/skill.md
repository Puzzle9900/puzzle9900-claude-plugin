---
name: generic-skill-tdd-setup
description: Set up TDD infrastructure for a Claude skills project — creates a tdd/ folder at the repo root, generates a test.md scaffold for each skill found in .claude/skills/, installs required dependencies (tmux, jq), and ensures tdd/ and .claude-sessions/ are gitignored. Suggest this when a user wants to write or run tests for their Claude skills, or when starting a new skills project that needs a test harness.
type: generic
tools: [Read, Write, Edit, Bash, Glob]
---

# generic-skill-tdd-setup

## Context

This skill bootstraps a TDD harness for any Claude Code project that contains skills in `.claude/skills/`. Once set up:

- A `tdd/` folder at the repo root holds one `test.md` per skill
- Each `test.md` follows a standard scenario/evaluation template
- Required CLI tools are verified and installed
- Shell tool scripts in `.claude/tools/` are made executable
- `tdd/` and `.claude-sessions/` are excluded from version control

Run this skill once per project. Re-runs are safe — existing `test.md` files are never overwritten.

## Instructions

You are a Claude Code setup assistant. Your job is to scaffold TDD infrastructure for a skills-based Claude project, then report exactly which files were created and which were skipped.

## Steps

### 1. Locate the repo root and skills folder

Run:
```bash
git rev-parse --show-toplevel
```

Store the result as `REPO_ROOT`. If this fails (not a git repo), stop and tell the user: "This skill requires a git repository. Run `git init` first."

Set `SKILLS_DIR="$REPO_ROOT/.claude/skills"`.

Check whether `SKILLS_DIR` exists:
```bash
ls "$REPO_ROOT/.claude/skills"
```

If the directory does not exist or is empty, stop and tell the user: "No skills found in `.claude/skills/`. Create at least one skill folder there before running this setup."

### 2. Check and install dependencies

Check for `tmux`:
```bash
which tmux
```

If missing, install via Homebrew on macOS:
```bash
brew install tmux
```

If `brew` is not available either, warn the user:
> `tmux` is required but could not be installed automatically. Install it manually (`brew install tmux` on macOS, `apt install tmux` on Linux), then re-run this skill.

Check for `jq`:
```bash
which jq
```

If missing, install via Homebrew on macOS:
```bash
brew install jq
```

If `brew` is not available either, warn the user:
> `jq` is required but could not be installed automatically. Install it manually (`brew install jq` on macOS, `apt install jq` on Linux), then re-run this skill.

Stop if either dependency could not be satisfied.

### 3. Make tool scripts executable

If `.claude/tools/` exists and contains `.sh` files, make them all executable:
```bash
chmod +x "$REPO_ROOT/.claude/tools/"*.sh
```

If the folder does not exist, skip this step silently.

### 4. Ensure tdd/ and .claude-sessions/ are gitignored

Check the root `.gitignore`:
```bash
cat "$REPO_ROOT/.gitignore"
```

If `tdd/` is not already present in `.gitignore`, append:
```
# TDD test artifacts — local only
tdd/
```

If `.claude-sessions/` is not already present in `.gitignore`, append:
```
# Claude session state — local only
.claude-sessions/
```

If no `.gitignore` exists at the root, create one with both entries.

### 5. Create tdd/ folder

Create the directory if it does not exist:
```bash
mkdir -p "$REPO_ROOT/tdd"
```

### 6. Discover skills and generate test.md files

List every immediate subdirectory of `.claude/skills/` — each one is a skill name.

For each skill name:

1. Check whether `$REPO_ROOT/tdd/<skill-name>/test.md` already exists.
   - If it does: add the skill to the **skipped** list. Do not modify the file.
   - If it does not: create `$REPO_ROOT/tdd/<skill-name>/` and write the following `test.md`, substituting `<skill-name>` with the actual skill folder name:

```markdown
# TDD: <skill-name>

## Setup
```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
TOOLS="$REPO_ROOT/.claude/tools"
```
<!-- Add bash commands to seed state before running tests -->

## Teardown
```bash
# Add cleanup commands here
```

---

## Scenario 1: <describe the happy path>

**Given:** <!-- initial state -->

**When:** Invoke `<skill-name>` with:
- `param1: value`

**Then:**
- <!-- expected observable outcome -->

### Acceptance Criteria
- [ ] <!-- binary, verifiable criterion -->

### Evaluation
```bash
# bash commands to verify criteria
```
```

Add the skill to the **created** list.

### 7. Report results

Print a structured summary:

```
TDD Setup Complete
─────────────────────────────────────────
Repo:    <REPO_ROOT>
Skills:  <total count>

Created test.md:
  ✓ <skill-name>
  ✓ <skill-name>
  ...

Skipped (already exist):
  – <skill-name>
  ...
─────────────────────────────────────────
Next: edit tdd/<skill-name>/test.md to fill in scenarios, then run /generic-skill-tdd-runner skill:<skill-name>
```

If all skills were skipped (all test.md files already existed), report:
> All test.md files already exist — nothing to create. Run `/generic-skill-tdd-runner` to execute tests.

## Constraints

- Never overwrite an existing `tdd/<skill-name>/test.md`
- Only discover immediate subdirectories of `.claude/skills/` — do not recurse deeper
- Do not modify any file inside `.claude/skills/` — this skill is read-only with respect to skill source files
- The generated `test.md` is a scaffold only — it must not be executed by this skill
- All filesystem operations are idempotent: re-running this skill must produce the same end state with no destructive side effects
- This skill is fully generic — no references to specific projects, repos, app names, or organization conventions
