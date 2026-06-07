Improve the Add/Edit Book form so a book can be created with its initial reading status.

Current issue:
- Books can be added, but the form does not clearly allow choosing whether the book is want_to_read, in_progress, finished, or abandoned.
- The user should be able to add a book already in progress or already finished.

Goal:
Update the Add/Edit Book form to support initial status and reading dates.

Fields to include:
- title
- author
- page_count
- estimated_words
- difficulty_label
- status
- started_on
- finished_on
- notes

Status options:
- want_to_read
- in_progress
- finished
- abandoned

Behavior:
- status defaults to want_to_read.
- started_on and finished_on are optional date inputs.

Date defaults:
- If status is in_progress and started_on is blank, set started_on to today.
- If status is finished and finished_on is blank, set finished_on to today.
- If status is finished and started_on is blank, set started_on to finished_on.
- If status is want_to_read, leave started_on and finished_on blank unless the user explicitly provides dates.
- If status is abandoned, allow started_on if provided; leave finished_on blank unless the user explicitly provides it.

Stats:
- Books created as finished should immediately count toward finished books and completed estimated words.
- Books created as in_progress should appear in the in-progress section.
- Books created as want_to_read should appear in the want-to-read section.
- Books created as abandoned should appear in the abandoned section.

UX:
- Add helper text near status:
  "Adding a book you've already started or finished? Set its status here."
- Show date fields clearly but keep them visually secondary.
- Keep the form mobile-first:
  - labels above inputs
  - large controls
  - generous spacing
  - no tables
  - no hover-only behavior
- Use Tailwind utilities only.

Scope:
- Do not add reading sessions yet.
- Do not add metadata lookup.
- Do not add covers.
- Do not add unrelated features.
