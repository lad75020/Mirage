---
name: speckit-issue-sync
description: Sync spec.md with updates from the linked source GitHub Issue
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: issue:commands/sync.md
---

# Issue Sync

Fetch the latest state of the linked GitHub Issue and update the current feature's spec artifacts to reflect any changes — new acceptance criteria, updated requirements, new comments, or a changed issue state.

## User Input

$ARGUMENTS

Optional: A GitHub issue URL or reference to sync against. If omitted, the linked issue for the current feature is resolved automatically from the traceability file.

## Prerequisites

Ensure one of the following is available:

- **GitHub CLI** (`gh`): Verify with `gh auth status`
- **GitHub MCP tool**: Available via the `github` tool functions

## Steps

### 1. Resolve the Target Issue

**If `$ARGUMENTS` is provided**, parse the issue reference (URL, `owner/repo#number`, or bare number) as described in `/speckit.issue.import`.

**If `$ARGUMENTS` is empty**, resolve the linked issue automatically:

1. Read `.specify/extensions/issue/links.yml`.
2. Identify the active feature directory:
   ```bash
   feature_dir=$(git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's|.*/||')
   ```
3. Find the entry in `links.yml` whose `feature` field matches the active feature.
4. Extract `issue_url`, `issue_number`, and `repo` from that entry.

If no linked issue is found, stop and report:

```
❌ No linked issue found for feature '<feature-dir>'.

   Import an issue first:  /speckit.issue.import <issue-url>
   Or link an existing spec: /speckit.issue.link <issue-url>
```

### 2. Fetch the Current Issue State

Retrieve the latest issue data, including its current open/closed state:

```bash
gh issue view <number> --repo <owner/repo> \
  --json title,body,labels,comments,url,number,state
```

### 3. Read the Existing spec.md

Read the full contents of `.specify/features/<feature-dir>/spec.md`.

Note the date of the previous import or sync from the `> **Source**:` header line.

### 4. Diff and Identify Changes

Compare the freshly fetched issue content against what was previously imported.
Identify each of the following change types:

| Change type | How to detect |
|---|---|
| New or changed requirements | Body has new bullet points or edited sections |
| New acceptance criteria | New checklist items in the body |
| New scenarios | New usage examples in body or comments posted after last sync |
| Removed content | Items that existed before but are no longer in the body |
| Issue state change | `state` field changed to `CLOSED` |
| New open questions | Questions raised in recent comments |

### 5. Apply Updates to spec.md

Update `spec.md` with the identified changes. Follow these rules:

- **Additive by default**: Add new requirements, scenarios, and acceptance criteria without removing existing spec content.
- **Flag conflicts**: If new issue content directly contradicts content already in the spec, annotate the conflict with a blockquote rather than silently overwriting:
  ```markdown
  > ⚠️ **Conflict** (from issue sync on <date>): The issue now states "X" but the
  > spec currently says "Y". Resolve manually.
  ```
- **Mark new additions**: Annotate additions with their source so the author knows what was automatically merged:
  ```markdown
  - [ ] AC-N: <new criterion> _(synced from issue on <date>)_
  ```
- **Preserve local additions**: Content in spec.md that was added manually and is not present in the issue must not be removed.
- **Update the source header**: Refresh the `> **Source**:` line to record the sync:
  ```markdown
  > **Source**: [#<number>](<issue-url>) — imported on <import-date>, synced on <today>
  ```
- **Record issue closure**: If the issue is now closed, add a note at the top of the spec:
  ```markdown
  > ℹ️ Source issue #<number> was closed on <date>.
  ```

### 6. Update the Traceability Record

Update the matching entry in `.specify/extensions/issue/links.yml`:

```yaml
    last_synced_at: <ISO 8601 timestamp>
    issue_state: <open|closed>
```

### 7. Report Results

Summarize the changes applied:

```
✅ Synced spec.md with issue #<number> from <owner/repo>

Changes applied to .specify/features/<feature-dir>/spec.md:
  + <N> new requirements added
  + <N> new acceptance criteria added
  + <N> new scenarios added
  ⚠️  <N> conflicts flagged for manual review

Issue state: <open|closed>
```

If the spec is already up to date:

```
✅ spec.md is already up to date with issue #<number>. No changes needed.
```