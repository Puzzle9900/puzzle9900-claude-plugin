---
name: generic-skill-tdd-runner
description: Execute TDD test scenarios for a Claude skill — reads tdd/<skill>/test.md, runs Setup, seeds Given state, invokes the skill inline, evaluates Acceptance Criteria via bash, runs Teardown, and prints a structured pass/fail report. Suggest this when a user wants to run or verify tests for a skill, or after editing a test.md file.
type: generic
tools: [Read, Bash]
---

# generic-skill-tdd-runner

## Context

This skill executes structured TDD scenarios defined in `tdd/<skill>/test.md`. It is the execution counterpart to `generic-skill-tdd-setup`, which generates the scaffold.

For each scenario it:
1. Runs the shared Setup bash block
2. Seeds the Given state
3. Invokes the skill under test inline using the When inputs
4. Runs Evaluation bash to check each Acceptance Criterion
5. Marks each criterion PASS or FAIL based on exit code and output
6. Always runs Teardown — even if scenarios fail or the skill crashes
7. Prints a structured pass/fail report

## Inputs

- `skill` (optional): skill name matching a folder in both `tdd/` and `.claude/skills/`. If omitted, lists all available test suites.

## Instructions

You are a Claude Code test runner. Your job is to faithfully execute the test scenarios defined in `tdd/<skill>/test.md`, report results with precision, and always clean up — never leave the environment in a modified state after the run.

## Steps

### 1. If no skill provided, list available test suites

If `skill` was not provided:
```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
ls "$REPO_ROOT/tdd/"
```

For each folder that contains a `test.md`, count its scenarios and print:
```
Available TDD suites:
  <skill-name>    <N> scenarios    tdd/<skill-name>/test.md
  ...

Run: /generic-skill-tdd-runner <skill-name>
```
Then stop.

### 2. Validate inputs and locate files

Resolve the repo root:
```bash
git rev-parse --show-toplevel
```

Store as `REPO_ROOT`.

Locate the test file at `$REPO_ROOT/tdd/<skill>/test.md`. If it does not exist, stop with:
> Test file not found: `tdd/<skill>/test.md`
> Run `/generic-skill-tdd-setup` first to generate the scaffold, then fill in the scenarios.

Locate the skill source at `$REPO_ROOT/.claude/skills/<skill>/skill.md`. If it does not exist, stop with:
> Skill source not found: `.claude/skills/<skill>/skill.md`
> Check that the skill name is spelled correctly.

### 3. Parse the test file

Read `tdd/<skill>/test.md` and extract the following structure:

- **Setup block**: the fenced bash block directly under the `## Setup` heading
- **Teardown block**: the fenced bash block directly under the `## Teardown` heading
- **Scenarios**: each `## Scenario N: <name>` section, parsed into:
  - **Given**: any bash commands described or fenced under the `**Given:**` field
  - **When inputs**: the bullet list under `**When:** Invoke \`<skill>\` with:` — treat each bullet as a named parameter (`key: value`)
  - **Acceptance Criteria**: each `- [ ] <text>` line (unchecked checkboxes only)
  - **Evaluation bash**: the fenced bash block under `### Evaluation`


### 4. Run Setup

Execute the Setup bash block:
```bash
# Contents of the ## Setup block
```

If the Setup block is empty or contains only comments, skip silently.

If Setup fails (non-zero exit), stop with:
> Setup failed. Fix the Setup block in `tdd/<skill>/test.md` before running tests.

### 5. For each scenario (in order)

Handle each scenario independently. Failures in scenario N must not affect scenario N+1 — catch errors within each scenario boundary.

#### 4a. Run Given seed commands

Execute any bash commands in the Given field. If a seed command fails, mark all criteria for this scenario as FAIL with evidence:
> Given seed failed: `<command>` exited <code>

Proceed to the next scenario (do not run the skill for this scenario).

#### 4b. Invoke the skill under test

Load and execute the skill inline by reading `.claude/skills/<skill>/skill.md` and following its Instructions, using the When inputs as the parameters for that invocation.

If the skill crashes or throws an unhandled error:
- Capture the error output as evidence
- Mark all Acceptance Criteria for this scenario as FAIL with the error as evidence:
  > Skill crashed: `<error text>`
- Proceed to the next scenario (do not run Evaluation for this scenario)

#### 4c. Run Evaluation bash and check criteria

For each Acceptance Criterion in this scenario:

1. Run the Evaluation bash block (the same block is run once per scenario — its output is shared across criteria)
2. A criterion passes if the Evaluation bash exits 0 AND the output contains evidence consistent with the criterion text
3. A criterion fails if the bash exits non-zero OR the output contradicts or lacks evidence for the criterion

Capture:
- `exit_code`: exit code of the Evaluation bash block
- `output`: stdout + stderr of the Evaluation bash block

Map each criterion to PASS or FAIL based on the above rules. Record the actual output as evidence for any FAIL.

### 6. Run Teardown (always)

Execute the Teardown bash block regardless of scenario outcomes:
```bash
# Contents of the ## Teardown block
```

If Teardown is empty or contains only comments, skip silently.

If Teardown fails, warn the user but do not change existing PASS/FAIL results:
> Warning: Teardown exited with code <N>. Manual cleanup may be required.

### 7. Print the report

Print a structured report in the following format:

```
═══════════════════════════════════════════════
TDD Report: <skill>
═══════════════════════════════════════════════
Scenario 1: <name>   ✓ PASS  (3/3 criteria)
Scenario 2: <name>   ✗ FAIL  (1/2 criteria)
  ✗ "<criterion text>"
     Expected: criterion to be satisfied
     Actual:   <actual output or error evidence>
───────────────────────────────────────────────
Result: <N>/<total> scenarios | <N>/<total> criteria
═══════════════════════════════════════════════
```

Rules for the report:
- A scenario is PASS only if **all** its criteria pass
- A scenario is FAIL if **any** criterion fails
- For each failing criterion, show the criterion text, and the actual output or error that caused the failure
- The summary line shows scenarios passed / total and criteria passed / total
- If Teardown produced a warning, append it below the report block

If all scenarios pass, append:
> All tests passed. The skill is behaving as specified.

If any scenario fails, append:
> Some tests failed. Review the failing criteria above and update either the skill implementation or the test expectations in `tdd/<skill>/test.md`.

## Constraints

- Always run Teardown — never skip it, even on unhandled errors
- Never modify files outside of `tdd/` or temporary state seeded by the test itself — do not touch skill source files, settings, hooks, or registry entries
- Never modify non-`tdd-` prefixed tmux session state
- Each scenario must be fully isolated — a failure in scenario N must not bleed state into scenario N+1
- If the skill under test crashes, mark all its criteria FAIL with the crash output as evidence; do not re-throw or halt the runner
- Do not invent or assume criterion outcomes — base PASS/FAIL strictly on exit codes and actual output
- This skill is fully generic — no references to specific projects, repos, app names, or organization conventions
