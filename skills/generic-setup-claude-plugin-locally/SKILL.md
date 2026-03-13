---
name: generic-setup-claude-plugin-locally
description: Set up a local Claude Code plugin globally so its skills are available in all sessions without needing /plugin update on every change.
type: generic
---

# generic-setup-claude-plugin-locally

## Context
Use this skill to install a local Claude Code plugin directory globally so its skills are immediately available across all Claude Code sessions. This approach skips the plugin cache — changes to skill files are picked up on the next session restart with no reinstall required.

## Instructions

You are a Claude Code setup assistant. Follow these steps in order to register a local plugin directory as a globally available plugin. Ask the user for the plugin directory path and plugin name if not already provided.

---

## Steps

### 1. Gather required information
Ask the user (or infer from context):
- **Plugin directory path** — absolute path to the plugin repo (e.g. `/Users/you/projects/my-claude-plugin`)
- **Plugin name** — the `name` field in `.claude-plugin/plugin.json` (e.g. `my-claude-plugin`)
- **Marketplace name** — a short identifier for the local marketplace (e.g. `my-plugins`). Defaults to `<plugin-name>-marketplace` if not specified.

### 2. Validate `.claude-plugin/plugin.json`
Read `<plugin-dir>/.claude-plugin/plugin.json`. Ensure:
- `name` matches the plugin name
- `version` is a valid semver string (e.g. `"1.0.0"`)
- `repository` field, if present, is a **string** URL — not an object. Remove it entirely if it causes validation errors.
- No project-specific content remains

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

### 3. Validate `.claude-plugin/marketplace.json`
Read `<plugin-dir>/.claude-plugin/marketplace.json`. Ensure:
- `name` matches the **marketplace name** chosen in Step 1
- The `plugins` array contains one entry with `name` matching the **plugin name**
- `source` is `"./"`

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
Read `~/.claude/settings.json`. Add the marketplace to `extraKnownMarketplaces` and enable the plugin in `enabledPlugins`:

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

Preserve all existing keys — only add the new entries.

### 5. Register the marketplace in `~/.claude/plugins/known_marketplaces.json`

**This is the critical step most setups miss.** `known_marketplaces.json` is Claude Code's authoritative marketplace registry. Even with correct `settings.json` and `installed_plugins.json`, the plugin will **silently fail to load** in new sessions if the marketplace is absent from this file.

Read `~/.claude/plugins/known_marketplaces.json`. Add an entry for the marketplace:

```json
"my-plugins": {
  "source": {
    "source": "directory",
    "path": "/Users/you/projects/my-claude-plugin"
  },
  "installLocation": "/Users/you/projects/my-claude-plugin",
  "lastUpdated": "<current ISO timestamp>"
}
```

Both `source.path` and `installLocation` must point to the **same source directory**.

Preserve all existing entries. Do not overwrite or remove any existing marketplace entries.

### 6. Register in `~/.claude/plugins/installed_plugins.json`
Read `~/.claude/plugins/installed_plugins.json`. Add an entry under the key `<plugin-name>@<marketplace-name>`:

```json
"my-claude-plugin@my-plugins": [
  {
    "scope": "user",
    "installPath": "/Users/you/projects/my-claude-plugin",
    "version": "1.0.0",
    "installedAt": "<current ISO timestamp>",
    "lastUpdated": "<current ISO timestamp>"
  }
]
```

Set `installPath` to the **source directory** — not a cache path. This ensures skill changes are picked up on the next session start with no reinstall.

Preserve all existing entries. Do not add duplicate keys.

### 7. Confirm and instruct the user
After all files are updated, tell the user:
- Which files were changed (settings.json, known_marketplaces.json, installed_plugins.json)
- The skill prefix to use (e.g. `puzzle9900-claude-plugin:my-skill`)
- To **open a new Claude Code session** — skills are available immediately with no reinstall needed
- Any new skill added to the plugin's `skills/` folder will appear automatically in the next new session

---

## Constraints
- Never use a cache path for `installPath` — always point to the source directory
- **Always update `known_marketplaces.json`** — omitting this step will cause the plugin to load only when Claude is started from the plugin's own directory, not globally
- Never overwrite existing entries in `installed_plugins.json` or `known_marketplaces.json`
- The key format in `enabledPlugins`, `installed_plugins.json`, and `known_marketplaces.json` must all use the same `<marketplace-name>` — it must match the `name` field in `.claude-plugin/marketplace.json`
- The `repository` field in `plugin.json` must be a string if present — remove it if unsure
- Do not modify any `env` fields in `settings.json`
