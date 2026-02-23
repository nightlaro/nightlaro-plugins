---
name: review-pr-feedback
description: Fetch unresolved PR feedback and CI errors, dispatch parallel sub-agents to analyze and fix each one
argument-hint: "[pr-number]"
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash(gh:*), Read, Grep, Glob, Edit, Write, Task, AskUserQuestion
---

# Review PR Feedback

Fetch unresolved PR review feedback and CI errors for the current branch's pull request, then dispatch parallel sub-agents to analyze each piece of feedback and apply fixes where valid.

## Step 1: Resolve the Pull Request

If the user provided a PR number as $ARGUMENTS, use that number.

Otherwise, auto-detect the current branch's open PR:

```bash
gh pr view --json number,title,headRefName,url
```

If no open PR is found for the current branch, tell the user:
"No open PR found for the current branch. Run `/review-pr-feedback <pr-number>` to specify one explicitly."
Then stop.

Extract and store: `pr_number`, `pr_title`, `branch_name`, `pr_url`.

## Step 2: Fetch Unresolved Review Threads

Use the GitHub GraphQL API to fetch all review threads and filter to unresolved ones:

```bash
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      title
      headRefName
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 10) {
            nodes {
              body
              author { login }
              path
              line
              diffHunk
            }
          }
        }
      }
    }
  }
}' -F owner='{owner}' -F repo='{repo}' -F pr={pr_number}
```

To determine `owner` and `repo`, run:
```bash
gh repo view --json owner,name
```

From the response, filter to threads where `isResolved` is `false`. For each unresolved thread:
- The **first comment** is the feedback (the reviewer's original comment)
- Subsequent comments are discussion context (include them for the sub-agent)
- Extract: `author`, `body`, `path`, `line`, `diffHunk`

If there are zero unresolved threads, report "No unresolved review threads found" but continue to Step 3 (there may still be CI failures).

## Step 3: Fetch CI Failures

Check for failed CI checks on the PR:

```bash
gh pr checks {pr_number} --json name,state,detailsUrl
```

For each check where `state` is `FAILURE`:
- Fetch the failed check's log output. Use the Actions run ID from the details URL:
  ```bash
  gh run view {run_id} --log-failed
  ```
- Extract the error message, file path, and line number from the log output
- Summarize the CI error concisely (the full log is too verbose for a sub-agent prompt)

If no CI failures, report "No CI failures found" but continue (there may be review feedback).

If BOTH review threads and CI failures are empty, tell the user:
"No unresolved review feedback or CI failures found for PR #{pr_number}. Nothing to address."
Then stop.

## Step 4: Triage and Deduplicate

Before dispatching sub-agents, triage the collected feedback:

1. **Group related feedback**: If multiple reviewers commented on the same file about the same issue, group them into a single work item. Include all reviewer comments in the sub-agent prompt.

2. **Link CI errors to feedback**: If a CI error points to the same file/issue as a review comment, combine them into one work item. The CI error provides concrete evidence for the reviewer's feedback.

3. **Present the plan to the user**: Show a numbered list of work items:
   ```
   Found {N} unresolved feedbacks and {M} CI errors -> {X} unique work items:

   1. [FEEDBACK] {file_path}:{line} -- {one-line summary} (by @{author})
   2. [CI ERROR] {check_name} -- {one-line error summary}
   3. [FEEDBACK+CI] {file_path}:{line} -- {summary} (feedback by @{author}, confirmed by CI)
   ```

   Do NOT ask for confirmation -- proceed directly to dispatching sub-agents.

## Step 5: Dispatch Parallel Sub-Agents

For EACH work item from Step 4, dispatch a sub-agent using the Task tool with `subagent_type: "principal-engineer"`.

**CRITICAL: Dispatch ALL sub-agents in a single message with multiple Task tool calls.** This ensures they run in parallel, not sequentially. If there are 4 work items, you must make 4 Task tool calls in one message.

Each sub-agent receives the prompt below (fill in the placeholders per work item):

---

**SUB-AGENT PROMPT:**

````
You are reviewing PR feedback on branch `{branch}` in repo `{repo}`.

## The Feedback
Author: {author}
File: {file_path} (line {line})
Comment:
{comment_body}

Discussion context (if any):
{subsequent_comments or "None"}

Diff context:
{diff_hunk}

## CI Context
{ci_error_logs or "No CI errors related to this feedback."}

## Phase A: Validity Assessment

Reason through EACH of these questions explicitly before reaching a verdict. Do not skip any.

1. Is this feedback pointing to a real edge case, bug, or code quality issue?
2. Is the described scenario actually possible given the current codebase? Search for evidence.
3. If it IS real, what concrete evidence supports it? Cite specific files, line numbers, and runtime behavior.
4. If it is NOT real, what concrete evidence proves it is impossible? Cite specific code paths that prevent it.
5. Has this exact problem (or a similar one) been solved elsewhere in this codebase? Search for patterns.
6. If a solution exists elsewhere, can we apply that same pattern here?

**Verdict:** State VALID or INVALID with your full chain of reasoning.

If INVALID -> stop here. Report your verdict and reasoning. Do not make any code changes.

## Phase B: Apply Fix (only if VALID)

Read the relevant file(s) and implement the minimal fix that addresses the feedback.

After implementing, STOP. Do not report success yet. Proceed to Phase C.

## Phase C: Solution Verification (max 2 attempts)

You MUST now switch to adversarial mode and challenge your own fix. Answer EACH of these questions explicitly:

1. Does this fix address the ROOT CAUSE of the feedback, or does it only treat a symptom?
2. What specific evidence proves this solution is correct? ("it should work" is NOT evidence -- cite code, API docs, runtime behavior, or test results.)
3. Does this fix introduce any NEW problems? Check for: broken imports, missing references, regressions in related functionality, dead code left behind.
4. Is there a SIMPLER solution you overlooked? Could this be solved with fewer lines or less complexity?
5. Does this solution follow EXISTING patterns in the codebase, or does it invent a new approach? If new, justify why.
6. If the fix REMOVES code: verify that nothing else depends on what was removed. Use Grep to search for references.
7. If the fix ADDS code: is the new code based on VERIFIED API behavior or documentation, or on assumption? If assumption, flag it.
8. Would a senior engineer approve this fix in code review? If not, what would they object to?

**Verification result:**
- If ALL checks pass -> report the fix as verified. Include the evidence for each check.
- If ANY check fails -> revise the fix to address the failure, then re-run Phase C (attempt 2 of 2).
- If attempt 2 also fails -> DO NOT apply the fix. Revert any changes you made. Report as "requires human judgment" with:
  - What the feedback asks for
  - Why it's valid
  - What you attempted
  - Why verification failed
  - Your recommendation for the human
````

---

## Step 6: Collect Results and Present Summary

After all sub-agents complete, collect their results and present this summary:

```
## PR Feedback Review: #{pr_number} -- {pr_title}

Found {N} unresolved feedbacks, {M} CI errors -> {X} work items dispatched.

### Results

| # | Feedback | File | Verdict | Action |
|---|----------|------|---------|--------|
| 1 | One-line summary | path/file.ext:line | VALID | Fixed -- what was done |
| 2 | One-line summary | path/file.ext:line | INVALID | No action -- why |
| 3 | One-line summary | path/file.ext:line | VALID | Requires human judgment |

### Changes Made
- `path/to/file.ext` -- what was changed and why
- `path/to/other.ext` -- what was changed and why

### Needs Attention
(Only if any work items require human judgment)
- **Item #3**: Attempted 2 fixes but verification failed.
  - Reviewer asked: "..."
  - Attempted: [what was tried]
  - Failed because: [specific reason]
  - Recommendation: [actionable next step]
```

After presenting the summary, tell the user:
"All changes are uncommitted. Review the changes above, then let me know if you'd like to commit them."

Do NOT commit automatically. Wait for the user to request a commit.
