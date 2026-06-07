Fix the Create Reading Log flow.

Current issue:
- The dashboard empty state shows a Create Reading Log button.
- Clicking it displays a placeholder saying this is a future feature.
- This should not be a future feature.

Expected behavior:
- If no ReadingLog exists, clicking Create Reading Log should open a mobile-first form.
- The form should create a ReadingLog with:
  - name
  - language_code
  - word_goal
- name is required.
- language_code should default to "es".
- word_goal is optional.
- After successful creation, return to the dashboard.
- The dashboard should then show the stats for that reading log.

Implementation requirements:
- Use the existing Ash ReadingLog resource/actions if present.
- If the required ReadingLog action is missing, add it.
- Remove any placeholder or “next feature” behavior.
- Keep the UI mobile-first.
- Use Tailwind utilities only.
- Do not add metadata lookup, book detail pages, or unrelated features.
