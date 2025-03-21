class NoteMailer < ApplicationMailer
  def note_email
    @note = params[:note]
    mail(to: params[:email], subject: "Here is a note for you!")
  end
end
