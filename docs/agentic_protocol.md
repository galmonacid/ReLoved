# Agentic Development Protocol

## Goals
- Keep changes small, reviewable, and reversible.
- Provide clear evidence for tests and behavior changes.

## Change discipline
- Prefer small diffs with focused scope.
- Avoid mixing refactors with new features.
- Update docs alongside code changes when relevant.

## Task workflow (per change)
- Restate scope and acceptance criteria.
- Implement the smallest viable change.
- Add or update tests as needed.
- Record test commands and results.
- Summarize behavior changes and risks.

## Evidence
- Always report test commands and results.
- Note any skipped tests and why.

## Safety checks
- Identify risky changes (auth, rules, payments, emails).
- Add guardrails (validation, rate limits, logging) for risky changes.

## Rollback notes
- For any change that touches prod behavior, record rollback steps:
  - What to revert.
  - Any config to restore.
  - Any data cleanup steps.

## Data + config hygiene
- No secrets in repo.
- Document required config in `docs/environments_secrets.md`.
- Use emulators for local testing where possible.

## Change summary template
- Scope:
- Tests:
- Risk/rollback:
