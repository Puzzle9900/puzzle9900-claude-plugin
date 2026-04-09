---
name: generic-claude-initial-setup
description: Analyze a Claude Code project and generate a permissions allow-list of safe, commonly-used commands to reduce permission prompts. Use when the user wants to pre-approve commands or set up permissions for a project.
type: generic
---

# generic-claude-initial-setup

## Context
Every Claude Code project prompts the user for permission on each new command pattern. For projects with well-known toolchains (Node/npm, Python, Go, Rust, Java/Gradle, etc.), most of the prompts are for safe, read-only, or build-related commands that the user will always approve. This skill detects the project's tech stack and generates a tailored `permissions.allow` list so the user can drop it into their `.claude/settings.json` (or `.claude/settings.local.json`) and dramatically reduce noise.

## Instructions

Analyze the current project to detect its tech stack, build tools, and common workflows. Then produce a safe `permissions.allow` array that the user can add to their settings. Focus on commands that are **read-only, local-only, and non-destructive**. Never include commands that push code, deploy, delete data, or access secrets.

## Steps

1. **Detect the project tech stack** by checking for the presence of key files:
   - `package.json` / `yarn.lock` / `pnpm-lock.yaml` → Node.js ecosystem
   - `requirements.txt` / `pyproject.toml` / `Pipfile` / `setup.py` → Python
   - `go.mod` → Go
   - `Cargo.toml` → Rust
   - `build.gradle` / `pom.xml` → Java/Kotlin (Gradle or Maven)
   - `Gemfile` → Ruby
   - `Makefile` → Make-based builds
   - `Dockerfile` / `docker-compose.yml` → Docker
   - `.terraform/` / `*.tf` → Terraform
   - `pubspec.yaml` → Flutter/Dart
   - `*.xcodeproj` / `*.xcworkspace` → iOS/macOS (Xcode)
   - `build.gradle.kts` with `android` block or `AndroidManifest.xml` → Android

2. **Read the project's scripts/commands** (e.g., `scripts` in `package.json`, `Makefile` targets, `Pipfile` scripts) to discover project-specific safe commands.

3. **Build the allow list** by combining:

   **a) Universal safe commands (always include):**
   ```
   Bash(git status)
   Bash(git log *)
   Bash(git diff *)
   Bash(git branch *)
   Bash(git show *)
   Bash(git rev-parse *)
   Bash(git remote -v)
   Bash(git stash list)
   Bash(ls *)
   Bash(pwd)
   Bash(which *)
   Bash(cat *)
   Bash(wc *)
   Bash(head *)
   Bash(tail *)
   Bash(echo *)
   Bash(date)
   Bash(env)
   Bash(printenv *)
   Bash(mkdir *)
   ```

   **b) Stack-specific safe commands** (include only if detected):

   **Node.js / npm / yarn / pnpm:**
   ```
   Bash(npm run lint *)
   Bash(npm run test *)
   Bash(npm run build *)
   Bash(npm run format *)
   Bash(npm run typecheck *)
   Bash(npm list *)
   Bash(npm ls *)
   Bash(npm outdated *)
   Bash(npm view *)
   Bash(npm run check *)
   Bash(npx tsc --noEmit *)
   Bash(npx prettier --check *)
   Bash(npx eslint *)
   Bash(npx jest *)
   Bash(npx vitest *)
   Bash(node *)
   ```
   If yarn detected:
   ```
   Bash(yarn lint *)
   Bash(yarn test *)
   Bash(yarn build *)
   Bash(yarn format *)
   Bash(yarn typecheck *)
   Bash(yarn check *)
   ```
   If pnpm detected:
   ```
   Bash(pnpm lint *)
   Bash(pnpm test *)
   Bash(pnpm build *)
   Bash(pnpm format *)
   Bash(pnpm typecheck *)
   ```

   **Python:**
   ```
   Bash(python *)
   Bash(python3 *)
   Bash(pip list *)
   Bash(pip show *)
   Bash(pytest *)
   Bash(mypy *)
   Bash(ruff check *)
   Bash(ruff format --check *)
   Bash(flake8 *)
   Bash(black --check *)
   Bash(isort --check *)
   Bash(pylint *)
   ```
   If poetry detected (`pyproject.toml` with `[tool.poetry]`):
   ```
   Bash(poetry run *)
   Bash(poetry show *)
   ```
   If pipenv detected:
   ```
   Bash(pipenv run *)
   ```

   **Go:**
   ```
   Bash(go build ./...)
   Bash(go test *)
   Bash(go vet *)
   Bash(go fmt *)
   Bash(go mod tidy)
   Bash(go list *)
   Bash(go version)
   Bash(golangci-lint run *)
   ```

   **Rust:**
   ```
   Bash(cargo build *)
   Bash(cargo test *)
   Bash(cargo check *)
   Bash(cargo clippy *)
   Bash(cargo fmt *)
   Bash(cargo doc *)
   Bash(rustc --version)
   ```

   **Java / Kotlin (Gradle):**
   ```
   Bash(./gradlew build *)
   Bash(./gradlew test *)
   Bash(./gradlew check *)
   Bash(./gradlew lint *)
   Bash(./gradlew assemble *)
   Bash(./gradlew tasks *)
   ```

   **Java / Kotlin (Maven):**
   ```
   Bash(mvn compile *)
   Bash(mvn test *)
   Bash(mvn verify *)
   Bash(mvn package *)
   ```

   **Ruby:**
   ```
   Bash(bundle exec *)
   Bash(rake *)
   Bash(ruby *)
   Bash(rspec *)
   Bash(rubocop *)
   ```

   **Make:**
   ```
   Bash(make *)
   ```

   **Docker (read-only):**
   ```
   Bash(docker ps *)
   Bash(docker images *)
   Bash(docker logs *)
   Bash(docker compose ps *)
   Bash(docker compose logs *)
   Bash(docker inspect *)
   ```

   **Flutter / Dart:**
   ```
   Bash(flutter analyze *)
   Bash(flutter test *)
   Bash(flutter build *)
   Bash(dart analyze *)
   Bash(dart test *)
   Bash(dart format *)
   ```

   **iOS / macOS (Xcode):**
   ```
   Bash(xcodebuild -list *)
   Bash(xcodebuild -showBuildSettings *)
   Bash(xcodebuild build *)
   Bash(xcodebuild test *)
   Bash(swift build *)
   Bash(swift test *)
   Bash(swift package *)
   Bash(pod install *)
   ```

   **Android:**
   ```
   Bash(./gradlew assembleDebug *)
   Bash(./gradlew assembleRelease *)
   Bash(./gradlew connectedAndroidTest *)
   Bash(./gradlew lintDebug *)
   Bash(adb devices)
   Bash(adb logcat *)
   ```

   **Terraform (read-only):**
   ```
   Bash(terraform plan *)
   Bash(terraform validate *)
   Bash(terraform fmt *)
   Bash(terraform show *)
   ```

   **c) Project-specific scripts** found in `package.json` `scripts`, `Makefile` targets, etc. — include as individual `Bash(<package-manager> run <script-name> *)` entries.

4. **Check for existing settings** — read `.claude/settings.json` and `.claude/settings.local.json` if they exist. Merge new entries with any existing `permissions.allow` list without duplicating.

5. **Ask the user to pick a completion sound** — present a numbered list and let them choose one (or skip):

   ```
   Which sound should play when Claude Code finishes a task?

    1. Basso
    2. Blow
    3. Bottle
    4. Frog
    5. Funk
    6. Glass
    7. Hero
    8. Morse
    9. Ping
   10. Pop
   11. Purr
   12. Sosumi
   13. Submarine
   14. Tink
   15. Spoken: "Task complete" (uses macOS say command)
   16. No sound — skip this

   Enter a number:
   ```

   Map the selection to a shell command:
   - Options 1–14 → `afplay /System/Library/Sounds/<Name>.aiff`
   - Option 15 → `say "Task complete"`
   - Option 16 → skip hook creation entirely

6. **Present the result to the user** with:
   - A summary of detected tech stacks
   - The full JSON block ready to paste or apply (permissions + Stop hook if a sound was chosen)
   - Ask the user which settings file they want to write to:
     - `.claude/settings.json` — shared with team (committed to git)
     - `.claude/settings.local.json` — personal only (gitignored)

7. **Apply only after user confirmation** — write to the chosen settings file, preserving any other existing settings:

   a) Merge the `permissions.allow` array (no duplicates).

   b) If a sound was chosen, create `.claude/hooks/play-song.sh` with this content:
   ```bash
   #!/bin/bash
   <selected-command>
   ```
   Make it executable (`chmod +x .claude/hooks/play-song.sh`).

   Then add (or merge) the `Stop` hook in the settings file:
   ```json
   "hooks": {
     "Stop": [
       {
         "hooks": [
           {
             "type": "command",
             "command": "bash .claude/hooks/play-song.sh"
           }
         ]
       }
     ]
   }
   ```
   If a `hooks` key already exists, merge `Stop` into it without overwriting other hook types.

## Constraints
- Never include commands that **push, deploy, publish, or delete** (e.g., `git push`, `npm publish`, `docker rm`, `terraform apply`, `rm -rf`)
- Never include commands that **access or expose secrets** (e.g., `cat .env`, `printenv SECRET_*`)
- Never add `Read(./.env)`, `Read(./.env.*)`, or `Read(./secrets/**)` to the allow list
- Never add `Bash(curl *)`, `Bash(wget *)`, or other network-exfiltration-capable commands
- Never add `Bash(rm *)`, `Bash(sudo *)`, or other destructive/privileged commands
- Do not include `defaultMode: "bypassPermissions"` — the goal is a curated allow-list, not blanket bypass
- The skill must remain fully generic — no references to specific projects, repos, or organization names
- Always let the user review and confirm before writing to any settings file
- If the project has no detectable tech stack, fall back to the universal safe commands only and inform the user
- Preserve any existing settings (hooks, env, etc.) when writing — only modify the `permissions.allow` array
