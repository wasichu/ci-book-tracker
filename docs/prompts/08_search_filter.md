Implement mobile-first search and filtering for books.

Goal:
Make it easier to find books once a reading log has many entries.

Scope:
- Add search/filter controls to the active reading log dashboard.
- Do not add metadata lookup.
- Do not add external APIs.
- Do not add covers yet.

Search:
- Add a search input near the top of the book list.
- Search should match title and author.
- Search should be case-insensitive.
- Search should update the visible list without requiring a full page reload.

Filters:
- Add status filters:
  - All
  - Want to Read
  - In Progress
  - Finished
  - Abandoned
- Default to All.
- Filters should combine with search.

Display:
- Keep existing status grouping if it still makes sense.
- If grouping becomes confusing when filtered, use a simple filtered list.
- Show a friendly empty state when no books match:
  "No books match this search."

Design:
- Mobile-first.
- Single-column layout.
- Large touch targets.
- No tables.
- Use Tailwind utilities only.
- Avoid hover-only interactions.

Implementation:
- Prefer LiveView events and assigns.
- Keep filtering simple and readable.
- Do not introduce external search dependencies.
