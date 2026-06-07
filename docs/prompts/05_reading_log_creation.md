Improve the ReadingLog create/edit UI with friendlier helper controls.

Goals:

1. Language code selection
- Replace the plain language_code text input with a select control.
- Offer common language choices first:
  - Spanish: es
  - French: fr
  - German: de
  - Italian: it
  - Portuguese: pt
  - Japanese: ja
  - Korean: ko
  - Chinese: zh
  - Arabic: ar
  - Russian: ru
  - Hindi: hi
  - Dutch: nl
  - Swedish: sv
  - Greek: el
  - Latin: la
- Store only the language code in the database.
- Show the human-readable language name in the UI.

2. Word goal helper
- Replace raw word_goal-only entry with:
  - goal amount input
  - unit selector
- Unit options:
  - words
  - thousand words
  - million words
- Convert the selected amount + unit into the stored integer word_goal.
- Examples:
  - 500 + thousand words -> 500000
  - 3 + million words -> 3000000
  - 250000 + words -> 250000

3. Human-readable goal display
- Wherever word_goal is displayed, format it naturally.
- Examples:
  - 3000000 -> 3 million words
  - 1500000 -> 1.5 million words
  - 500000 -> 500 thousand words
  - 25000 -> 25 thousand words
  - 950 -> 950 words

4. Scope
- Keep database schema unchanged if possible.
- Store language_code and word_goal as before.
- This is primarily a UI/form parsing and formatting task.
- Keep the design mobile-first.
- Use Tailwind utilities only.
- Do not add metadata lookup, covers, book detail pages, or unrelated features.
