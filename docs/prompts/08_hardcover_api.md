Add Hardcover metadata lookup as a second metadata provider.

Goal:
Use Hardcover as an optional richer metadata source alongside Open Library.

Background:
Hardcover exposes a GraphQL API and generally requires an API token.

Configuration:
- Read the API token from an environment variable:
  HARDCOVER_API_TOKEN
- If no token is configured:
  - Do not crash.
  - Hide or disable Hardcover lookup.
  - Show a helpful message in development if needed.

Provider architecture:
- Use the existing metadata provider abstraction.
- Add a Hardcover provider module.
- Normalize Hardcover results into the same internal metadata result format used by Open Library.

Normalized fields:
- title
- author
- page_count if available
- isbn_10
- isbn_13
- language_code
- publish_year if available
- hardcover_id
- cover_url if available
- provider = hardcover

User flow:
- In the Add/Edit Book metadata search section, allow provider choice:
  - Open Library
  - Hardcover, only if configured
  - All providers, optional if easy
- Search by title, author, ISBN, or general query.
- Display results in the same UI format as Open Library results.
- Selecting a result should pre-fill the form.
- User must confirm/save manually.

Error handling:
- Handle missing token.
- Handle GraphQL errors.
- Handle timeouts.
- Handle no results.
- Never crash the LiveView.

Implementation:
- Use Req or the existing HTTP client.
- Keep GraphQL query code isolated in the Hardcover provider module.
- Do not add Goodreads/Apify.
- Do not implement sync with a user's Hardcover library.
- This is only metadata lookup for book entry.

Design:
- Mobile-first.
- Keep result cards easy to scan and tap.
- Show provider name clearly so the user knows where the metadata came from.
