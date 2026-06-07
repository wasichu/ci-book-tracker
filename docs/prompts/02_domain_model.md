Implement the initial Ash domain model.

Create two resources:

ReadingLog
- name
- language_code
- word_goal

Book
- reading_log_id
- title
- author
- page_count
- estimated_words
- difficulty_label
- status
- added_on
- started_on
- finished_on
- notes

Status values:
- want_to_read
- in_progress
- finished
- abandoned

Requirements:

- title is required
- status defaults to want_to_read
- added_on defaults to today's date
- page_count is optional
- estimated_words is optional
- notes are optional

Add actions for:
- create reading log
- add book
- edit book
- start book
- finish book
- abandon book
- reopen book

Keep the implementation simple and idiomatic.

Do not implement metadata lookup yet.
