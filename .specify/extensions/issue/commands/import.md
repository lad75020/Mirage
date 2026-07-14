---
description: "Import a GitHub Issue and generate spec.md with structured requirements, scenarios, and acceptance criteria"
---

# Issue Import

Import a GitHub Issue into spec-kit artifacts, generating a `spec.md` populated with requirements, user scenarios, and acceptance criteria derived from the issue's title, body, labels, and comments.

## User Input

$ARGUMENTS

The argument should be a GitHub issue URL or reference in one of these formats:

- Full URL: `https://github.com/owner/repo/issues/123`
- Short reference: `owner/repo#123`
- Issue number only (when inside a GitHub repository): `123`

## Prerequisites

Ensure one of the following is available for fetching issue data:

- **GitHub CLI** (`gh`): Verify with `gh auth status`
- **GitHub MCP tool**: Available via the `github` tool functions

## Steps

### 1. Parse the Issue Reference

Extract the repository owner, repository name, and issue number from `$ARGUMENTS`.

- If a full URL is provided (e.g., `https://github.com/owner/repo/issues/123`), parse
  `owner`, `repo`, and `123` from it.
- If provided as `owner/repo#number`, split on `#`.
- If only a number is provided, infer the repository from the current git remote:
  ```bash
  git remote get-url origin
  ```

### 2. Fetch Issue Data

Retrieve the following fields for the issue:

- **Title**: Issue title
- **Body**: Full markdown body
- **Labels**: All labels attached to the issue
- **Comments**: All comments (author + body)
- **Issue URL**: Canonical URL
- **Issue number**: Numeric ID

Using the GitHub CLI:
```bash
gh issue view <number> --repo <owner/repo> \
  --json title,body,labels,comments,url,number
```

Using the GitHub MCP tool, call the appropriate function to get issue details.

### 3. Extract Spec Content from the Issue

Analyze the issue content and identify the following. Each may appear in the body or in comments — use best judgement when sections are not explicitly labelled:

- **Problem Statement / Context**: What problem this addresses or what value it provides
- **User Stories / Requirements**: Desired behavior, often in
  "As a ... I want ... so that ..." form
- **Acceptance Criteria**: Explicit conditions that must be true for the issue to be
  considered resolved (look for checklists in the body)
- **Scenarios**: Concrete usage examples or edge cases from the body or comments
- **Out of Scope**: Any explicitly excluded items
- **Open Questions**: Unresolved points raised in the discussion

If these sections are not explicitly present, derive them from the issue content.
Map the problem statement to requirements. Map checklists to acceptance criteria.

### 4. Determine the Target Feature Directory

Identify the current active feature directory:

```bash
feature_dir=$(git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's|.*/||')
```

If no active feature branch is detected, create a directory name by slugifying the issue title (e.g., `001-add-user-authentication`). Use the next available sequential number if existing feature directories are present under `.specify/features/`.

The spec file will be written to:
```
.specify/features/<feature-dir>/spec.md
```

Create the directory if it does not exist.

### 5. Generate spec.md

Write `spec.md` to the feature directory using the structure below. Populate every section with content derived from the issue. Do not leave placeholder text — if a section has no applicable content, omit it rather than writing "N/A".

```markdown
# <Issue Title>

> **Source**: [#<number>](<issue-url>) — imported on <today's date (YYYY-MM-DD)>

## Overview

<One-paragraph summary of the feature or problem being solved>

## Problem Statement

<What problem this solves and the value it delivers>

## Requirements

### Functional Requirements

- FR-1: <requirement derived from the issue>
- FR-2: <requirement>

### Non-Functional Requirements

- NFR-1: <non-functional requirement, if any from the issue>

## User Scenarios

### Scenario 1: <Descriptive name>

**Given** <precondition>
**When** <action taken>
**Then** <expected outcome>

## Acceptance Criteria

- [ ] AC-1: <criterion>
- [ ] AC-2: <criterion>

## Out of Scope

<Explicitly excluded items mentioned in the issue>

## Open Questions

<Unresolved points from the issue discussion>
```

### 6. Record the Traceability Link

Create or update `.specify/extensions/issue/links.yml` to record the association.
Create the directory `.specify/extensions/issue/` if it does not exist.

```yaml
links:
  - feature: <feature-dir>
    issue_url: <issue-url>
    issue_number: <number>
    repo: <owner/repo>
    imported_at: <ISO 8601 timestamp>
    last_synced_at: <ISO 8601 timestamp>
    spec_file: .specify/features/<feature-dir>/spec.md
```

If the file already exists and an entry for this feature exists, update it in place.
If no entry exists for this feature, append the new entry.

### 7. Confirm Completion

Report a summary to the user:

```
✅ Imported issue #<number> from <owner/repo>

Generated: .specify/features/<feature-dir>/spec.md
  - <N> functional requirements
  - <N> scenarios
  - <N> acceptance criteria

Traceability recorded in: .specify/extensions/issue/links.yml

Next step: /speckit.plan to create a technical implementation plan
```
