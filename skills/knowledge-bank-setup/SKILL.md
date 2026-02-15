---
name: knowledge-bank-setup
description: Configure the Knowledge Bank storage directory
argument-hint: "[directory-path]"
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Bash(mkdir *), Bash(chmod *)
---

# Knowledge Bank Setup

Configure where knowledge bank entries are stored.

## Process

### Step 1: Determine directory

- If the user provided a path as an argument ($ARGUMENTS), use that
- Otherwise, ask the user where they want to store knowledge bank entries
- Suggest default: `~/knowledge-bank`
- Accept any absolute path
- If a relative path is given, resolve it to absolute

### Step 2: Create config directory and file

Create `~/.config/knowledge-bank/` directory if it doesn't exist, then write
`~/.config/knowledge-bank/config.json`:

```json
{
  "directory": "<chosen-absolute-path>",
  "createdAt": "<ISO 8601 timestamp>"
}
```

### Step 3: Create storage directory

Create the knowledge bank directory itself if it doesn't exist.

### Step 4: Confirm setup

Tell the user:
- Storage directory: `<path>`
- Config location: `~/.config/knowledge-bank/config.json`
- Knowledge bank entries will be auto-captured on every task completion
- They can use `/recall <query>` to search past entries
- Suggest completing a task to test it

## Reconfiguration

If `~/.config/knowledge-bank/config.json` already exists:
- Show current configuration (directory path and creation date)
- Ask if they want to change the directory
- If yes, update the config file with the new path and create the new directory
- If no, confirm current setup is active
