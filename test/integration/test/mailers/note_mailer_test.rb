require "test_helper"

class NoteMailerTest < ActionMailer::TestCase
  test "config.action_mailer.default_url_options.host is tenantized" do
    note = notes(:one)
    email = NoteMailer.with(email: "human@example.org", note: note).note_email

    assert_emails(1) { email.deliver_now }

    doc = Nokogiri::HTML5(email.body.to_s)
    uri = doc.at_css("p#default_url_options a")["href"]

    assert_equal("http://#{ApplicationRecord.current_tenant}.example.com/notes/#{note.id}", uri)
  end
end
