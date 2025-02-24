require "test_helper"

class TestActiveStorage < ActionDispatch::IntegrationTest
  test "can upload a file" do
    post(notes_path,
         params: {
           note: {
             title: "Neat logo",
             body: "Must have been a cool conference!",
             image: fixture_file_upload(Rails.root.join("test/fixtures/files/goruco.jpg"), "image/jpg"),
           },
         })
    assert_response :redirect

    note = Note.order(:created_at).last
    assert_predicate(note.image, :attached?)
  end
end
