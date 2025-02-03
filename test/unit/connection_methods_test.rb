# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::ConnectionMethods do
  test "it is mixed into ActiveRecord::Base" do
    assert_includes(ActiveRecord::Base.ancestors, ActiveRecord::Tenanted::ConnectionMethods)
  end
end
