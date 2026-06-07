defmodule CiBookTracker.Library.BookStatus do
  use Ash.Type.Enum,
    values: [:want_to_read, :in_progress, :finished, :abandoned]
end
