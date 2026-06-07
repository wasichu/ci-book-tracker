Implement a mobile-first Book Detail page using Phoenix LiveView.

Navigation:

* Clicking a book from the dashboard should navigate to its detail page.
* Provide a clear Back button to return to the dashboard.
* Navigation should preserve the currently active ReadingLog.

Display:

* Title
* Author
* Status
* Difficulty
* Page count
* Estimated total words
* Added date
* Started date
* Finished date
* Notes

Formatting:

* Display estimated words using human-readable formatting.
* Examples:

  * 82500 -> 82.5 thousand words
  * 1500000 -> 1.5 million words
* Gracefully handle missing values.

Layout requirements:

* Mobile first.
* Single-column layout.
* Large readable typography.
* Use cards or sections to group information.
* No tables.
* Generous spacing and touch targets.

Actions:

Display status actions appropriate for the current status.

want_to_read:

* Start
* Finish
* Abandon

in_progress:

* Finish
* Abandon

finished:

* Reopen

abandoned:

* Reopen

Behavior:

Start:

* set status to in_progress
* set started_on to today if blank

Finish:

* set status to finished
* set finished_on to today if blank
* set started_on to finished_on if blank

Abandon:

* set status to abandoned
* set started_on to today if blank

Reopen:

* set status to in_progress
* preserve existing dates unless current application behavior requires otherwise

Editing:

* Provide an Edit Book button.
* Reuse the existing Add/Edit Book form.
* Allow editing:

  * title
  * author
  * page count
  * estimated words
  * difficulty
  * notes
  * status
  * started_on
  * finished_on
* After saving, return to the Book Detail page.

Deletion:

* Add a clearly labeled "Delete Book" action.
* Place deletion in a visually separate danger section near the bottom of the page.
* Do not make Delete Book a primary action.
* Require confirmation before deletion.
* Confirmation should include the book title.
* If confirmed:

  * delete the book
  * return to the dashboard
  * refresh dashboard statistics

Design:

* Prioritize clarity and ease of use on phones.
* Keep actions obvious and easy to tap.
* Avoid icon-only controls.
* Use Tailwind utilities only.
* Keep implementation consistent with the existing dashboard and form design.

Scope:

* Do not add metadata lookup.
* Do not add covers.
* Do not add reading sessions.
* Do not add unrelated features.

Focus on creating a polished, practical Book Detail page that supports the complete lifecycle of a book.

