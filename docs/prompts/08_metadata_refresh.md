Add metadata refresh support for existing books.

Current issue:
- Books added manually may not have cover images or complete metadata.
- There is no way to later search metadata providers for an existing book.

Goal:
Allow an existing book to search metadata providers and apply selected metadata.

User flow:
- On the Book Detail page, add a secondary action: "Find Metadata".
- Use the existing metadata search UI/provider abstraction.
- Pre-fill the search query using the book title and author.
- Show provider results.
- User selects a result.
- Show a confirmation/review step before applying changes.

Fields that may be updated:
- cover_url
- page_count
- estimated_words
- isbn_10
- isbn_13
- language_code
- metadata provider/source fields if they exist

Important:
- Do not overwrite title, author, notes, status, started_on, or finished_on unless the user explicitly edits them.
- Cover image can be added without changing other book data.
- User must confirm before saving metadata changes.

Design:
- Mobile-first.
- Keep this as a secondary action, not the main book workflow.
- Use Tailwind utilities only.

Scope:
- Do not add new metadata providers.
- Do not add local image caching.
- Do not add unrelated features.
