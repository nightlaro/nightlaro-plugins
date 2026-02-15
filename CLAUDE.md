# Knowledge Bank Plugin

## Auto-Capture (Hook)

When the Knowledge Bank hook injects a capture prompt after task completion,
follow its instructions to append an entry to the specified file. Generate
the entry entirely from conversation context. Do not ask the user questions.

If you see "Knowledge Bank is not configured", suggest the user run
`/knowledge-bank-setup`.

## /recall - Retrieval

### Slash Command

Users can invoke `/recall` directly with a query.

### Natural Language Triggers

Also trigger the `/recall` skill when the user explicitly asks to retrieve
past context. Recognized patterns:

**Direct references:**
- "Check/search/explore the knowledge bank..."
- "What does the knowledge bank say about..."

**Intent-based triggers:**
- "What did we do before about/with..."
- "Recall context about..."
- "Check past work on..."
- "Have we dealt with this before?"
- "What's the history on..."
- "Any prior context on..."
- "What do we know about..."

**NOT a trigger (normal questions, do not invoke /recall):**
- "How does this function work?" (asking about current code)
- "What should we do about X?" (asking for advice)
- "Why is this failing?" (debugging)

**The rule:** Only trigger when the user's intent is clearly to retrieve
past work context. When uncertain, do NOT trigger. Never proactively
search the knowledge bank on your own.
