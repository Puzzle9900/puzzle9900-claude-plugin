---
name: generic-setup-claude-plugin-locally
description: Set up a local Claude Code plugin globally so its skills are available in all sessions without needing /plugin update on every change.
type: generic
---

# generic-setup-claude-plugin-locally

## Context
Use this skill when you need to register a local Claude Code plugin directory as a globally available plugin. This is the right approach when:
- You are developing a plugin locally and want changes picked up automatically on the next session restart, without running any reinstall command.
- You want the plugin's skills available in every Claude Code session, regardless of the working directory.

Do **not** use this skill when:
- The plugin is already published to a remote marketplace and you just want to install it (use `/plugin update` instead).
- You only need the plugin in a single project (use project-scoped plugin configuration instead).

## Instructions

You are a Claude Code setup assistant. Follow the Steps below in order to register a local plugin directory as a globally available plugin. Ask the user for the plugin directory path if not already provided. Read the plugin's manifest files to infer the plugin name and marketplace name automatically.

## Steps

### 1. Gather required information
Ask the user (or infer from context):
- **Plugin directory path** — absolute path to the plugin repo (e.g. `/Users/you/projects/my-claude-plugin`)

Verify the path exists and contains a `.claude-plugin/` subdirectory. If it does not, stop and ask the user to verify the path.

### 2. Read and validate `.claude-plugin/plugin.json`
Read `<plugin-dir>/.claude-plugin/plugin.json`. Extract the **plugin name** from the `name` field. Then ensure:
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

- Both `source.path` and `installLocation` must point to the **same absolute directory path**.
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

- Set `installPath` to the **source directory** (the plugin repo path) — not a cache path. This ensures skill changes are picked up on the next session start with no reinstall.
- Set `scope` to `"user"` for global availability.
- Set `version` to the version string from `plugin.json` (Step 2).
- Use the current time in ISO 8601 UTC format for both `installedAt` and `lastUpdated`.

Preserve all existing entries in the `"plugins"` object. Do not add duplicate keys — if the key already exists, inform the user and ask whether to overwrite.

### 7. Verify and confirm
After all files are updated, re-read each modified JSON file and verify it is valid JSON (no syntax errors, no missing commas, no trailing commas). If any file has invalid JSON, fix it before proceeding.

Then tell the user:
- Which files were created or modified (list each file path)
- The plugin key: `<plugin-name>@<marketplace-name>`
- The skill prefix to use: `<plugin-name>:<skill-folder-name>` (e.g. `my-claude-plugin:my-skill`)
- To **open a new Claude Code session** for the changes to take effect — no reinstall command is needed
- Any new skill added to the plugin's `skills/` folder will appear automatically in the next new session

## Constraints
- Never use a cache path for `installPath` — always point to the source directory
- **Always update `known_marketplaces.json`** — omitting this step will cause the plugin to load only when Claude is started from the plugin's own directory, not globally
- Never overwrite existing entries in `installed_plugins.json` or `known_marketplaces.json` without user confirmation
- The key format in `enabledPlugins`, `installed_plugins.json`, and `known_marketplaces.json` must all use the same `<marketplace-name>` — it must match the `name` field in `.claude-plugin/marketplace.json`
- The `repository` field in `plugin.json` must be a string if present — remove it if it is an object or causes errors
- Do not modify any `env` fields in `settings.json`
- If `~/.claude/plugins/` directory does not exist, create it before writing any files inside it
- All timestamps must use ISO 8601 format with UTC timezone suffix `Z` (e.g. `"2026-01-15T10:30:00.000Z"`)
