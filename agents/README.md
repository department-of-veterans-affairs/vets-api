# Agents

This directory contains AI agent skills for use with AI coding assistants such as Claude Code and GitHub Copilot.

## What are skills?

Skills are reusable, context-rich prompts that teach your AI assistant how to perform specific tasks in this codebase. Each skill lives in its own folder and includes a `SKILL.md` file with instructions, context, and any supporting scripts.

## Directory structure

```
agents/
└── skills/
    └── va-form-upload/       # Skill folder name
        ├── SKILL.md          # Skill instructions read by the AI assistant
        └── scripts/          # Supporting scripts referenced by the skill
```

## How to use a skill

Copy the skill folder you want into the skills directory for your AI assistant:

### Claude Code

```bash
cp -r agents/skills/va-form-upload ~/.claude/skills/va-form-upload
```

Skills are picked up automatically. You can also reference them explicitly by name in your prompt (e.g., "use the va-form-upload-api skill to add form 20-10208").

### GitHub Copilot

```bash
cp -r agents/skills/va-form-upload .github/copilot/skills/va-form-upload
```

Copilot reads skills from `.github/copilot/skills/` in the repository root.

## Available skills

| Skill | Description |
|-------|-------------|
| [`va-form-upload`](skills/va-form-upload/SKILL.md) | Add new VA forms to the Form Upload Tool backend (vets-api) |
