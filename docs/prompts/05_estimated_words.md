Improve the Estimated Words UX in the Add/Edit Book form.

Current issue:
- The form contains an editable "Estimated Words" field.
- It is unclear whether this means total estimated words, words per page, or something else.
- The field is automatically populated, which makes it feel like a calculated value rather than user input.

Goal:
Make the meaning of estimated words clear and reduce confusion.

Behavior:

1. Page Count remains editable.
- Keep the existing Page Count input.

2. Estimated Words should represent total estimated words for the entire book.
- Rename the display to "Estimated Total Words".

3. If Page Count is present:
- Automatically calculate:
  estimated_total_words = page_count * 250
- Display the calculated value as read-only helper text or a read-only field.
- Do not present it as a primary editable input.

Example:

Page Count: 330

Estimated Total Words:
82,500

(using 250 words per page)

4. If Page Count is blank:
- Allow the user to manually enter an Estimated Total Words value.
- This supports books where page count is unknown.

5. Editing existing books:
- Preserve existing stored estimated word values.
- Recalculate only when appropriate and consistent with current behavior.

Design:
- Mobile-first.
- Labels above inputs.
- Large readable text.
- Keep the estimated value visually secondary to Page Count.
- Use Tailwind utilities only.

Scope:
- Do not add metadata lookup.
- Do not add covers.
- Do not add reading sessions.
- Keep this focused on clarifying and simplifying the Estimated Words experience.
