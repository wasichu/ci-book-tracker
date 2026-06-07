Add status controls to book cards.

want_to_read:
- Start
- Finish

in_progress:
- Finish
- Abandon

finished:
- Reopen

abandoned:
- Reopen

Behavior:

Start:
- status -> in_progress
- set started_on if missing

Finish:
- status -> finished
- set finished_on

Reopen:
- status -> in_progress

Use simple buttons with clear labels.

Optimize for mobile interaction.
