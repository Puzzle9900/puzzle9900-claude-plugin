---
name: generic-spec
description: Create or update project specifications, milestones, and documentation in the standardized projectspecs folder structure
type: generic
---

# generic-spec

## Context
This skill manages project specifications following a strict folder structure. Use it whenever you need to create, update, or add documentation to project milestones.

## Instructions

You are a documentation specialist that creates and manages project specifications.

### Folder Structure

All documentation MUST be created in:
```
projectspecs/
├── 001_milestone-name/
│   ├── spec.md              # Main specification document
│   ├── technical-design.md  # Optional: technical details
│   ├── api-design.md        # Optional: API specifications
│   └── assets/              # Optional: diagrams, images
├── 002_another-milestone/
│   └── spec.md
└── ...
```

## Steps

1. **Analyze the Request** — Determine if the user wants to:
   - Create new milestone
   - Add to existing milestone
   - Update existing spec

2. **Find Next Number** (for new milestones):
   - List existing folders matching pattern `###_*`
   - Find the highest number
   - Increment by 1, zero-padded to 3 digits (001, 002, ... 010, ... 100)

3. **Create Folder Structure** — For new milestones:
   - Create folder: `projectspecs/{number}_{kebab-case-name}/`
   - Create `spec.md` with the template below

4. **Write Documentation** using this template:

```markdown
# {Milestone Title}

**Milestone**: {number}_{name}
**Created**: {YYYY-MM-DD}
**Status**: Draft | In Progress | Review | Approved | Completed

## Overview
{Brief description of what this milestone accomplishes}

## Goals
- {Goal 1}
- {Goal 2}
- {Goal 3}

## Requirements

### Functional Requirements
- [ ] {Requirement 1}
- [ ] {Requirement 2}

### Non-Functional Requirements
- [ ] {Performance, security, scalability requirements}

## Technical Approach
{High-level technical approach}

## Tasks
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

## Dependencies
- {List any dependencies on other milestones or external factors}

## Success Criteria
- {How do we know this milestone is complete?}

## Notes
{Additional context, decisions, or references}
```

5. **Report** the created file path to the user.

## Constraints
- Use kebab-case for folder names (e.g., `user-authentication`, `payment-integration`)
- Always 3 digits, zero-padded for numbering
- Always create `spec.md` as the primary document
- Add supplementary docs in the same milestone folder
- Cross-reference between milestones when dependencies exist
