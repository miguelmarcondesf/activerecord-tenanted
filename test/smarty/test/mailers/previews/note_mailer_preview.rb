# Preview all emails at http://localhost:3000/rails/mailers/note_mailer
class NoteMailerPreview < ActionMailer::Preview
  def note_email
    NoteMailer.with(email: "person@example.com", note: Note.first).note_email
  end
end
