# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Tenant do
  describe "#to_global_id" do
    for_each_scenario do
      let(:user) do
        TenantedApplicationRecord.while_tenanted("foo") do
          User.create!(email: "user1@example.org")
        end
      end

      test "#to_global_id" do
        assert_equal("gid://dummy/User/1?tenant=foo", user.to_global_id.uri.to_s)
        assert_equal("gid://dummy/User/1?x=y&tenant=foo", user.to_global_id(x: "y").uri.to_s)
      end

      test "#to_signed_global_id" do
        assert_equal("gid://dummy/User/1?tenant=foo", user.to_signed_global_id.uri.to_s)
        assert_equal("gid://dummy/User/1?x=y&tenant=foo", user.to_signed_global_id(x: "y").uri.to_s)
      end
    end
  end
end

describe GlobalID do
  describe "#tenant" do
    with_scenario(:primary_db, :primary_record) do
      test "on a tenanted model is the tenant" do
        gid = TenantedApplicationRecord.while_tenanted("foo") do
          User.create!(email: "user1@example.org").to_global_id
        end

        assert_equal("foo", gid.tenant)
      end

      test "on an untenanted model is nil" do
        gid = Announcement.create!(message: "hello").to_global_id

        assert_nil(gid.tenant)
      end
    end
  end
end
