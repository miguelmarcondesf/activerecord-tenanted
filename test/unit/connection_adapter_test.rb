# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::ConnectionAdapter do
  with_scenario(:primary_db, :primary_record) do
    describe ".tenanted?" do
      test "returns false for untenanted connection" do
        assert_not(Announcement.connection.tenanted?)
      end

      test "returns true for tenanted connection" do
        TenantedApplicationRecord.create_tenant("foo") do
          assert_predicate(User.connection, :tenanted?)
        end
      end
    end

    describe ".tenant" do
      test "returns nil for untenanted connection" do
        assert_nil(Announcement.connection.tenant)
      end

      test "returns tenant name for tenanted connection" do
        TenantedApplicationRecord.create_tenant("foo") do
          assert_equal("foo", User.connection.tenant)
        end
      end
    end
  end
end
