# Waonder Cloud Plugin for Claude Code

A Claude Code plugin that extends your development workflow with Waonder-specific capabilities—an AI-powered travel companion platform with location-aware RAG (Retrieval-Augmented Generation).

## What is This?

This is a **Claude Code plugin** that provides custom skills, agents, and hooks for developing and maintaining the Waonder ecosystem. It integrates directly into Claude Code to enhance your AI-assisted development experience.

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
/plugin marketplace add waonder/waonder-claude-plugin

# Install the plugin
/plugin install waonder-cloud@waonder-claude-plugin
```

### Option 2: Local Development

Clone and use directly:

```bash
git clone https://github.com/waonder/waonder-claude-plugin.git
cd your-project
claude --plugin-dir ../waonder-claude-plugin
```

### Option 3: Add to Project

Copy the plugin to your project's `.claude/plugins/` directory:

```bash
cp -r waonder-claude-plugin ~/.claude/plugins/
```

## Usage

Once installed, access Waonder skills with the `/waonder-cloud:` prefix:

```bash
# List available skills
/waonder-cloud:help

# Example skills (add your own!)
/waonder-cloud:setup-dev      # Set up development environment
/waonder-cloud:run-etl        # Execute ETL pipelines
/waonder-cloud:test-contexts  # Test location context retrieval
```

## Plugin Structure

```
waonder-claude-plugin/
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
name: waonder-code-reviewer
description: Reviews code for Waonder best practices
---

You are a code review specialist for the Waonder platform.
Review code for:
- NestJS module patterns
- TypeORM entity design
- PostGIS spatial queries
- RAG pipeline implementation
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
  "name": "waonder-plugins",
  "owner": {
    "name": "Waonder Team",
    "email": "hello@waonder.com"
  },
  "plugins": [
    {
      "name": "waonder-cloud",
      "source": "./",
      "description": "Waonder development plugin",
      "version": "1.0.0"
    }
  ]
}
```

### Submit to Official Marketplace

Submit your plugin to Anthropic's official marketplace:
- **Claude.ai**: https://claude.ai/settings/plugins/submit
- **Console**: https://platform.claude.com/plugins/submit

## Waonder Ecosystem

This plugin is designed for the Waonder platform:

- **waonder-backend**: NestJS API with PostGIS, vector search, and RAG
- **waonder-web-page**: Next.js landing page
- **waonder-react-native**: Mobile application
- **waonder-android**: Native Android app

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your skills/agents/hooks
4. Test with `claude --plugin-dir .`
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Built with Claude Code for the Waonder team.
