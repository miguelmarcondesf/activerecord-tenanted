require "test_helper"

class TestActiveStorage < ActionDispatch::IntegrationTest
  test "fixtures work with ActiveStorage::FixtureSet" do
    note = notes(:one)
    assert_predicate(note.image, :attached?, "Expected note fixture to have an attached image from ActiveStorage fixtures")
  end

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

    attachment_path = ActiveStorage::Blob.service.path_for(note.image.key)

    root_glob = "*/tmp/storage/#{ApplicationRecord.current_tenant}"
    blob_glob = "#{ApplicationRecord.current_tenant}/??/??/#{note.image.key.split("/").last}"
    assert(File.fnmatch(File.join(root_glob, blob_glob), attachment_path),
           "path #{attachment_path.inspect} does not match expected pattern")
  end
end
