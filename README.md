# puzzle9900-claude-plugin for Claude Code

A Claude Code plugin that provides custom skills, agents, and hooks to extend your development workflow.

## What is This?

This is a **Claude Code plugin** that provides custom skills, agents, and hooks. It integrates directly into Claude Code to enhance your AI-assisted development experience.

### Plugin vs Marketplace Plugin

| Type | Description |
|------|-------------|
| **Plugin** | A local directory that extends Claude Code with custom functionality |
| **Marketplace Plugin** | The same plugin, but published to a marketplace for discovery and installation |

This repository serves as both:
- A **standalone plugin** you can use locally during development
- A **marketplace plugin** that can be installed via Claude Code's plugin system

## Installation

### Option 1: Install from Marketplace (Recommended)

```bash
# Add the marketplace
/plugin marketplace add puzzle9900/puzzle9900-claude-plugin

# Install the plugin
/plugin install puzzle9900-claude-plugin
```

### Option 2: Local Development

Clone and use directly:

```bash
git clone https://github.com/Puzzle9900/puzzle9900-claude-plugin.git
cd your-project
claude --plugin-dir ../puzzle9900-claude-plugin
```

### Option 3: Global Install for Local Development

Register the plugin globally so its skills are available in every Claude Code session, with changes picked up automatically on each restart — no reinstall needed.

#### Automated setup

Use the built-in skill to configure everything:

```bash
/puzzle9900-claude-plugin:generic-setup-claude-plugin-locally
```

It will ask for your plugin directory path and handle all the registration steps below.

#### Manual setup

If you prefer to set things up manually, follow these steps:

**1. Create the plugins directory** (if it doesn't exist):

```bash
mkdir -p ~/.claude/plugins
```

**2. Register the marketplace in `~/.claude/settings.json`:**

Add these entries (merge into your existing file — don't overwrite other keys):

```json
{
  "enabledPlugins": {
    "puzzle9900-claude-plugin@puzzle9900-plugins": true
  },
  "extraKnownMarketplaces": {
    "puzzle9900-plugins": {
      "source": {
        "source": "directory",
        "path": "/absolute/path/to/puzzle9900-claude-plugin"
      }
    }
  }
}
```

**3. Register in `~/.claude/plugins/known_marketplaces.json`:**

This is the step most setups miss — without it the plugin silently fails to load outside the plugin directory.

```json
{
  "puzzle9900-plugins": {
    "source": {
      "source": "directory",
      "path": "/absolute/path/to/puzzle9900-claude-plugin"
    },
    "installLocation": "/absolute/path/to/puzzle9900-claude-plugin",
    "lastUpdated": "2026-01-15T10:30:00.000Z"
  }
}
```

**4. Register in `~/.claude/plugins/installed_plugins.json`:**

```json
{
  "version": 2,
  "plugins": {
    "puzzle9900-claude-plugin@puzzle9900-plugins": [
      {
        "scope": "user",
        "installPath": "/absolute/path/to/puzzle9900-claude-plugin",
        "version": "1.1.0",
        "installedAt": "2026-01-15T10:30:00.000Z",
        "lastUpdated": "2026-01-15T10:30:00.000Z"
      }
    ]
  }
}
```

> **Important:** Set `installPath` to the cloned repo path (not a cache path) so changes are picked up automatically.

**5. Restart Claude Code** — skills are available immediately with no reinstall needed. Any new skill added to `skills/` will appear in the next session.

## Usage

Once installed, access skills with the `/puzzle9900-claude-plugin:` prefix:

```bash
# List available skills
/puzzle9900-claude-plugin:generic-help

# Example skills (add your own!)
/puzzle9900-claude-plugin:generic-spec
/puzzle9900-claude-plugin:generic-spec-capture
/puzzle9900-claude-plugin:generic-contributor-jira-context
```

## Plugin Structure

```
puzzle9900-claude-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (metadata)
├── skills/                   # Custom slash commands
│   └── example/
│       └── SKILL.md
├── agents/                   # Specialized AI agents
│   └── example-agent.md
├── hooks/                    # Event handlers
│   └── hooks.json
├── .mcp.json                 # MCP server configurations (optional)
├── .lsp.json                 # LSP server configurations (optional)
└── README.md
```

## Creating Custom Skills

Add a new skill by creating a directory in `skills/`:

```
skills/
└── my-skill/
    └── SKILL.md
```

Example `SKILL.md`:

```markdown
---
description: Description shown in /help
---

Instructions for Claude when this skill is invoked.
Include context, steps, and expected behavior.
```

## Creating Custom Agents

Add agents in the `agents/` directory:

```markdown
<!-- agents/code-reviewer.md -->
---
name: my-code-reviewer
description: Reviews code for best practices
---

You are a code review specialist.
Review code for best practices, patterns, and potential issues.
```

## Creating Hooks

Define hooks in `hooks/hooks.json`:

```json
{
  "hooks": {
    "pre-tool-use": [
      {
        "tool": "Bash",
        "command": "echo 'Running command...'"
      }
    ],
    "post-tool-use": [
      {
        "tool": "Write",
        "command": "echo 'File written: $TOOL_INPUT_file_path'"
      }
    ]
  }
}
```

## Development

### Testing Your Plugin

```bash
# Run Claude Code with this plugin loaded
claude --plugin-dir .

# Reload plugins after changes (inside Claude Code)
/reload-plugins
```

### Versioning

Update `plugin.json` version following semantic versioning:
- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

## Publishing to Marketplace

### Create a Marketplace

To distribute multiple plugins, create a `marketplace.json`:

```json
{
  "name": "puzzle9900-plugins",
  "owner": {
    "name": "Puzzle9900 Team",
    "email": "hello@puzzle9900.com"
  },
  "plugins": [
    {
      "name": "puzzle9900-claude-plugin",
      "source": "./",
      "description": "puzzle9900-claude-plugin",
      "version": "1.0.0"
    }
  ]
}
```

### Submit to Official Marketplace

Submit your plugin to Anthropic's official marketplace:
- **Claude.ai**: https://claude.ai/settings/plugins/submit
- **Console**: https://platform.claude.com/plugins/submit

## Contributing

1. Fork and clone the repository
2. Set up the plugin globally using **Option 3** above (or run `/puzzle9900-claude-plugin:generic-setup-claude-plugin-locally`)
3. Create a feature branch
4. Add your skills, agents, or hooks
5. Open a new Claude Code session — your changes are picked up automatically
6. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.
