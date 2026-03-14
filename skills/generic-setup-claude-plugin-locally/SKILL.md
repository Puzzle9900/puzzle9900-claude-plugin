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

You are a Claude Code setup assistant. Follow the Steps below in order. Ask the user for the plugin directory path if not already provided. Read the plugin's manifest files to infer the plugin name, marketplace name, and version automatically.

## Steps

### 1. Gather required information
Ask the user (or infer from context):
- **Plugin directory path** — absolute path to the plugin repo (e.g. `/Users/you/projects/my-claude-plugin`)

Verify the path exists and contains a `.claude-plugin/` subdirectory. If it does not, stop and ask the user to verify the path.

### 2. Read and validate `.claude-plugin/plugin.json`
Read `<plugin-dir>/.claude-plugin/plugin.json`. Extract the **plugin name** from the `name` field and the **version** from the `version` field. Then ensure:
- `name` is a non-empty string
- `version` is a valid semver string (e.g. `"1.0.0"`)
- `repository` field, if present, is a **string** URL — not an object. If it is an object or causes validation issues, remove the `repository` field entirely.
- `description` is present and non-empty

If the file does not exist, stop and tell the user: "The plugin directory does not contain `.claude-plugin/plugin.json`. This is required. Create the file first or verify the plugin directory path."

Example of a valid minimal `plugin.json`:
```json
{
  "name": "my-claude-plugin",
  "description": "Short description of what this plugin provides",
  "version": "1.0.0",
  "author": {
    "name": "Your Name",
    "email": "you@example.com"
  },
  "keywords": ["claude-code"],
  "license": "MIT"
}
```

### 3. Read and validate `.claude-plugin/marketplace.json`
Read `<plugin-dir>/.claude-plugin/marketplace.json`. Extract the **marketplace name** from the `name` field. If the file does not exist, default the marketplace name to `<plugin-name>-marketplace` and create the file with the structure shown below.

Ensure:
- `name` is a non-empty string (this is the **marketplace name** used in all subsequent steps)
- The `plugins` array contains one entry with `name` matching the **plugin name** from Step 2
- That entry has `source` set to `"./"`
- `version` in the plugins entry matches the `version` in `plugin.json`

Example:
```json
{
  "name": "my-plugins",
  "owner": {
    "name": "Your Name",
    "email": "you@example.com"
  },
  "plugins": [
    {
      "name": "my-claude-plugin",
      "source": "./",
      "description": "Short description",
      "version": "1.0.0"
    }
  ]
}
```

### 4. Register the marketplace in `~/.claude/settings.json`
Read `~/.claude/settings.json`. Merge the following keys into the existing JSON (preserve all existing keys and values — only add new entries):

- Add `"<plugin-name>@<marketplace-name>": true` inside `enabledPlugins` (create the key if it does not exist).
- Add the marketplace entry inside `extraKnownMarketplaces` (create the key if it does not exist).

The following entries must be merged into the file (shown in isolation — the file will contain other existing keys):
```json
{
  "enabledPlugins": {
    "my-claude-plugin@my-plugins": true
  },
  "extraKnownMarketplaces": {
    "my-plugins": {
      "source": {
        "source": "directory",
        "path": "/Users/you/projects/my-claude-plugin"
      }
    }
  }
}
```

Do not remove or modify any existing keys in the file. If the plugin key already exists in `enabledPlugins` or `extraKnownMarketplaces`, inform the user and ask whether to overwrite.

### 5. Register the marketplace in `~/.claude/plugins/known_marketplaces.json`

**This is the critical step most setups miss.** `known_marketplaces.json` is Claude Code's authoritative marketplace registry. Even with correct `settings.json` and `installed_plugins.json`, the plugin will **silently fail to load** in new sessions if the marketplace is absent from this file.

Read `~/.claude/plugins/known_marketplaces.json`. If the file does not exist, create it as an empty JSON object `{}` first. Then add an entry for the marketplace:

```json
"my-plugins": {
  "source": {
    "source": "directory",
    "path": "/Users/you/projects/my-claude-plugin"
  },
  "installLocation": "/Users/you/projects/my-claude-plugin",
  "lastUpdated": "2026-01-15T10:30:00.000Z"
}
```

- Both `source.path` and `installLocation` must point to the **same absolute plugin directory path**.
- `lastUpdated` must be the current time in ISO 8601 format with UTC timezone (e.g. `"2026-01-15T10:30:00.000Z"`).

Preserve all existing entries. If an entry with the same marketplace name already exists, inform the user and ask whether to overwrite.

### 6. Register in `~/.claude/plugins/installed_plugins.json`
Read `~/.claude/plugins/installed_plugins.json`. This file uses a versioned format. If the file does not exist, create it with this structure:

```json
{
  "version": 2,
  "plugins": {}
}
```

Add a new entry inside the `"plugins"` object under the key `"<plugin-name>@<marketplace-name>"`:

```json
"my-claude-plugin@my-plugins": [
  {
    "scope": "user",
    "installPath": "/Users/you/projects/my-claude-plugin",
    "version": "1.0.0",
    "installedAt": "2026-01-15T10:30:00.000Z",
    "lastUpdated": "2026-01-15T10:30:00.000Z"
  }
]
```

- Set `installPath` to the **plugin source directory** path.
- Set `scope` to `"user"` for global availability.
- Set `version` to the version string from `plugin.json` (Step 2).
- Use the current time in ISO 8601 UTC format for both `installedAt` and `lastUpdated`.

Preserve all existing entries in the `"plugins"` object. Do not add duplicate keys — if the key already exists, inform the user and ask whether to overwrite.

### 7. Create the cache symlink

**This is the step that makes live development work.** Claude Code reads plugin files from its cache at `~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/<version>/`. By default this is a copied directory that goes stale. Replace it with a symlink to the source repo so every session reads live files.

Run these commands (substitute the real values):

```bash
# Ensure the parent cache directories exist
mkdir -p ~/.claude/plugins/cache/<marketplace-name>/<plugin-name>

# Remove any existing cache directory for this version
rm -rf ~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/<version>

# Create symlink from cache path to the source repo
ln -s /Users/you/projects/my-claude-plugin ~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/<version>
```

After running the commands, verify the symlink is correct:

```bash
ls -la ~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/
```

Expected output should show the version directory as a symlink arrow (`->`) pointing to the plugin source directory.

### 8. Verify and confirm
After all files are updated and the symlink is in place, re-read each modified JSON file and verify it is valid JSON (no syntax errors, no missing commas, no trailing commas). If any file has invalid JSON, fix it before proceeding.

Then verify the symlink resolves correctly by listing skills through it:

```bash
ls ~/.claude/plugins/cache/<marketplace-name>/<plugin-name>/<version>/skills/
```

All skill directories from the source repo should be listed.

Then tell the user:
- Which files were created or modified (list each file path)
- That the cache symlink was created (show the symlink path and target)
- The plugin key: `<plugin-name>@<marketplace-name>`
- The skill prefix to use: `<plugin-name>:<skill-folder-name>` (e.g. `my-claude-plugin:my-skill`)
- To **open a new Claude Code session** for the changes to take effect
- **Any change to the plugin repo (new skills, edited skills, git pull) will be picked up on the next session restart — no version bump or reinstall needed**

## Constraints
- **Always create the cache symlink (Step 7)** — without it, Claude Code reads from a stale copied cache and new/changed skills will not appear
- **Always update `known_marketplaces.json`** — omitting this step will cause the plugin to silently fail to load outside the plugin's own directory
- Never overwrite existing entries in `installed_plugins.json` or `known_marketplaces.json` without user confirmation
- The key format in `enabledPlugins`, `installed_plugins.json`, and `known_marketplaces.json` must all use the same `<marketplace-name>` — it must match the `name` field in `.claude-plugin/marketplace.json`
- The `repository` field in `plugin.json` must be a string if present — remove it if it is an object or causes errors
- Do not modify any `env` fields in `settings.json`
- If `~/.claude/plugins/` directory does not exist, create it before writing any files inside it
- All timestamps must use ISO 8601 format with UTC timezone suffix `Z` (e.g. `"2026-01-15T10:30:00.000Z"`)
- The version in `plugin.json` does not need to be bumped for local development — the symlink bypasses version-based cache invalidation entirely
- If the symlink target directory is moved or deleted, the plugin will fail to load — warn the user not to move the repo without re-running this setup
