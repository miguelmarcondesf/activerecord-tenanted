# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Tenant do
  for_each_scenario do
    describe "#to_global_id" do
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
