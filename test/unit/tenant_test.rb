# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Tenant do
  describe ".tenanted_config_name" do
    with_scenario(:vanilla, :tenanted_primary) do
      test "it sets database configuration name to 'primary' by default" do
        assert_equal("primary", TenantedApplicationRecord.tenanted_config_name)
      end
    end

    with_scenario(:vanilla_named_primary, :tenanted_primary) do
      test "it sets database configuration name" do
        assert_equal("tenanted", TenantedApplicationRecord.tenanted_config_name)
      end
    end
  end

  describe ".while_tenanted" do
    with_each_scenario do
      describe ".current_tenant" do
        test "returns nil by default" do
          assert_nil(TenantedApplicationRecord.current_tenant)
        end

        test "returns the string name of the tenant if in a tenant context " do
          TenantedApplicationRecord.while_tenanted(:foo) do
            assert_equal("foo", TenantedApplicationRecord.current_tenant)
          end

          TenantedApplicationRecord.while_tenanted("foo") do
            assert_equal("foo", TenantedApplicationRecord.current_tenant)
          end
        end

        test "subclasses see the same tenant" do
          assert_nil(User.current_tenant)

          TenantedApplicationRecord.while_tenanted("foo") do
            assert_equal("foo", User.current_tenant)
          end
        end
      end

      test "raise NoTenantError on database access if there is no current tenant" do
        assert_raises(ActiveRecord::Tenanted::NoTenantError) do
          User.first
        end
      end

      test "raise if switching tenants in a while_tenanted block" do
        TenantedApplicationRecord.while_tenanted("foo") do
          # an odd exception to raise here IMHO, but that's the current behavior of Rails
          e = assert_raises(ArgumentError) do
            TenantedApplicationRecord.while_tenanted("bar") { }
          end
          assert_includes(e.message, "shard swapping is prohibited")
        end
      end
    end
  end

  describe "connection pools" do
    with_each_scenario do
      test "models should share connection pools" do
        TenantedApplicationRecord.while_tenanted("foo") do
          assert_same(User.connection_pool, Post.connection_pool)
        end
      end
    end
  end

  describe "creation and migration" do
    with_each_scenario do
      test "database should be created" do
        dbpath = TenantedApplicationRecord.while_tenanted("foo") do
          User.first
          User.connection_db_config.database
        end

        assert(File.exist?(dbpath))
      end
    end
  end

  describe "logging" do
    with_each_scenario do
      test "database logs should emit the tenant name" do
        log = capture_log do
          TenantedApplicationRecord.while_tenanted("foo") do
            User.count
          end
        end
        assert_includes(log.string, "[tenant=foo]")
      end
    end
  end
end
