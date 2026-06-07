Build a mobile-first dashboard using Phoenix LiveView.

If no reading log exists:
- display a welcome screen
- display a large "Create Reading Log" button

If a reading log exists:
- display summary cards:
  - books finished
  - books in progress
  - estimated words completed
  - goal progress percentage

Below the summary:
- show a large "Add Book" button

Below that:
- show books grouped by status

Design requirements:

- mobile-first
- single-column layout
- large touch targets
- no tables
- no external UI libraries
- use Tailwind utilities only

Desktop can simply use a centered container.
