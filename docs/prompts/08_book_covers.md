Add book cover support using metadata already available from providers.

Goal:
Display book cover thumbnails when available.

Data model:
- Add optional fields to Book if they do not already exist:
  - cover_url
  - cover_provider
  - cover_id if useful
- Keep these fields optional.
- Do not require covers for any book.

Open Library covers:
- If an Open Library cover_id or ISBN is available, generate a cover URL using Open Library's Covers API.
- Prefer medium-sized covers for detail pages.
- Prefer small or medium thumbnails for dashboard cards.
- Do not download/cache images locally yet.

UI:
- Dashboard book cards should show a small cover thumbnail when available.
- Book Detail page should show a larger cover when available.
- If no cover exists, show a simple placeholder:
  - book icon
  - or neutral rectangle with title initials
- Covers should never break layout.

Design:
- Mobile-first.
- Keep covers lightweight.
- Avoid giant images on the dashboard.
- Use Tailwind utilities only.

Accessibility:
- Cover images should have useful alt text:
  "Cover of <title>"
- Decorative placeholders can have empty alt text if appropriate.

Scope:
- Do not implement local image caching.
- Do not implement image upload.
- Do not scrape covers.
- Do not add Hardcover in this task unless already implemented.
