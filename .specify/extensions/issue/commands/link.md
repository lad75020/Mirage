---
description: "Link a spec artifact to a GitHub Issue for bidirectional traceability"
---

# Issue Link

Establish a bidirectional traceability link between the current feature's spec artifacts and a GitHub Issue. Records the association locally in the traceability file and optionally posts a cross-reference comment on the GitHub issue pointing back to the spec.

Use this command when you already have a `spec.md` and want to associate it with an existing GitHub issue — as opposed to `/speckit.issue.import`, which creates the spec from the issue.

## User Input

$ARGUMENTS

The argument should be a GitHub issue URL or reference:

- Full URL: `https://github.com/owner/repo/issues/123`
- Short reference: `owner/repo#123`

Optionally append `--comment` to automatically post the back-reference comment on
the issue without being prompted:

```
/speckit.issue.link https://github.com/owner/repo/issues/123 --comment
```

## Prerequisites

- The current feature must have a `spec.md` at
  `.specify/features/<feature-dir>/spec.md`.
- GitHub CLI (`gh`) or GitHub MCP tool must be available to post the optional
  back-reference comment.

## Steps

### 1. Parse the Issue Reference

Extract the repository owner, repository name, and issue number from `$ARGUMENTS`
(strip `--comment` before parsing if present).

If the argument is missing or cannot be parsed, stop and report:

```
❌ Please provide a GitHub issue URL or reference.

   Usage: /speckit.issue.link https://github.com/owner/repo/issues/123
   Or:    /speckit.issue.link owner/repo#123
```

### 2. Verify the Issue Exists

Fetch basic issue metadata to confirm the issue is accessible:

```bash
gh issue view <number> --repo <owner/repo> --json title,url,number,state
```

Display the issue title and state to the user so they can confirm it is the correct issue before any files are modified.

If the issue cannot be fetched, report the error and stop.

### 3. Determine the Current Feature and Spec File

Identify the active feature directory:

```bash
feature_dir=$(git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's|.*/||')
```

Verify that `.specify/features/<feature-dir>/spec.md` exists. If it does not:

```
❌ No spec.md found for feature '<feature-dir>'.

   Create spec artifacts first:
     /speckit.specify          — to write a spec from scratch
     /speckit.issue.import     — to generate a spec from a GitHub issue
```

### 4. Add the Issue Reference to spec.md

Open `.specify/features/<feature-dir>/spec.md` and add or update the source reference line immediately after the top-level heading.

If no source reference line exists, insert:

```markdown
> **Source**: [#<number>](<issue-url>) — linked on <today's date (YYYY-MM-DD)>
```

If a `> **Source**:` or `> **Sources**:` line already exists, append the new reference to it (preserving all existing references):

```markdown
> **Sources**: [#<existing>](<existing-url>), [#<number>](<issue-url>) — linked on <date>
```

### 5. Record the Traceability Link

Create or update `.specify/extensions/issue/links.yml`. Create the directory
`.specify/extensions/issue/` if it does not exist.

```yaml
links:
  - feature: <feature-dir>
    issue_url: <issue-url>
    issue_number: <number>
    repo: <owner/repo>
    linked_at: <ISO 8601 timestamp>
    spec_file: .specify/features/<feature-dir>/spec.md
```

If an entry for this feature already exists in the file, update the `issue_url`, `issue_number`, `repo`, and `linked_at` fields in place. If no entry exists, append a new one.

### 6. Post a Back-Reference Comment on the GitHub Issue

If `--comment` was passed in `$ARGUMENTS`, post the comment automatically.
Otherwise, ask the user:

```
Post a cross-reference comment on issue #<number>? (y/N)
```

If the user confirms (or `--comment` was specified), post the following comment:

```markdown
📋 **Spec Kit Traceability Link**

This issue is linked to a spec-kit artifact:

- **Feature**: `<feature-dir>`
- **Spec file**: `.specify/features/<feature-dir>/spec.md`
- **Linked on**: <today's date>

To sync spec artifacts with future changes to this issue, run:
`/speckit.issue.sync`
```

Using the GitHub CLI:
```bash
gh issue comment <number> --repo <owner/repo> --body "<comment text>"
```

### 7. Report Completion

```
✅ Linked issue #<number> ("<issue-title>") to feature '<feature-dir>'

  Spec updated:   .specify/features/<feature-dir>/spec.md
  Links file:     .specify/extensions/issue/links.yml
  Issue comment:  <posted|skipped>

To keep spec artifacts in sync with future issue changes, run:
  /speckit.issue.sync
```
