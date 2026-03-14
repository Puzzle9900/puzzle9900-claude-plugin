# AI-Native Engineering Framework

**Milestone**: 001_ai-native-engineering-framework
**Created**: 2026-03-13
**Status**: Draft

## Overview
A personal framework for shifting from a traditional hands-on engineering mindset to an AI-native one — where the primary skill is not *doing* the work, but *enabling Claude to do the work*. This specification captures the motivation, concerns, guiding principles, and roadmap for an experienced Android and cloud engineer transitioning into an AI-delegated workflow across platforms, starting with iOS as the first unfamiliar territory.

## Motivation

### The Core Shift
Traditional engineering: "How do I build this?"
AI-native engineering: "How do I enable Claude to build this for me?"

This is not about replacing engineering skill — it is about **reframing** it. The value moves from manual implementation to:
- Crafting precise specifications
- Designing effective agent workflows
- Building reusable skills that compound over time
- Orchestrating pipelines that reduce human-in-the-loop friction

### Why Now
- AI agent tooling (Claude Code, skills, agents, hooks) has reached a maturity level where delegation is practical, not theoretical
- Many engineers are already reducing on-ramp time for new platforms by leveraging agent workflows — the gap between those who adopt and those who don't is widening
- Expanding into iOS without deep platform expertise is the ideal proving ground: success here validates the entire approach

### Personal Context
- **Strong in**: Android engineering, cloud engineering — years of hands-on experience
- **Growing into**: iOS development, with Claude as the primary implementer
- **Goal**: Build things that are simple and integrate smoothly with Claude, reducing manual interaction to the minimum necessary

## Concerns and How We Address Them

| Concern | Status | Approach |
|---------|--------|----------|
| **What if Claude changes tomorrow?** | Open | Keep skills and specs platform-agnostic where possible. Specs are Markdown — portable to any LLM. Skills follow a simple contract (frontmatter + instructions). Avoid deep coupling to Claude-specific APIs unless the value justifies it. |
| **What if we need to switch to another AI?** | Open | The spec-driven workflow (write spec → delegate → review) works with any capable model. Skills are essentially structured prompts — transferable. The orchestration layer is the lock-in risk; keep it thin. |
| **How do I orchestrate agents and skills?** | Open | Start simple: one skill per concern, composed manually. Evolve toward pipeline definitions as patterns emerge. Document orchestration patterns in this plugin as they mature. |
| **How do I manage multiple pipelines?** | Open | Use the plugin's folder structure as the source of truth. Each skill/agent is self-contained. Pipeline composition happens through clear naming, ordering conventions, and a future orchestration guide. |
| **Should everything run in the Claude console?** | Open | The console is the primary interface for interactive work. For batch/automated workflows, consider the SDK or CI hooks. Start in-console; graduate to SDK only when the console becomes a bottleneck. |
| **Do I need the SDK?** | Open | Not yet. The SDK becomes relevant when: (a) you need programmatic orchestration, (b) you want to embed Claude in a CI/CD pipeline, or (c) console-based interaction is too slow for repetitive tasks. Revisit after the first 5 skills are built. |
| **How do I see the orchestration clearly?** | Open | Maintain a living orchestration guide (`docs/orchestration-guide.md`). Use naming conventions (`domain/platform/skill-name`) to make pipelines self-documenting. Consider a visual map once complexity warrants it. |
| **How do I keep my skills and agents up to date?** | Open | Version skills alongside the plugin. Review and prune quarterly. Tag skills with a `last-verified` date. When Claude's capabilities change, re-test the most critical skills first. |
| **How do I drive and steer outcomes?** | Open | Through specifications (this), reviews, and feedback loops. The engineer's role shifts from writing code to writing intent — and verifying the result matches. |

## Guiding Principles

### 1. Spec-First, Always
Never ask Claude to build something without a written specification. The spec is the artifact — the code is the output. Specs survive model changes, team changes, and platform changes.

### 2. Reduce Manual Interaction, Not Control
The goal is fewer keystrokes, not less oversight. Every skill and agent should reduce the *routine* interaction while preserving the *decision* interaction. You steer; Claude rows.

### 3. Start Simple, Graduate When It Hurts
- First: manual invocation of individual skills
- Then: chained skills with clear input/output contracts
- Later: orchestrated pipelines with the SDK (only when console-based chaining becomes a bottleneck)
- Never: premature abstraction of orchestration

### 4. Platform-Agnostic by Default, Platform-Specific by Necessity
Skills should be written at the highest useful level of abstraction. A "create API endpoint" skill should work for NestJS today and Express tomorrow. Only drop into platform-specific detail when the abstraction leaks.

### 5. The Plugin Is the Portfolio
This plugin is not just a tool — it is a living record of your AI-native engineering capability. Each skill represents a problem you've learned to delegate. The collection represents the scope of what you can build without doing it manually.

## Framework: The AI-Native Engineering Loop

```
┌─────────────────────────────────────────────────┐
│                                                   │
│   1. SPECIFY        Write what you want built     │
│        │            (spec.md, clear intent)        │
│        ▼                                          │
│   2. DELEGATE       Invoke skill/agent to build   │
│        │            (Claude does the work)         │
│        ▼                                          │
│   3. REVIEW         Verify output matches intent  │
│        │            (you remain the engineer)      │
│        ▼                                          │
│   4. EXTRACT        If it worked, capture the     │
│        │            pattern as a reusable skill    │
│        ▼                                          │
│   5. COMPOUND       Skills build on skills —      │
│        │            your leverage grows over time  │
│        └──────────► back to 1.                    │
│                                                   │
└─────────────────────────────────────────────────┘
```

## Roadmap

### Phase 1: Foundation (Current)
- [x] Set up the Waonder Claude plugin structure
- [x] Create the generic spec skill
- [x] Create the generic skill creator
- [ ] Document the AI-native engineering framework (this spec)
- [ ] Build 3-5 foundational skills (spec, review, scaffold)
- [ ] Validate the workflow end-to-end on a real feature

### Phase 2: iOS Proving Ground
- [ ] Create iOS-specific skills (SwiftUI scaffold, Xcode project setup, build & run)
- [ ] Build a simple iOS feature using only spec → delegate → review
- [ ] Measure: time-to-feature vs traditional learning curve
- [ ] Document what worked and what required manual intervention

### Phase 3: Cross-Platform Orchestration
- [ ] Establish skill chaining patterns (output of one → input of next)
- [ ] Create backend ↔ mobile integration skills
- [ ] Evaluate whether the SDK is needed for orchestration
- [ ] Build an orchestration map of all active pipelines

### Phase 4: Self-Sustaining System
- [ ] Skills maintain themselves (auto-update prompts when APIs change)
- [ ] New team members can onboard by reading specs and invoking skills
- [ ] The plugin becomes the canonical way to build in the Waonder ecosystem

## Success Criteria
- Can build a complete iOS feature (UI + API integration) with less than 20% manual code writing
- All reusable patterns are captured as skills, not tribal knowledge
- Switching from Claude to another capable model requires changing only the runtime, not the specs or skills
- Time from idea to working prototype is measured in hours, not days
- The plugin contains at least 15 production-quality skills within 6 months

## Notes
- This is a personal growth spec as much as a technical one — the hardest part is the mindset shift, not the tooling
- iOS was chosen as the first expansion because it is unfamiliar enough to force reliance on delegation, but close enough to Android to validate the approach
- The Waonder ecosystem (backend, web, mobile) is the perfect sandbox: complex enough to be real, controlled enough to experiment safely
- Revisit this spec monthly to update concerns status and roadmap progress
