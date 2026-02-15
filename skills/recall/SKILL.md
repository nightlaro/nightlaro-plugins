---
name: recall
description: Search the knowledge bank for past context relevant to a query
argument-hint: "[query]"
disable-model-invocation: false
user-invocable: true
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
---

# Knowledge Bank Recall

Search the knowledge bank for context relevant to the user's query.

## Configuration

Read `~/.config/knowledge-bank/config.json` to find the knowledge bank directory.
If the config file doesn't exist, respond:
"Knowledge Bank is not configured. Run /knowledge-bank-setup first."

## Determine Scope

- **Default:** Search only files matching `*-<current-project>.md`
  (derive project name from the current working directory basename)
- **All projects:** If the user said "all projects", "search everything",
  or "across projects", search all `.md` files in the knowledge bank directory

## Search Strategy: Exponential Time Windows

Search in expanding time windows. Stop as soon as you have enough context
to answer the query. Today's date is available from the system.

```
Window 1: Today
Window 2: Yesterday (2 days total)
Window 3: Past 7 days
Window 4: Past 30 days
Window 5: Past 90 days
Window 6: All files
```

At each window:

1. Use Glob to find files matching the date range and project scope
   - Files are named `YYYY-MM-DD-<project>.md`
   - Filter by comparing the date prefix against the window bounds
2. Use Grep to search for keywords from the query across those files
3. Use Read to load relevant entries from matching files
4. Evaluate: do you have enough context to answer the query?
   - If **YES**: stop expanding, proceed to output
   - If **NO**: expand to the next window
   - If you've exhausted all windows with no results, report that clearly

## Output Format

Return a concise summary in this format:

```
## Knowledge Bank Recall: "<original query>"

**Found N relevant entries** (searched <window description>, <project> project)

### Summary:
<3-8 bullet points synthesizing the relevant information>

### Key decisions & reasoning:
<bullet points focused on WHY things were done, not just what>

### Source entries:
<list of source file names and entry timestamps for reference>
```

## Important

- Be thorough but concise. Summarize, do not dump raw entries.
- Focus on information relevant to the query, skip unrelated entries.
- If no relevant entries found after searching all windows, say so clearly
  and suggest the user try broader search terms or search all projects.
