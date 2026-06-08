Implement real Open Library metadata lookup for adding and editing books.

Goal:
Use Open Library as the first metadata provider to assist manual book entry.

Important philosophy:

* Manual entry remains the primary workflow.
* Metadata lookup is optional and should assist the user.
* Metadata lookup should never silently overwrite existing book data.
* The user must always review and confirm data before saving.

Provider architecture:

* Use the existing metadata provider abstraction and stubs.
* Implement an OpenLibrary provider module.
* Keep provider-specific logic isolated from the rest of the application.
* Normalize provider results into a shared internal metadata result structure.

User flow:

1. Add a "Search Metadata" section to the Add/Edit Book form.

2. The user can enter:

   * title
   * author
   * ISBN
   * or a general search query

3. Search Open Library.

4. Display matching results.

5. The user selects a result.

6. Prefill the book form.

7. The user reviews and edits as needed.

8. The user saves normally.

Search behavior:

* Support title and author search.
* Support general keyword search.
* Limit results to a reasonable number (for example 5–10).
* Prefer results with richer metadata when available.
* Prefer results with page counts when available.
* If the active ReadingLog language_code is "es", prefer Spanish-language results when possible, but do not hide other results.

ISBN lookup:

* If the query appears to be an ISBN, perform ISBN lookup first.
* Support ISBN-10 and ISBN-13.
* Normalize input by removing spaces and hyphens before lookup.
* Examples:

  * 9781234567890
  * 978-1234567890
  * 123456789X

Behavior:

* If ISBN lookup finds a match:

  * show the matching book as the primary result.
  * allow the user to select and import it.
* If ISBN lookup finds no match:

  * fall back to normal search behavior.
  * do not treat this as an error.
  * show a friendly message:
    "No exact ISBN match found. Try searching by title or author."

Normalized metadata fields:

* title
* author
* page_count
* isbn_10
* isbn_13
* language_code
* publish_year
* open_library_work_key
* open_library_edition_key
* cover_id
* cover_url

Estimated words:

* If page_count is available:

  * estimate total words as page_count * 250.
* Keep behavior consistent with the existing Estimated Total Words UX.
* Users should still be able to edit the value if the current design allows it.

Result display:

Each result should show as much useful information as available:

* title
* author
* publish year
* language
* page count

If a cover image is available:

* display a small thumbnail.
* do not cache covers locally yet.

Error handling:

* Handle Open Library outages gracefully.
* Handle timeouts gracefully.
* Handle empty results gracefully.
* Never crash the form.
* Display friendly messages for common failures.

Implementation:

* Use Req or the existing HTTP client already used in the project.
* Keep API code inside the metadata provider.
* Do not add Hardcover yet.
* Do not add Goodreads/Apify.
* Do not add local image caching.
* Do not add automatic synchronization.

Design:

* Mobile-first.
* Search results should be easy to scan and tap.
* Use large touch targets.
* Use Tailwind utilities only.
* Keep the interaction fast and simple.

Success criteria:

A user should be able to:

* Search by title.
* Search by author.
* Search by ISBN.
* Select a result.
* Prefill the form.
* Save the book.

while still being able to ignore metadata lookup entirely and enter books manually.

