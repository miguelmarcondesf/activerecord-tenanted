require "test_helper"

class TestRailsRecords < ActiveSupport::TestCase
  test "Rails records are subtenanted" do
    assert_predicate(ActionMailbox::Record, :tenanted?)
    assert_predicate(ActionText::Record, :tenanted?)
    assert_predicate(ActiveStorage::Record, :tenanted?)
  end
end
