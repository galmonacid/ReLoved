# Definition of Done (MVP)

## Scope
- Applies to MVP work items (features, backend functions, rules, and data model changes).

## Functional
- Meets acceptance criteria listed in the task or spec.
- Works on iOS simulator/device for primary flows.
- Handles empty/loading/error states for affected screens.

## Quality
- Unit tests added/updated for new logic.
- Firestore/Storage rules tests updated when rules change.
- Function tests updated when Cloud Functions change.
- No new warnings from `flutter analyze` or lint rules (if configured).
- Build passes for affected targets (Flutter app and Functions).

## Security + privacy
- Access control enforced via rules or function checks.
- PII minimized and stored only when necessary.
- Any new data fields documented in `docs/data_model.md`.

## UX
- Accessibility basics checked: labels, tap targets, contrast.
- Strings are user-friendly and consistent.

## Ops
- Release notes updated if user-visible behavior changed.
- Rollback steps noted for risky changes.

## Evidence
- Test command(s) recorded in the PR/summary.
- Relevant screenshots or notes for UI changes.

## Standard verification (when applicable)
- Flutter: `flutter analyze` and `flutter test`
- Functions: `npm --prefix backend/functions run lint` and `npm --prefix backend/functions run build`
- Rules: emulator-based tests (when present)
