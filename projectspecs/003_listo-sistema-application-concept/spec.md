# Listo Sistema Application Concept

**Milestone**: 003_listo-sistema-application-concept
**Created**: 2026-04-10
**Status**: Draft

---

## Overview

As LLMs become central to the daily development workflow, applications can no longer be designed around human-only development cycles. The **Listo Sistema** concept proposes an architecture for Android applications that is inherently suited to AI-assisted development: modular, slot-driven, and experimentation-first.

The core premise is simple: **features are independent units that plug into defined slots in the application shell**. Each feature can be developed, tested, experimented on, and removed without touching any other part of the system. This is not just a modular architecture — it is a system designed so that an AI agent can add or modify a feature with zero risk of unintended side effects elsewhere.

The name *Listo Sistema* ("Ready System" in Spanish) captures the idea of an application that is **always ready** to receive new features — from humans or from AI agents.

---

## The Problem This Solves

Traditional Android architectures (even clean, MVVM ones) couple features through shared modules, shared navigation graphs, shared state containers, and shared dependency injection wiring. When AI tooling generates a new feature, it must understand and modify all of this shared surface — which is error-prone and creates regression risk.

**The key shift:**

| Traditional Architecture | Listo Sistema |
|---|---|
| Features share a global DI graph | Each feature owns its own isolated DI scope |
| Navigation is centrally managed | Features declare their own navigation contracts |
| State is shared across features | State never crosses feature boundaries |
| Adding a feature = modifying shared files | Adding a feature = dropping a new module into a slot |
| A/B test = wrap everything in flags | A/B test = swap one slot's implementation |

---

## Goals

- Define an Android architecture where features are independently deployable units with zero shared mutable state
- Establish a "slot" abstraction that represents a named, typed integration point in the application shell
- Enable AI agents to generate, modify, or remove a feature without reading or touching any other feature module
- Make A/B testing and experimentation a structural property of the architecture, not an afterthought
- Provide a reference implementation blueprint applicable to any Android project

---

## Core Principles

### 1. Feature Isolation (Zero Coupling)
A feature module must not import from another feature module. Period. All cross-feature communication happens through the shell via typed contracts (interfaces/events). The dependency graph flows in one direction: `shell → feature`, never `feature → feature`.

### 2. Slot-Based Composition
The application shell defines a fixed set of **slots** — typed integration points where features are mounted. A slot is a Kotlin interface that any feature can implement. The shell does not know which feature occupies a slot at compile time; it only knows the interface.

```
AppShell
 ├── Slot: HomeContentSlot
 ├── Slot: NavigationSlot
 ├── Slot: ProfileSlot
 ├── Slot: NotificationSlot
 └── Slot: ExperimentalSlot[N]  ← reserved slots for AI-generated features
```

### 3. Experimentation as a First-Class Citizen
Every slot can have multiple registered implementations. A feature flag or experiment resolves which implementation fills the slot at runtime. This means a full A/B test is a matter of registering a second implementation for a slot — no `if/else` scattered through the codebase.

### 4. AI-Ready Contracts
Each slot is described by a machine-readable contract: a Kotlin interface + a JSON schema documenting its inputs and outputs. AI agents read these contracts to understand the integration surface before generating any code. The contract is the AI's specification.

### 5. Stackable Features
Multiple features can be stacked onto a single slot via a **FeatureStack** — a composable chain of slot implementations. This allows progressive enhancement: a base feature, a premium tier feature, and an experimental feature can all layer onto the same slot, each wrapping the previous.

---

## Proposed Architecture

### Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     APPLICATION SHELL                    │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌───────────┐  │
│  │ Slot A  │  │ Slot B  │  │ Slot C  │  │ Slot D... │  │
│  └────┬────┘  └────┬────┘  └────┬────┘  └─────┬─────┘  │
│       │            │            │              │         │
│  ┌────▼────────────▼────────────▼──────────────▼──────┐ │
│  │             SLOT REGISTRY (+ EXPERIMENT ENGINE)    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────┘
                          │ resolves
          ┌───────────────┼───────────────┐
          │               │               │
┌─────────▼──────┐ ┌──────▼──────┐ ┌─────▼──────────┐
│  Feature Mod A │ │ Feature Mod │ │ Feature Mod C  │
│  (impl Slot A) │ │ B (impl B)  │ │ (impl Slot A   │
│                │ │             │ │  variant — A/B)│
│  ViewModel     │ │ ViewModel   │ │ ViewModel      │
│  UseCase       │ │ UseCase     │ │ UseCase        │
│  Repository    │ │ Repository  │ │ Repository     │
│  (local DI)    │ │ (local DI)  │ │ (local DI)     │
└────────────────┘ └─────────────┘ └────────────────┘
          │               │               │
          └───────────────▼───────────────┘
                 SHARED KERNEL (no features allowed)
          ┌─────────────────────────────────────────┐
          │  Network client  │  Analytics contract  │
          │  Auth token      │  Logger              │
          │  Local DB schema │  Feature flag client │
          └─────────────────────────────────────────┘
```

### Module Structure

```
app/                          ← Shell module (thin, only wires slots)
  src/main/
    AppShell.kt               ← Registers slots
    SlotRegistry.kt           ← Runtime slot resolver

feature-contracts/            ← Interfaces only, no implementations
  HomeContentSlot.kt
  NavigationSlot.kt
  ProfileSlot.kt
  FeatureStack.kt             ← Composable wrapper

feature-home/                 ← Feature module (implements HomeContentSlot)
  FeatureHomeModule.kt        ← Hilt module, local scope
  HomeViewModel.kt
  HomeUseCase.kt
  HomeRepository.kt
  HomeScreen.kt               ← Compose UI

feature-home-v2/              ← A/B variant (same slot, different impl)
  ...

feature-profile/              ← Feature module (implements ProfileSlot)
  ...

shared-kernel/                ← Shared infrastructure (no feature code)
  network/
  auth/
  analytics/
  featureflags/
  db/
```

### Slot Contract (Kotlin)

```kotlin
// In feature-contracts module
interface HomeContentSlot {
    @Composable
    fun Content(modifier: Modifier)
    val analyticsTag: String
}

// In app shell
class SlotRegistry @Inject constructor(
    private val experimentEngine: ExperimentEngine
) {
    fun resolveHomeContent(): HomeContentSlot {
        return experimentEngine.resolve(
            slotId = "home_content",
            variants = mapOf(
                "control" to HomeFeatureV1(),
                "treatment" to HomeFeatureV2()
            )
        )
    }
}
```

### Feature Registration

```kotlin
// Each feature self-registers — shell never imports feature internals
@Module
@InstallIn(SingletonComponent::class)
object AppSlotModule {
    @Provides fun homeSlot(engine: ExperimentEngine): HomeContentSlot =
        engine.resolve("home_content", mapOf(
            "v1" to HomeFeatureV1Module.provide(),
            "v2" to HomeFeatureV2Module.provide()
        ))
}
```

### Feature Stack (Layered Features)

```kotlin
// Stack multiple features on one slot — each wraps the previous
val profileSlot: ProfileSlot = FeatureStack.build<ProfileSlot>()
    .add(BaseProfileFeature())
    .addIf(isPremiumUser) { PremiumProfileFeature(it) }
    .addIf(isInExperiment("new_badge")) { BadgeProfileFeature(it) }
    .build()
```

---

## Experimentation Model

### Three Layers of Experimentation

```
Layer 3: Slot Swap        — entirely swap a feature implementation per variant
Layer 2: Stack Insertion  — add/remove layers in a feature stack
Layer 1: In-Feature Flag  — simple flag within a feature for small changes
```

Only Layer 1 (in-feature flags) is allowed to modify internals of a feature module. Layers 2 and 3 never touch feature code — they operate purely at the slot registry level. This means an experiment at Layer 2 or 3 is zero-risk to any feature module.

### Experiment Lifecycle

```
Define → Register variant in SlotRegistry
Deploy → Gradual rollout via feature flag platform (GrowthBook / Eppo / Statsig)
Measure → Each slot emits standardized analytics events via contract
Graduate → Winning variant becomes the default; losing variant module is deleted
```

---

## AI Agent Integration Points

The architecture is specifically designed so that AI agents can work with minimal context:

| AI Agent Task | What It Needs to Read | What It Touches |
|---|---|---|
| Add a new feature | `feature-contracts/` (1 interface) + `shared-kernel/` | 1 new feature module + 1 line in SlotModule |
| A/B test a feature | Existing feature module + slot contract | 1 new variant module + 1 line in SlotRegistry |
| Remove a feature | SlotRegistry entry | Delete 1 module folder |
| Modify a feature | Only that feature's own files | Only that feature module |

**The AI-readable contract file** (`feature-contracts/ContractManifest.json`) documents each slot in a format an LLM can parse directly:

```json
{
  "slots": [
    {
      "id": "home_content",
      "interface": "HomeContentSlot",
      "inputs": [],
      "outputs": ["analyticsTag"],
      "currentImpl": "feature-home",
      "variants": ["feature-home-v2"]
    }
  ]
}
```

---

## Requirements

### Functional Requirements
- [ ] Define the `Slot` interface abstraction and `SlotRegistry` wiring mechanism
- [ ] Implement `FeatureStack` for layered feature composition
- [ ] Implement `ExperimentEngine` that resolves slot implementations from a feature flag platform
- [ ] Define `ContractManifest.json` schema and generation tooling
- [ ] Produce a reference Android project demonstrating the full pattern with 3 features and 1 A/B experiment

### Non-Functional Requirements
- [ ] A feature module must have zero compile-time dependencies on any other feature module (enforced by lint rule or Gradle constraint)
- [ ] Adding a new feature must require touching at most 2 files outside the new feature module
- [ ] Each slot resolution must add less than 1ms overhead at startup
- [ ] The architecture must be compatible with Hilt, Compose, and Navigation Component

---

## Tasks
- [ ] Finalize slot abstraction API design
- [ ] Define `ContractManifest.json` schema
- [ ] Implement `SlotRegistry` + `ExperimentEngine` prototype
- [ ] Implement `FeatureStack` composable wrapper
- [ ] Create reference Android project
- [ ] Write Gradle lint rule enforcing feature-to-feature import prohibition
- [ ] Document AI agent workflow (how an agent reads contracts and generates a new feature)

---

## Dependencies
- Depends on 001_ai-native-engineering-framework (AI tooling context)
- External: feature flag platform (GrowthBook, Eppo, or Statsig)
- External: Hilt, Jetpack Compose, Navigation Component

---

## Who Is Already Talking About This

The concept sits at the intersection of several active conversations:

### Modular / Slot-Based Architecture

- **Uber Engineering** — ["Engineering Scalable, Isolated Mobile Features with Plugins"](https://eng.uber.com/plugins/) — The closest real-world precedent. Uber built exactly this: a plugin system with typed integration points (slots), feature isolation enforcement, and A/B testing at the slot level using RIBs.
- **Uber RIBs** — [github.com/uber/RIBs](https://github.com/uber/RIBs) — Open-source cross-platform framework implementing this pattern.
- **Airbnb Engineering** — ["Introducing Trio"](https://medium.com/airbnb-engineering/introducing-trio-part-i-7f5017a1a903) — Airbnb's Compose-based modular UI architecture.
- **Polylith** — [polylith.gitbook.io](https://polylith.gitbook.io/polylith) — Formally specified LEGO-block architecture for backend systems. "Components + Bases + Interfaces" maps directly to "Features + Shell + Slot Contracts."
- **Google Android Team** — [developer.android.com/topic/modularization](https://developer.android.com/topic/modularization) — Official Android guidance on feature module patterns.

### AI-Native Architecture

- **arXiv: "Architecture Without Architects"** (2025) — [arxiv.org/abs/2604.04990](https://arxiv.org/abs/2604.04990) — Introduces "vibe architecting" — the phenomenon where AI coding agents make implicit architectural decisions through natural-language prompts. Identifies 5 coupling mechanisms. Directly motivates the need for Listo Sistema: if AI is shaping architecture implicitly, we must give it an explicit, safe structure to work within.
- **Martin Fowler / The Pragmatic Engineer** — [newsletter.pragmaticengineer.com](https://newsletter.pragmaticengineer.com/p/martin-fowler) — Fowler argues modular, refactorable architecture becomes *more* critical in the AI era, not less.
- **vFunction: "The Rise of Vibe Coding: Why Architecture Still Matters"** — [vfunction.com](https://vfunction.com/blog/vibe-coding-architecture-ai-agents/) — Makes the exact same argument: clean modular architecture is the prerequisite for reliable AI-generated code.
- **MIT CSAIL (2025)** — [news.mit.edu](https://news.mit.edu/2025/mit-researchers-propose-new-model-for-legible-modular-software-1106) — Proposes formal modularity models designed to remain legible to both humans and AI agents. Validates the legibility-first design of Listo Sistema.
- **Medium / Areg Petrosyan: "The Secret Weapon for AI Agents in Android"** — [medium.com/@aregyan](https://medium.com/@aregyan/the-secret-weapon-for-ai-agents-in-android-why-clean-architecture-beats-chaos-3dc561f72502) — Directly argues that clean, modular Android architecture makes AI agents more effective.

### Experimentation + Feature Flags

- **Rıdvan Özcan: "Feature Flags and Modular Development in Android"** — [medium.com/@ridvanozcan48](https://medium.com/@ridvanozcan48/feature-flags-and-modular-development-ensuring-flexibility-in-large-android-projects-14e9213c4b2a) — Android-specific treatment combining feature flags with modular architecture.
- **GrowthBook** — [growthbook.io](https://www.growthbook.io) — Open-source feature flag + A/B testing platform. A natural fit as the `ExperimentEngine` backend in this architecture.
- **Eppo** — [geteppo.com](https://www.geteppo.com/blog/mobile-experimentation-eppo-feature-flags-ab-testing) — Statistical experimentation platform for mobile, including Android SDK.
- **Optimizely: "6 Experimentation Secrets from Airbnb and Uber"** — [optimizely.com](https://www.optimizely.com/insights/blog/6-experimentation-secrets-from-airbnb-and-uber/) — Airbnb and Uber's internal culture of feature-level experimentation.

### Broader Context

- **Red Hat Developer: "Vibes, Specs, Skills, and Agents"** — [developers.redhat.com](https://developers.redhat.com/articles/2026/03/30/vibes-specs-skills-agents-ai-coding) — Names the four layers of agentic coding: vibes (intent), specs (structure), skills (reusable procedures), agents (executors). Listo Sistema is the "specs" layer for Android.
- **Eugene Yan (Amazon): "Patterns for Building LLM-based Systems"** — [eugeneyan.com](https://eugeneyan.com/writing/llm-patterns/) — The canonical reference on LLM system patterns. The composition and isolation patterns map directly to slot-based feature architecture.

---

## Success Criteria

- A developer (or AI agent) can add a fully functional new feature to a Listo Sistema app by creating 1 new Gradle module and adding 1 line to the slot registry — nothing else.
- A/B testing a feature requires zero changes to existing feature code.
- A feature module can be deleted with zero cascading compile errors.
- An AI agent given only `ContractManifest.json` and the `shared-kernel/` module can generate a valid, compilable feature module that passes lint checks.

---

## Notes

The name *Listo Sistema* is intentionally bilingual: "listo" means both "ready" (Spanish) and evokes "list" as in a composable list of capabilities. The system is always ready to receive new features.

This concept is not a new framework — it is a set of architectural constraints and conventions applied on top of existing Android primitives (Hilt, Compose, Gradle multi-module). The goal is a pattern, not a library.

Future work could include a Gradle plugin that enforces the slot contract schema and auto-generates the `ContractManifest.json` from Kotlin interfaces.
