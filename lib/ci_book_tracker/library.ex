defmodule CiBookTracker.Library do
  use Ash.Domain

  resources do
    resource CiBookTracker.Library.ReadingLog do
      define :create_reading_log, action: :create, args: [:name, :language_code, :word_goal]
      define :delete_reading_log, action: :destroy
      define :get_reading_log, action: :read, get_by: [:id]
      define :list_reading_logs, action: :read
    end

    resource CiBookTracker.Library.Book do
      define :add_book, action: :create, args: [:reading_log_id, :title]
      define :list_books, action: :read
      define :edit_book, action: :edit
      define :start_book, action: :start
      define :finish_book, action: :finish
      define :abandon_book, action: :abandon
      define :reopen_book, action: :reopen
    end
  end
end
