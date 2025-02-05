# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Subtenant do
  for_each_scenario do
    test "connection pool is shared between subtenant and tenant classes" do
      FakeRecord.subtenant_of "TenantedApplicationRecord"

      TenantedApplicationRecord.while_tenanted("foo") do
        assert_same(TenantedApplicationRecord.connection_pool, FakeRecord.connection_pool)
      end
    end

    test "raises NameError if the class does not exist" do
      assert_raises(NameError) do
        FakeRecord.subtenant_of "NotARecord"
        FakeRecord.connection_pool
      end
    end

    test "raises Error if the class is an untenanted abstract connection class" do
      e = assert_raises(ActiveRecord::Tenanted::Error) do
        FakeRecord.subtenant_of "SharedApplicationRecord"
        FakeRecord.connection_pool
      end
      assert_includes(e.message, "not tenanted")
    end

    test "raises Error if the class is not a tenanted concrete class" do
      e = assert_raises(ActiveRecord::Tenanted::Error) do
        FakeRecord.subtenant_of "User"
        FakeRecord.connection_pool
      end
      assert_includes(e.message, "not a connection class")
    end

    describe ".tenanted?" do
      test "returns true for subtenants" do
        assert_not(FakeRecord.tenanted?)

        FakeRecord.subtenant_of "TenantedApplicationRecord"

        assert_predicate(FakeRecord, :tenanted?)
      end
    end
  end
end
