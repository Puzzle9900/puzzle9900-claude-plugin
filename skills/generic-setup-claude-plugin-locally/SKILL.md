---
name: generic-setup-claude-plugin-locally
description: Set up a local Claude Code plugin globally using a symlink so changes are picked up on every session restart with no version bump or reinstall.
type: generic
---

# generic-setup-claude-plugin-locally

## Context
Use this skill when you need to register a local Claude Code plugin directory as a globally available plugin **for active development**.

**Why a symlink?** Claude Code always copies marketplace plugins into a version-stamped cache directory (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`). Even if `installPath` in `installed_plugins.json` points to your source directory, Claude Code reads from the cache. If you add or change skills without bumping the version, new sessions keep loading the stale cache. The symlink approach replaces the cache directory with a symbolic link to your source repo, so Claude Code reads live files every time.

Use this skill when:
- You are developing a plugin locally and want every change (new skills, edited skills, new agents) picked up on the next session restart — no version bump, no `plugin update`, no cache clearing.
- You want the plugin's skills available in every Claude Code session, regardless of the working directory.

Do **not** use this skill when:
- The plugin is already published to a remote marketplace and you just want to install it (use `claude plugin install` instead).
- You only need the plugin in a single project (use `claude --plugin-dir <path>` instead).

## Instructions

You are a Claude Code setup assistant. The setup process is automated by a `scripts/setup-local.sh` script that lives inside the plugin repository. Your job is to validate prerequisites, run the script, and confirm the result.

## Steps

### 1. Determine the plugin directory path
Ask the user (or infer from context) for the **absolute path** to the plugin repo (e.g. `/Users/you/projects/my-claude-plugin`).

Verify the path exists and contains both:
- A `.claude-plugin/` subdirectory
- A `scripts/setup-local.sh` file

If `.claude-plugin/` does not exist, stop and ask the user to verify the path.

If `scripts/setup-local.sh` does not exist, stop and tell the user: "This plugin does not include a `scripts/setup-local.sh` setup script. You can copy one from a plugin that has it, or perform the setup manually." Do not attempt to create the script or perform the steps by hand.

### 2. Validate plugin manifests
Read `<plugin-dir>/.claude-plugin/plugin.json` and ensure:
- `name` is a non-empty string
- `version` is a valid semver string (e.g. `"1.0.0"`)
- `description` is present and non-empty
- `repository` field, if present, is a **string** URL — not an object. If it is an object, warn the user and remove it before proceeding.

Read `<plugin-dir>/.claude-plugin/marketplace.json` and ensure:
- `name` is a non-empty string
- The `plugins` array contains an entry whose `name` matches the plugin name from `plugin.json`

If either file is missing or invalid, stop and tell the user what needs to be fixed before running setup.

### 3. Run the setup script
Execute the script from the plugin directory:

```bash
bash <plugin-dir>/scripts/setup-local.sh
```

The script automates all registration steps:
1. Reads plugin name, version, and marketplace name from the manifest files
2. Updates `~/.claude/settings.json` — adds `enabledPlugins` and `extraKnownMarketplaces` entries
3. Updates `~/.claude/plugins/known_marketplaces.json` — registers the marketplace source
4. Updates `~/.claude/plugins/installed_plugins.json` — registers the plugin with scope `"user"`
5. Creates a cache symlink at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` pointing to the source directory

Watch the script output for any `ERROR` lines. If the script exits with a non-zero status, report the error to the user and stop.

### 4. Verify the result
After the script completes successfully, confirm it worked by running **all** of these checks:

#### 4a. Cache symlink
```bash
ls -la ~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/
```
The version directory should be a symlink (`->`) pointing to the plugin source directory.

#### 4b. Registered paths point to the correct directory
Read `~/.claude/plugins/known_marketplaces.json` and `~/.claude/settings.json` and verify that the `path` value for the marketplace matches the **plugin root directory** (the directory containing `.claude-plugin/`). A common failure mode is the path pointing one level too high (the parent directory) or one level too low (a subdirectory like `scripts/`).

If a path is wrong:
1. Tell the user which file has the wrong path and what it should be.
2. Re-run the setup script — the fixed script will overwrite stale values.
3. If the script itself produced the wrong path, the bug is in the `PLUGIN_DIR` resolution at the top of `setup-local.sh`. The correct line is:
   ```bash
   PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
   ```
   because the script lives in `scripts/` and needs to resolve to the **parent** directory.

#### 4c. Marketplace file is reachable
Verify that `<registered-path>/.claude-plugin/marketplace.json` actually exists. If it does not, the registered path is wrong — go back to step 4b.

Then tell the user:
- The plugin key: `<plugin-name>@<marketplace-name>` (shown in the script output)
- The skill prefix to use: `<plugin-name>:<skill-folder-name>`
- To **open a new Claude Code session** for the changes to take effect
- **Any change to the plugin repo (new skills, edited skills, git pull) will be picked up on the next session restart — no version bump or reinstall needed**

## What the script does (reference)

This section documents the registration steps for anyone maintaining the script or debugging issues. You do not need to perform these steps — the script handles them.

| Step | File | What is written |
|------|------|-----------------|
| Settings | `~/.claude/settings.json` | `enabledPlugins["<plugin>@<marketplace>"] = true` and `extraKnownMarketplaces["<marketplace>"]` with directory source |
| Known marketplaces | `~/.claude/plugins/known_marketplaces.json` | Marketplace entry with `source`, `installLocation`, and `lastUpdated` |
| Installed plugins | `~/.claude/plugins/installed_plugins.json` | Plugin entry under `"plugins"` with scope `"user"`, version, and timestamps (file uses `"version": 2` wrapper) |
| Cache symlink | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` | Symlink to the plugin source directory — this is what makes live development work |

**Critical:** The `known_marketplaces.json` and cache symlink steps are the ones most manual setups miss. Without `known_marketplaces.json`, the plugin silently fails to load in new sessions. Without the symlink, Claude Code reads from a stale cache copy.

## Constraints
- Do not perform the setup steps manually — always use the `scripts/setup-local.sh` script
- Do not modify any `env` fields in `settings.json`
- If the symlink target directory is moved or deleted, the plugin will fail to load — warn the user not to move the repo without re-running setup
- The version in `plugin.json` does not need to be bumped for local development — the symlink bypasses version-based cache invalidation entirely
