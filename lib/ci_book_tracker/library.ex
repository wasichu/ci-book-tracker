defmodule CiBookTracker.Library do
  use Ash.Domain

  resources do
    resource CiBookTracker.Library.ReadingLog do
      define :create_reading_log, action: :create, args: [:name, :language_code, :word_goal]
      define :delete_reading_log, action: :destroy
      define :edit_reading_log, action: :edit
      define :get_reading_log, action: :read, get_by: [:id]
      define :list_reading_logs, action: :read
    end

    resource CiBookTracker.Library.Book do
      define :add_book, action: :create, args: [:reading_log_id, :title]
      define :add_book_with_cover, action: :create_with_cover, args: [:reading_log_id, :title]
      define :get_book, action: :read, get_by: [:id]
      define :list_books, action: :read
      define :edit_book, action: :edit
      define :attach_book_cover, action: :attach_cover
      define :remove_book_cover, action: :remove_cover
      define :start_book, action: :start
      define :finish_book, action: :finish
      define :abandon_book, action: :abandon
      define :reopen_book, action: :reopen
      define :delete_book, action: :destroy
    end
  end
end
