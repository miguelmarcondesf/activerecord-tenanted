# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Tenant do
  describe ".tenanted_config_name" do
    for_each_scenario({ primary_db: [ :primary_record, :secondary_record ] }) do
      test "it sets database configuration name to 'primary' by default" do
        assert_equal("primary", TenantedApplicationRecord.tenanted_config_name)
      end
    end

    for_each_scenario({ primary_named_db: [ :primary_record, :secondary_record ],
                        secondary_db:     [ :primary_record, :secondary_record ] }) do
      test "it sets database configuration name" do
        assert_equal("tenanted", TenantedApplicationRecord.tenanted_config_name)
      end
    end
  end

  describe ".while_tenanted" do
    for_each_scenario do
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

  describe ".tenant_exist?" do
    for_each_scenario do
      test "it returns false if the tenant database has not been created" do
        assert_not(TenantedApplicationRecord.tenant_exist?("doesnotexist"))
      end

      test "it returns true if the tenant database has not been created" do
        TenantedApplicationRecord.while_tenanted("foo") { User.count }

        assert(TenantedApplicationRecord.tenant_exist?("foo"))
      end
    end
  end

  describe "connection pools" do
    for_each_scenario do
      test "models should share connection pools" do
        TenantedApplicationRecord.while_tenanted("foo") do
          assert_same(User.connection_pool, Post.connection_pool)
        end
      end
    end
  end

  describe "creation and migration" do
    for_each_scenario do
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
    for_each_scenario do
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
