#!/bin/bash

# Knowledge Bank - Auto-capture hook
# Fires on TaskCompleted events. Injects a prompt telling Claude to
# generate and append a knowledge bank entry.

# Read the hook event JSON from stdin
input=$(cat)

# JSON parsing helper: prefer jq, fallback to python3
json_get() {
  local json="$1"
  local path="$2"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r "$path"
  elif command -v python3 &>/dev/null; then
    echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys = '$path'.strip('.').split('.')
val = data
for k in keys:
    if val is None:
        break
    if isinstance(val, dict):
        val = val.get(k)
    else:
        val = None
        break
print(val if val is not None else 'Unknown task')
"
  else
    echo "ERROR: knowledge-bank-hook requires jq or python3. Neither found."
    exit 0
  fi
}

# Read config
config_file="$HOME/.config/knowledge-bank/config.json"
if [ ! -f "$config_file" ]; then
  echo "Knowledge Bank is not configured. Run /knowledge-bank-setup to set your storage directory."
  exit 0
fi

config=$(cat "$config_file")
bank_dir=$(json_get "$config" '.directory')

if [ -z "$bank_dir" ] || [ "$bank_dir" = "null" ]; then
  echo "Knowledge Bank directory not set in config. Run /knowledge-bank-setup to configure."
  exit 0
fi

project=$(basename "$(json_get "$input" '.cwd')")
today=$(date +%Y-%m-%d)
file_path="${bank_dir}/${today}-${project}.md"
timestamp=$(date +%H:%M)

# Output the capture prompt - injected into Claude's context
cat <<PROMPT
KNOWLEDGE BANK CAPTURE - Append an entry to the knowledge bank for the task you just completed.

Target file: ${file_path}
If the file does not exist, create it with a heading: # Knowledge Bank - ${project} - ${today}

Append the following markdown entry:

---

## [${timestamp}] Task: <task subject from the completed task>

**What happened:**
<2-4 bullet points summarizing what was done>

**Why these decisions:**
<2-3 bullets explaining reasoning behind key choices made>

**Files changed:**
<list each file changed with a one-line description of the change>

**Context for future readers:**
<1-3 bullets: gotchas, edge cases, dependencies, things not obvious from code>

IMPORTANT: Generate this entirely from your conversation context. Do NOT ask the user any questions. Write the entry silently.
PROMPT
