Implement bulk CSV import for books.

Goal:
Allow users to import books into the currently active ReadingLog from a simple CSV file.

CSV columns:
- title required
- author optional
- status optional
- page_count optional
- estimated_words optional
- difficulty_label optional
- started_on optional
- finished_on optional
- notes optional

Behavior:
- status defaults to want_to_read.
- Valid statuses:
  - want_to_read
  - in_progress
  - finished
  - abandoned
- Dates should use YYYY-MM-DD.
- If page_count is present and estimated_words is blank:
  - estimated_words = page_count * 250.
- If status is finished and finished_on is blank:
  - finished_on = today.
- If status is finished and started_on is blank:
  - started_on = finished_on.
- Import into the currently active ReadingLog only.

Flow:
1. Add an Import CSV action, probably from Settings or the dashboard.
2. User uploads a CSV file.
3. Parse and validate the file.
4. Show a preview before importing.
5. Show row-level validation errors.
6. User confirms import.
7. Create valid books.
8. Show success/failure summary.

Requirements:
- Do not silently import invalid rows.
- Do not require metadata lookup.
- Do not fetch covers during import.
- Do not add duplicate detection yet unless simple.
- Keep manual entry unchanged.
- Mobile-first UI.
- Use Tailwind utilities only.
