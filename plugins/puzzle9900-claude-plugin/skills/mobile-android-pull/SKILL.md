---
name: mobile-android-pull
description: Pull latest changes, build the Android app, deploy to a connected device, and open Android Studio — use at the start of a dev session or after a branch switch.
type: mobile
platform: android
---

# mobile-android-pull

## Context

This skill starts a fresh Android development session: pulls the latest code, builds the app, installs it on a connected device or emulator, and opens Android Studio pointed at the right directory. It works from the current working directory or from inside a git worktree.

Use it at the start of a coding session, after switching branches, or after rebasing.

## Instructions

Perform the steps below in order. Detect project values (app ID, module name, main activity) from project files — never hardcode them. Stop and report clearly if any step fails.

## Steps

### 1. Resolve working directory

Use the current working directory as the project root:

```bash
git rev-parse --show-toplevel
```

Record the result as `PROJECT_ROOT`. If CWD is inside a git worktree, this resolves to the worktree root — which is the correct target.

### 2. Pull latest changes

```bash
cd "$PROJECT_ROOT"
git pull --rebase --autostash
```

- `--rebase` keeps local commits on top of upstream changes.
- `--autostash` stashes uncommitted changes before rebasing and restores them after.
- If merge conflicts arise, stop and report them to the user — do not attempt to auto-resolve.

### 3. Detect project details

Read these values from project files (do not assume):

**App ID** — from `app/build.gradle` or `app/build.gradle.kts`:

```bash
grep -E 'applicationId' "$PROJECT_ROOT"/app/build.gradle* | head -1
```

**Main activity** — from `AndroidManifest.xml`:

```bash
grep -B1 'android.intent.action.MAIN' "$PROJECT_ROOT"/app/src/main/AndroidManifest.xml | grep 'android:name'
```

Record `APP_ID` and `MAIN_ACTIVITY` for Step 6.

### 4. Open Android Studio

Open Android Studio pointed at the project root (non-blocking):

```bash
open -a "Android Studio" "$PROJECT_ROOT"
```

If the `studio` CLI launcher is available at `/Applications/Android Studio.app/Contents/MacOS/studio`:

```bash
/Applications/Android Studio.app/Contents/MacOS/studio "$PROJECT_ROOT" &
```

Android Studio will trigger a Gradle sync automatically on open. The remaining steps run in parallel while it loads.

### 5. Build the app

```bash
cd "$PROJECT_ROOT"
./gradlew :app:assembleDebug
```

- If the default module is not `app`, adjust the task prefix accordingly (e.g., `:feature-app:assembleDebug`).
- Report full error output if the build fails — do not proceed to installation.

### 6. Deploy to device

**6a. Check connected devices:**

```bash
adb devices
```

- If no device is listed → ask the user to connect a device or start an emulator, then stop.
- If multiple devices are listed → ask the user which one to target and apply `-s <serial>` to all subsequent `adb` commands.

**6b. Install the APK:**

```bash
adb install -r "$PROJECT_ROOT/app/build/outputs/apk/debug/app-debug.apk"
```

(`-r` reinstalls over an existing version without uninstalling first.)

**6c. Launch the app:**

```bash
adb shell am start -n "${APP_ID}/${MAIN_ACTIVITY}"
```

### 7. Report status

```
## Session Ready

- **Project root**: <path>
- **Branch**: <current branch>
- **Pull**: Success / Conflicts (list them)
- **Build**: Success / Failed
- **Device**: <serial or emulator name>
- **App installed**: Yes / No
- **App launched**: Yes / No
- **Android Studio**: Opening at <path>
```

## Constraints

- **NEVER hardcode** app ID, activity name, or APK path — always read from project files.
- **NEVER force-push, reset, or auto-resolve merge conflicts** — stop at Step 2 and report.
- **NEVER close or kill existing Android Studio windows** — only open a new one.
- **NEVER target a device without confirming** when multiple devices are connected.
- **ALWAYS use `./gradlew`** from the project root — do not use a globally installed Gradle.
- If `git pull` produces conflicts, stop before building or opening Android Studio.
