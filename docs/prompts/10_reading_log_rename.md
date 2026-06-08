Add the ability to edit an existing ReadingLog.

Goal:
Allow users to rename a reading log and update basic log settings.

Fields:
- name
- language_code
- word_goal

Behavior:
- Add an Edit action for each log on the home/log selector page.
- Add an Edit Log or Log Settings action from the active dashboard.
- Reuse the existing ReadingLog create/edit form if possible.
- Saving should update the log and return to the previous page.
- Name is required.
- Do not change the log id.
- Do not affect books in the log.

Design:
- Mobile-first.
- Clear labels.
- Large touch targets.
- Use Tailwind utilities only.

Scope:
- Do not add unrelated settings.
- Do not delete or duplicate logs.
