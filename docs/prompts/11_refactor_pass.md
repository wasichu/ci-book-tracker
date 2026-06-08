Review the codebase for small refactoring opportunities before packaging.

Goal:
Improve maintainability without changing behavior.

Focus on:
- Duplicated LiveView logic
- Repeated formatting helpers
- Repeated metadata provider normalization code
- Large functions that can be split simply
- Confusing names
- Dead code
- TODO placeholders that should be removed or documented
- Inconsistent status/date handling
- Inconsistent word-count formatting
- Test gaps for critical flows

Important:
- Do not redesign the architecture.
- Do not add features.
- Do not change UI behavior unless fixing an obvious bug.
- Prefer small, safe refactors.
- Keep Ash actions and domain logic as the source of truth.
- Preserve existing behavior.
- After refactoring, run tests/format checks and report what changed.
