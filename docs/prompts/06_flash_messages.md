Improve flash message UX by automatically dismissing flash messages.

Current issue:
- Flash messages remain visible until manually dismissed.
- This creates unnecessary visual clutter after actions complete.

Goal:
Flash messages should automatically fade out after a short delay.

Behavior:
- Success/info flash messages should automatically disappear after 3 seconds.
- Error flash messages should remain visible until manually dismissed.
- Users should still be able to manually dismiss any flash immediately.

Animation:
- Use a short fade-out transition before removal.
- Keep the animation subtle and responsive.
- Avoid abrupt disappearance.

Implementation:
- Prefer Phoenix LiveView and existing JS helpers.
- Use minimal custom JavaScript.
- Keep the solution idiomatic for Phoenix LiveView.

Design:
- Mobile-first.
- Do not alter flash styling beyond adding the fade behavior.
- Keep existing flash functionality intact.

Scope:
- Only implement auto-dismiss behavior for flash messages.
- Do not modify unrelated UI components.
