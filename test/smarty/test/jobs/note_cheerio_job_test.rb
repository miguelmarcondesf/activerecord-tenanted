require "test_helper"

class NoteCheerioJobTest < ActiveJob::TestCase
  test "update the note" do
    note = notes(:one)
    assert_not_includes(note.body, "Cheerio!")

    perform_enqueued_jobs do
      NoteCheerioJob.perform_later(note)
    end

    note.reload

    assert_includes(note.body, "Cheerio!")
  end
end
