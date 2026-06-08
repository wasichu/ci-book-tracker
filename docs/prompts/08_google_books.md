Implement Google Books metadata lookup as a second metadata provider.

Goal:
Improve metadata coverage, especially for graded readers, commercial language-learning books, Kindle-adjacent editions, and books missing or incomplete in Open Library.

Context:
- Open Library lookup already exists and works.
- Open Library coverage is incomplete for some graded readers.
- Google Books should use the same provider abstraction and normalized metadata result structure already used by Open Library.

Provider architecture:
- Add a GoogleBooks provider module.
- Keep Google Books API code isolated in that provider.
- Normalize Google Books results into the existing shared metadata result structure.
- Do not let Google Books-specific response shapes leak into LiveViews or forms.

Search behavior:
- Support title, author, ISBN, and general query search.
- If the query looks like an ISBN:
  - normalize it by removing spaces and hyphens.
  - search Google Books by ISBN first.
  - if no result is found, fall back to general search.
- Limit results to a reasonable number, such as 5–10.
- Prefer results with:
  - page_count
  - language matching the active ReadingLog language_code
  - authors
  - cover image
  - published date

API key behavior:
- The provider must work without an API key.
- If GOOGLE_BOOKS_API_KEY is configured, include it in requests.
- If no API key is configured, continue using public API access.
- Missing API keys should never prevent the feature from working.
- Keep configuration simple and optional.

Normalized fields:
- provider = google_books
- provider_id
- title
- author
- page_count
- isbn_10
- isbn_13
- language_code
- publish_year
- cover_url
- description if already supported
- raw metadata only if the existing abstraction has a raw/debug field

Estimated words:
- If page_count is available:
  - estimate total words as page_count * 250.
- Keep behavior consistent with the current Estimated Total Words UX.

UI behavior:
- Add Google Books as a selectable provider in the metadata search UI.
- Provider options should include:
  - Open Library
  - Google Books
- If simple, also add:
  - All Providers
- Results should clearly show the provider name.
- Selecting a Google Books result should prefill the same Add/Edit Book form fields as Open Library.
- User must still review and save manually.
- Do not silently overwrite saved book data.

Result display:
Each result card should show available fields:
- title
- author
- provider
- publish year
- language
- page count
- thumbnail if available

Error handling:
- Handle no results gracefully.
- Handle Google Books API errors gracefully.
- Handle timeouts gracefully.
- Never crash the LiveView.
- If Google Books fails while Open Library works, show available results rather than failing the whole lookup.

Implementation:
- Use Req or the same HTTP client already used for Open Library.
- Keep the code simple and dependency-light.
- Do not add Hardcover in this task.
- Do not add Goodreads/Apify.
- Do not add local image caching.

Design:
- Mobile-first.
- Search controls and result cards should remain easy to tap.
- Use Tailwind utilities only.
- Keep manual entry as the primary workflow.

Success criteria:
- User can search Google Books by title.
- User can search Google Books by author/general query.
- User can search Google Books by ISBN.
- User can select a result.
- Form is prefilled.
- Existing Open Library lookup still works.
- Manual entry still works even when metadata lookup finds nothing.
