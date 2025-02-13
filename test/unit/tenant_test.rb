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

  describe "no current tenant" do
    for_each_scenario do
      test "raise NoTenantError on database access if there is no current tenant" do
        assert_raises(ActiveRecord::Tenanted::NoTenantError) do
          User.first
        end
      end
    end
  end

  describe ".current_tenant" do
    for_each_scenario do
      test "returns nil by default" do
        assert_nil(TenantedApplicationRecord.current_tenant)
      end

      test ".current_tenant= sets tenant context" do
        assert_nil(TenantedApplicationRecord.current_tenant)

        TenantedApplicationRecord.current_tenant = "foo"

        assert_equal("foo", TenantedApplicationRecord.current_tenant)
        assert_nothing_raised { User.first }
      end
    end
  end

  describe ".while_tenanted" do
    for_each_scenario do
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

      test "raise if switching tenants in a while_tenanted block" do
        TenantedApplicationRecord.while_tenanted("foo") do
          # an odd exception to raise here IMHO, but that's the current behavior of Rails
          e = assert_raises(ArgumentError) do
            TenantedApplicationRecord.while_tenanted("bar") { }
          end
          assert_includes(e.message, "shard swapping is prohibited")
        end
      end

      test "may allow shard swapping if explicitly asked" do
        TenantedApplicationRecord.while_tenanted("foo", prohibit_shard_swapping: false) do
          assert_nothing_raised do
            TenantedApplicationRecord.while_tenanted("bar") { }
          end
        end
      end
    end
  end

  describe ".while_untenanted" do
    for_each_scenario do
      test "current_tenant is nil" do
        TenantedApplicationRecord.current_tenant = "foo"
        TenantedApplicationRecord.while_untenanted do
          assert_nil(TenantedApplicationRecord.current_tenant)
        end
      end

      test "allows shard swapping" do
        TenantedApplicationRecord.current_tenant = "foo"
        TenantedApplicationRecord.while_untenanted do
          TenantedApplicationRecord.while_tenanted("bar") do
            assert_equal("bar", TenantedApplicationRecord.current_tenant)
          end
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

  describe ".create_tenant" do
    for_each_scenario do
      test "raises an Exception if the tenant already exists" do
        TenantedApplicationRecord.while_tenanted("foo") { User.count }

        assert_raises(ActiveRecord::Tenanted::TenantExistsError) do
          TenantedApplicationRecord.create_tenant("foo")
        end
      end

      test "creates the database" do
        assert_not(TenantedApplicationRecord.tenant_exist?("foo"))

        TenantedApplicationRecord.create_tenant("foo")

        assert(TenantedApplicationRecord.tenant_exist?("foo"))
      end

      test "sets up the schema" do
        TenantedApplicationRecord.create_tenant("foo")

        ActiveRecord::Migration.verbose = true

        TenantedApplicationRecord.while_tenanted("foo") do
          assert_silent do
            User.first
          end
        end
      end

      test "yields the block in the context of the created tenant" do
        TenantedApplicationRecord.create_tenant("foo") do
          assert_equal("foo", TenantedApplicationRecord.current_tenant)
        end
      end
    end
  end

  describe ".destroy_tenant" do
    for_each_scenario do
      test "it returns if the tenant does not exist" do
        assert_nothing_raised do
          TenantedApplicationRecord.destroy_tenant("doesnotexist")
        end
      end

      describe "when the tenant exists" do
        setup { TenantedApplicationRecord.create_tenant("foo") }

        test "it deletes the connection pool" do
          TenantedApplicationRecord.destroy_tenant("foo")

          pool = TenantedApplicationRecord.connection_handler.retrieve_connection_pool(
            TenantedApplicationRecord.connection_specification_name,
            role: TenantedApplicationRecord.current_role,
            shard: "foo",
            strict: false)

          assert_nil(pool)
        end

        test "it logs the deletion" do
          log = capture_log do
            TenantedApplicationRecord.destroy_tenant("foo")
          end
          assert_includes(log.string, "destroying tenant database")
          assert_includes(log.string, "DESTROY [tenant=foo]")
        end

        test "it deletes the database file" do
          TenantedApplicationRecord.destroy_tenant("foo")

          assert_not(TenantedApplicationRecord.tenant_exist?("foo"))
        end
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
        db_path = TenantedApplicationRecord.while_tenanted("foo") do
          User.first
          User.connection_db_config.database
        end

        assert(File.exist?(db_path))
      end

      test "database should be migrated" do
        ActiveRecord::Migration.verbose = true

        TenantedApplicationRecord.while_tenanted("foo") do
          assert_output(/migrating.*create_table/m, nil) do
            User.first
          end
          assert_equal(20250203191115, User.connection_pool.migration_context.current_version)
        end
      end

      test "database schema file should be created" do
        schema_path = TenantedApplicationRecord.while_tenanted("foo") do
          User.first
          ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(User.connection_db_config)
        end

        assert(File.exist?(schema_path))
      end

      test "database schema cache file should be created" do
        schema_cache_path = TenantedApplicationRecord.while_tenanted("foo") do
          User.first
          ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(User.connection_db_config)
        end

        assert(File.exist?(schema_cache_path))
      end

      describe "when schema dump file exists" do
        setup { with_schema_dump_file }

        test "database should load the schema dump file" do
          ActiveRecord::Migration.verbose = true

          TenantedApplicationRecord.while_tenanted("bar") do
            assert_silent do
              User.first
            end
            assert_equal(20250203191115, User.connection_pool.migration_context.current_version)
          end
        end

        describe "and there are pending migrations" do
          setup { with_new_migration_file }

          test "it runs the migrations after loading the schema" do
            ActiveRecord::Migration.verbose = true

            TenantedApplicationRecord.while_tenanted("foo") do
              assert_output(/migrating.*add_column/m, nil) do
                User.count
              end
              assert_equal(20250213005959, User.connection_pool.migration_context.current_version)
              assert_equal([ "id", "email", "created_at", "updated_at", "age" ].sort,
                           User.new.attributes.keys.sort)
            end
          end
        end
      end

      describe "when an outdated schema cache dump file exists" do
        setup { with_schema_cache_dump_file }
        setup { with_new_migration_file }

        describe "before a connection is made" do
          test "models can be created but migration is not applied" do
            assert_equal([ "id", "email", "created_at", "updated_at" ].sort,
                         User.new.attributes.keys.sort)
          end
        end

        describe "after a connection is made" do
          test "remaining migrations are applied" do
            ActiveRecord::Migration.verbose = true

            TenantedApplicationRecord.while_tenanted("foo") do
              assert_output(/migrating.*add_column/m, nil) do
                User.count
              end
              assert_equal(20250213005959, User.connection_pool.migration_context.current_version)
              assert_equal([ "id", "email", "created_at", "updated_at", "age" ].sort,
                           User.new.attributes.keys.sort)
            end
          end
        end
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
