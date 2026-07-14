# spec-kit-issue

A [Spec Kit](https://github.com/github/spec-kit) community extension that generates
and maintains spec artifacts from GitHub Issues — eliminating duplicate work between
issue tracking and specification.

## Overview

Developers already describe requirements in GitHub Issues: user stories, acceptance
criteria, labels, and discussions. But when starting Spec-Driven Development, they
rewrite everything from scratch in `spec.md`. This extension bridges that gap.

**Three commands:**

| Command | Description |
|---|---|
| `/speckit.issue.import` | Read a GitHub Issue and generate `spec.md` with structured requirements, scenarios, and acceptance criteria |
| `/speckit.issue.sync` | Keep spec artifacts updated when the source issue is modified |
| `/speckit.issue.link` | Add bidirectional traceability between spec artifacts and their source issue |

## Installation

```bash
specify extension add spec-kit-issue --from https://github.com/aaronrsun/spec-kit-issue/archive/refs/tags/v1.0.0.zip
```

Or install from a local clone for development:

```bash
specify extension add --dev /path/to/spec-kit-issue
```

## Prerequisites

- [Spec Kit](https://github.com/github/spec-kit) `>=0.1.0`
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated with `gh auth login`,
  **or** the GitHub MCP tool available in your AI agent

## Usage

### Import a GitHub Issue → spec.md

Start a new feature from an existing GitHub issue. The command fetches the issue's
title, body, labels, and comments, then writes a `spec.md` with structured
requirements, scenarios, and acceptance criteria.

```
/speckit.issue.import https://github.com/owner/repo/issues/123
```

After importing, continue with the normal Spec Kit workflow:

```
/speckit.plan
/speckit.tasks
/speckit.implement
```

### Sync spec.md with Issue Updates

When the source issue is updated (new acceptance criteria, changed requirements,
new comments), re-run sync to pull in the changes without losing any local
additions to the spec.

```
/speckit.issue.sync
```

The active feature's linked issue is resolved automatically. To sync against a
specific issue instead:

```
/speckit.issue.sync https://github.com/owner/repo/issues/123
```

### Link an Existing spec.md to a GitHub Issue

If you already have a `spec.md` and want to associate it with a GitHub issue
(without regenerating the spec), use `link`. This adds a source reference to the
spec and optionally posts a cross-reference comment on the GitHub issue.

```
/speckit.issue.link https://github.com/owner/repo/issues/123
```

Pass `--comment` to automatically post the back-reference without being prompted:

```
/speckit.issue.link https://github.com/owner/repo/issues/123 --comment
```

## Traceability File

The extension stores traceability data in:

```
.specify/extensions/issue/links.yml
```

This file records which feature directories are linked to which GitHub issues,
along with import and sync timestamps. It is written and read automatically by all
three commands.

## License

MIT
