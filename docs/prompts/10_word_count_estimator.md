Implement a sample-based word estimate helper for books.

Goal:
Allow users to estimate a book's total word count by pasting a representative text sample and scaling it by pages, Kindle locations, screens, chapters, or percent.

Context:
- Current estimates often use page_count * 250.
- This is useful but rough.
- Kindle editions and graded readers may have unreliable page counts.
- A pasted sample can provide a better estimate.

User flow:
- Add a "Word Estimate Helper" section to the Add/Edit Book form or Book Detail page.
- User pastes sample text from the book.
- App counts the words in the sample.
- User enters:
  - sample unit count
  - total unit count
  - unit type
- App calculates an estimated total word count.
- User can apply the estimate to the book's Estimated Total Words field.

Unit types:
- pages
- Kindle locations
- screens
- chapters
- percent

Calculation:
- sample_words = count words in pasted sample text
- estimated_total_words = sample_words / sample_unit_count * total_unit_count

Examples:
- sample has 1,200 words
- sample represents 5 pages
- book has 180 pages
- estimate = 1,200 / 5 * 180 = 43,200 words

Behavior:
- Do not save pasted sample text.
- Count words locally only.
- Show the sample word count.
- Show the calculated estimate.
- Let the user apply the estimate manually.
- Do not overwrite estimated words automatically.

Validation:
- sample text required
- sample unit count must be greater than 0
- total unit count must be greater than 0
- total unit count should be greater than or equal to sample unit count
- handle empty/invalid input gracefully

Word counting:
- Implement a simple word count function suitable for Spanish and English text.
- Count words separated by whitespace/punctuation.
- Support accented characters and apostrophes reasonably.
- This does not need to be perfect.
- Do not call external APIs for word counting.

Optional data model:
- If simple, add optional fields to Book:
  - word_estimate_method
  - word_estimate_notes
- Possible method values:
  - page_count_default
  - metadata_page_count
  - manual_total
  - sample_based
- Do not store pasted sample text.

Design:
- Mobile-first.
- Keep the helper visually secondary.
- Use clear explanatory text:
  "Paste a representative sample to estimate the whole book."
- Large text area.
- Large numeric inputs.
- Clear "Apply Estimate" button.
- Use Tailwind utilities only.

Scope:
- Do not implement OCR.
- Do not implement Kindle scraping.
- Do not store copyrighted book text.
- Do not add reading sessions.
- Do not change metadata providers.
- Keep manual estimated words entry available.

Success criteria:
- User can paste sample text.
- App counts words.
- User can enter sample units and total units.
- App calculates estimated total words.
- User can apply that estimate to the book.
- The sample text is never persisted.
