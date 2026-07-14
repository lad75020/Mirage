# Changelog

## [1.0.0] - 2026-04-11

### Functionalities
- **Import** a GitHub Issue to generate a `spec.md` from scratch, mapping the issue body and comments to requirements, user scenarios, and acceptance criteria
- **Link** an existing `spec.md` to a GitHub Issue to establish traceability without regenerating the spec, with an optional back-reference comment posted on the issue
- **Sync** a linked spec with the latest issue state, merging new content additively, annotating additions with their source, and flagging contradictions for manual review rather than silently overwriting spec content

### Added
- `speckit.issue.import` — Fetch a GitHub Issue (title, body, labels, comments) and generate `spec.md` with structured requirements, scenarios, and acceptance criteria
- `speckit.issue.link` — Associate an existing `spec.md` with a GitHub Issue for bidirectional traceability; optionally posts a cross-reference comment on the issue
- `speckit.issue.sync` — Pull updates from the linked source issue into `spec.md`, merging new requirements and acceptance criteria while preserving local additions and flagging conflicts
