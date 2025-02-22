class NoteCheerioJob < ApplicationJob
  queue_as :default

  def perform(note)
    if note.needs_cheerio?
      note.update!(body: "#{note.body} Cheerio!")
    end
  end
end
