---
name: generic-skill-best-practices
description: Best practices and quality guidelines for writing effective skill definitions. Use this before or during skill creation to ensure the skill is well-designed, concise, and reliable.
type: generic
---

# generic-skill-best-practices

## Context

This skill provides quality and design guidance for writing skill definitions. It complements `generic-skill-creator-structure`, which covers file format, naming, and folder placement. This skill covers what makes a skill actually useful: clear purpose, atomic steps, efficient context usage, and reliable execution.

Use this skill when:
- You are about to create a new skill and want to ensure quality
- You are reviewing or improving an existing skill
- You need to decide whether a skill is the right solution versus an agent or MCP

## Instructions

Apply these best practices when creating, reviewing, or improving any skill definition. Each practice addresses a common failure mode. When reviewing an existing skill, check each practice and flag violations.

## Steps

### 1. Start with concrete use cases, not abstract helpfulness

Before writing a skill, identify 2-3 specific situations where a user would need it. Write these as the "Use this skill when" bullets in the Context section.

- **Good**: "Use this when you need to create a new milestone spec with the standardized template"
- **Bad**: "Use this to help with documentation tasks"

If you cannot name at least two concrete triggers, the skill may be too vague to be useful. A skill that tries to help with everything helps with nothing.

### 2. Write the description for auto-invocation

The `description` field in frontmatter is how Claude decides whether to activate a skill automatically. It must contain:
- The specific action the skill performs (third person: "Creates...", "Validates...", "Generates...")
- Enough trigger keywords for Claude to match against user intent
- The context in which it applies

Test your description mentally: if a user says "I want to [task]", would this description clearly match or clearly not match? Ambiguous descriptions cause false activations or missed activations — both are bad.

### 3. Make each step atomic, sequential, and complete

Every step in the Steps section should:
- **Do exactly one thing** — if a step contains "and" connecting two different actions, split it
- **Be independently verifiable** — someone reviewing the output should be able to confirm this step was completed correctly
- **Include its own success criteria** — what does "done" look like for this step?
- **Follow sequentially** — step N should depend on step N-1 being complete

Bad step: "Analyze the codebase and generate the configuration file"
Good steps: "1. Identify all configuration sources in the project" then "2. Generate the configuration file using the identified sources"

### 4. Keep skills concise — context window efficiency matters

Every token in a skill definition consumes context window space when loaded. Respect this budget:

- Cut explanatory prose that does not change behavior — if removing a sentence would not change what Claude does, remove it
- Use tables and lists over paragraphs for structured information
- Put examples inline only when the exact format is load-bearing
- Avoid restating what Claude already knows how to do — reference existing tools and commands instead of explaining them

A skill that is twice as long is not twice as good. It is half as efficient.

### 5. Write Constraints that prevent real misuse

The Constraints section is not a style guide. It should prevent specific, observed (or anticipated) failure modes:

- **Good constraint**: "Always create files in the current working directory, never in the plugin repository where this skill definition lives"
- **Bad constraint**: "Be thorough and helpful"

Each constraint should be testable: either the output violates it or it does not. Vague guidance like "be concise" or "don't be verbose" belongs nowhere — demonstrate the desired style in the Steps section instead. Show, do not tell.

### 6. Use ${CLAUDE_PLUGIN_ROOT} for portable paths

When a skill needs to reference files within the plugin repository (for example, to read a template), use `${CLAUDE_PLUGIN_ROOT}` instead of hardcoded absolute paths. This ensures the skill works regardless of where the plugin is installed.

For files in the consuming project (where the user invoked the skill), use relative paths from the current working directory.

### 7. Choose skills over MCPs and agents appropriately

Understand what each tool type is for:

| Type | Best for | Examples |
|------|----------|---------|
| **Skill** | Codified workflows and knowledge — things that follow a repeatable process | Creating specs, setting up projects, running review checklists |
| **Agent** | Persistent domain expertise — things that require reasoning about a specific area | Feature experts, architecture reviewers, code quality guardians |
| **MCP** | Real-time external data — things that need live information from APIs or services | Ticket lookups, wiki reads, CI status checks |

If your skill mostly fetches live data and presents it, it should probably be an MCP. If it mostly reasons about a domain without following specific steps, it should be an agent. Skills are for repeatable, step-by-step workflows.

### 8. Test with realistic user prompts

After writing a skill, test it by invoking it the way a real user would — not with a perfectly formatted command, but with the casual, incomplete way people actually ask for things:

- "set up the project" (not "/generic-setup-project with environment=local")
- "make a spec for the auth feature" (not "/generic-spec create milestone auth-feature")
- "test my skill" (not "/generic-skill-tester skills/my-skill/SKILL.md")

If the skill fails on natural language invocations, its Steps section likely has gaps in how it resolves ambiguous input. Add clarification steps or sensible defaults.

### 9. Avoid meta-instructions — show, do not tell

Do not include instructions like:
- "Be concise in your responses"
- "Use a professional tone"
- "Think step by step"

These are vague and unenforceable. Instead, demonstrate the desired behavior:
- Write the Steps section in the exact tone you want the output to follow
- Include output templates that show the target format
- Use the Output Format subsection (if applicable) to define structure explicitly

The skill definition itself is the style guide. Claude will mirror what it reads.

### 10. Reference existing tools rather than reimplementing

If a step requires functionality that an existing tool, skill, or MCP already provides, reference it instead of inlining a reimplementation:

- **Good**: "Invoke the `generic-agent-creator-structure` skill for file format and naming"
- **Bad**: (copy-pasting the entire agent file structure into your skill)

This avoids duplication, reduces skill size, and ensures that when the referenced tool is updated, all consumers get the improvement.

### 11. Plan for edge cases in the Steps

Common edge cases every skill should handle:
- What if the target file or directory already exists?
- What if the user provides incomplete input?
- What if a referenced tool or MCP is unavailable?
- What if the operation partially succeeds?

Each edge case should map to a specific behavior: ask the user, use a default, fail with a clear message, or skip gracefully. Skills that ignore edge cases produce unpredictable results.

## Constraints

- This skill provides guidance only — it does not create or modify skill files directly
- Do not duplicate content from `generic-skill-creator-structure` — that skill covers format and naming; this skill covers quality and design
- All examples must remain generic and project-agnostic per the repository's generic-only policy
- Do not use meta-instructions like "be concise" in examples — demonstrate the desired behavior instead
- When comparing skills to agents and MCPs, remain factual about capabilities — do not oversell any approach
