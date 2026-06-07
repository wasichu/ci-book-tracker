Create a mobile-first Add Book LiveView form.

Fields:

- title
- author
- page_count
- estimated_words
- difficulty_label
- notes

Behavior:

- title required
- estimated_words optional
- page_count optional

When page_count is entered and estimated_words is blank:

estimated_words = page_count * 250

Allow the user to edit the estimate.

After saving:
- return to dashboard
- show success feedback

Design for phones first:
- labels above inputs
- large controls
- generous spacing
- large save button
