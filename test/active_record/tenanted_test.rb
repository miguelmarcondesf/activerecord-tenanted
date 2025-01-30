# frozen_string_literal: true

require "test_helper"

class ActiveRecord::TenantedTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert ActiveRecord::Tenanted::VERSION
  end
end
