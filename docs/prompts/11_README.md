Update and modernize the README for CI Book Tracker.

Goal:
Create a polished README that explains what the project is, why it exists, how to use it, and how it relates to comprehensible input and extensive reading.

README structure:

# CI Book Tracker

Short description:

* Local-first reading tracker for language learners.
* Track books, reading logs, reading goals, and estimated words read.
* Works fully offline for manual entry.
* Internet access is only required for optional metadata lookup.

## Why This Project Exists

Explain that the project was inspired by comprehensible input and extensive reading approaches to language learning.

Discuss:

* The value of reading large amounts of understandable content.
* Tracking books completed.
* Tracking estimated words read.
* Setting long-term reading goals.
* Maintaining a personal record of reading progress.

Keep the tone informative and practical rather than ideological.

## Extensive Reading and Comprehensible Input

Briefly explain:

* Extensive reading generally involves reading large quantities of relatively easy and interesting material for meaning and enjoyment rather than intensive study.
* Many language learners use extensive reading as part of a comprehensible input approach to language acquisition.

Include links to:

* The Extensive Reading Foundation:
  https://erfoundation.org/wordpress/what_is/

* Inspiration video:
  https://www.youtube.com/watch?v=OheGJ2geFnA

Do not make strong claims that the app proves any language-learning theory.
Simply explain that these ideas inspired the project.

## Features

Current features:

* Multiple reading logs
* Language-specific reading logs
* Reading goals
* Estimated words read
* Add/edit/delete books
* Book detail pages
* Status workflow:

  * Want to Read
  * In Progress
  * Finished
  * Abandoned
* Search and filtering
* Metadata lookup
* Metadata refresh
* Local SQLite storage
* Database export
* Database restore
* Settings page
* Metadata provider configuration

## Metadata Providers

Describe:

* Open Library
* Google Books
* Hardcover if implemented

Explain:

* Metadata lookup is optional.
* Manual entry remains a first-class workflow.
* The application remains useful even without internet access.

## Philosophy

Include:

* Local-first
* Offline-capable
* No accounts
* No cloud dependency
* User owns their data
* SQLite database
* Metadata is optional enhancement, not a requirement

## Screenshots

Add placeholder sections for screenshots.

## Development

Document:

* Elixir version requirements
* Phoenix version requirements
* Installation
* mix setup
* Running the application
* Running tests

## Data Storage

Explain:

* Data is stored locally in SQLite.
* Database export and restore are supported.
* Users should back up their database file.

## Roadmap

Include future ideas such as:

* Burrito packaging
* Improved metadata providers
* Better word estimation tools
* Additional quality-of-life improvements

Keep the README concise, welcoming, and professional.
Avoid marketing language.
Focus on clarity and usefulness.

