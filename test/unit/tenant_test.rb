# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Tenant do
  describe ".tenanted_config_name" do
    for_each_scenario({ primary_db: [ :primary_record, :secondary_record, :subtenant_record ] }) do
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

  describe ".tenanted?" do
    for_each_scenario do
      test "returns true" do
        assert_predicate(User, :tenanted?)
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
        assert_nil(User.current_tenant)
      end

      test ".current_tenant= sets tenant context" do
        TenantedApplicationRecord.create_tenant("foo")

        assert_nil(TenantedApplicationRecord.current_tenant)

        TenantedApplicationRecord.current_tenant = "foo"

        assert_equal("foo", TenantedApplicationRecord.current_tenant)
        assert_nothing_raised { User.first }
      end

      test ".current_tenant= sets tenant context for a symbol" do
        TenantedApplicationRecord.create_tenant("foo")

        assert_nil(TenantedApplicationRecord.current_tenant)

        TenantedApplicationRecord.current_tenant = :foo

        assert_equal("foo", TenantedApplicationRecord.current_tenant)
        assert_nothing_raised { User.first }
      end

      test ".current_tenant= can be called repeatedly" do
        assert_nil(TenantedApplicationRecord.current_tenant)

        TenantedApplicationRecord.current_tenant = "foo"

        assert_equal("foo", TenantedApplicationRecord.current_tenant)

        TenantedApplicationRecord.current_tenant = "bar"

        assert_equal("bar", TenantedApplicationRecord.current_tenant)
      end

      test "using a record after changing tenant raises WrongTenantError" do
        TenantedApplicationRecord.create_tenant("foo")
        TenantedApplicationRecord.create_tenant("bar")

        TenantedApplicationRecord.current_tenant = "foo"

        user = User.create!(email: "user1@example.org")

        TenantedApplicationRecord.current_tenant = "bar"

        assert_raises(ActiveRecord::Tenanted::WrongTenantError) do
          user.update!(email: "user1+bar@example.org")
        end
      end

      test ".current_tenant inside with_tenant raises exception" do
        TenantedApplicationRecord.create_tenant("foo")

        TenantedApplicationRecord.with_tenant("foo") do
          assert_raises(ArgumentError) do
            TenantedApplicationRecord.current_tenant = "bar"
          end

          assert_raises(ArgumentError) do # not even the same tenant is OK
            TenantedApplicationRecord.current_tenant = "foo"
          end
        end
      end
    end

    for_each_scenario(except: { primary_db: [ :subtenant_record ] }) do
      describe "concrete classes" do
        test "concrete classes can call current_tenant=" do
          TenantedApplicationRecord.current_tenant = "foo"
          assert_equal("foo", TenantedApplicationRecord.current_tenant)
          assert_equal("foo", User.current_tenant)

          User.current_tenant = "bar"
          assert_equal("bar", TenantedApplicationRecord.current_tenant)
          assert_equal("bar", User.current_tenant)
        end

        test ".current_tenant= sets tenant context" do
          TenantedApplicationRecord.create_tenant("foo")

          assert_nil(User.current_tenant)

          User.current_tenant = "foo"

          assert_equal("foo", User.current_tenant)
          assert_nothing_raised { User.first }
        end
      end
    end
  end

  describe ".with_tenant" do
    for_each_scenario do
      setup do
        TenantedApplicationRecord.create_tenant("foo")
        TenantedApplicationRecord.create_tenant("bar")
      end

      test "current tenant is set in the block context " do
        TenantedApplicationRecord.with_tenant(:foo) do
          User.first
          assert_equal("foo", TenantedApplicationRecord.current_tenant)
        end

        TenantedApplicationRecord.with_tenant("foo") do
          User.first
          assert_equal("foo", TenantedApplicationRecord.current_tenant)
        end
      end

      test "subclasses see the same tenant" do
        assert_nil(User.current_tenant)

        TenantedApplicationRecord.with_tenant("foo") do
          assert_equal("foo", User.current_tenant)
        end
      end

      test "raise if switching tenants in a with_tenant block" do
        TenantedApplicationRecord.with_tenant("foo") do
          # an odd exception to raise here IMHO, but that's the current behavior of Rails
          e = assert_raises(ArgumentError) do
            TenantedApplicationRecord.with_tenant("bar") { }
          end
          assert_includes(e.message, "shard swapping is prohibited")
        end
      end

      test "overrides the current tenant if set with current_tenant=" do
        TenantedApplicationRecord.current_tenant = "foo"

        TenantedApplicationRecord.with_tenant("bar") do
          assert_equal("bar", TenantedApplicationRecord.current_tenant)
        end

        assert_equal("foo", TenantedApplicationRecord.current_tenant)
      end

      test "using a record outside of the block raises NoTenantError" do
        user = TenantedApplicationRecord.with_tenant("bar") do
          User.create!(email: "user1@example.org")
        end

        assert_raises(ActiveRecord::Tenanted::NoTenantError) do
          user.update!(email: "user1+bar@example.org")
        end
      end

      test "using a record in another block raises WrongTenantError" do
        user = TenantedApplicationRecord.with_tenant("foo") do
          User.create!(email: "user1@example.org")
        end

        TenantedApplicationRecord.with_tenant("bar") do
          assert_raises(ActiveRecord::Tenanted::WrongTenantError) do
            user.update!(email: "user1+bar@example.org")
          end
        end
      end

      test "may allow shard swapping if explicitly asked" do
        invoked = nil

        TenantedApplicationRecord.with_tenant("foo", prohibit_shard_swapping: false) do
          assert_nothing_raised do
            TenantedApplicationRecord.with_tenant("bar") { invoked = true }
          end
        end

        assert(invoked)
      end

      test "allow nesting with_tenant calls when the tenant is the same" do
        invoked = nil

        assert_nothing_raised do
          TenantedApplicationRecord.with_tenant("foo") do
            TenantedApplicationRecord.with_tenant("foo") { invoked = true }
          end
        end

        assert(invoked)
      end

      test "attempting to access a tenant that does not exist raises TenantDoesNotExistError" do
        assert_not(TenantedApplicationRecord.tenant_exist?("baz"))

        assert_nothing_raised do
          TenantedApplicationRecord.with_tenant("baz") { } # this is OK because it doesn't hit the database
        end

        assert_raises(ActiveRecord::Tenanted::TenantDoesNotExistError) do
          TenantedApplicationRecord.with_tenant("baz") { User.count }
        end
      end
    end

    for_each_scenario(except: { primary_db: [ :subtenant_record ] }) do
      setup do
        TenantedApplicationRecord.create_tenant("foo")
        TenantedApplicationRecord.create_tenant("bar")
      end

      describe "concrete classes" do
        test "current tenant is set in the block context " do
          User.with_tenant(:foo) do
            User.first
            assert_equal("foo", User.current_tenant)
          end

          User.with_tenant("foo") do
            User.first
            assert_equal("foo", User.current_tenant)
          end
        end

        test "superclasses see the same tenant" do
          assert_nil(User.current_tenant)

          User.with_tenant("foo") do
            assert_equal("foo", TenantedApplicationRecord.current_tenant)
          end
        end

        test "raise if switching tenants in a with_tenant block" do
          User.with_tenant("foo") do
            # an odd exception to raise here IMHO, but that's the current behavior of Rails
            e = assert_raises(ArgumentError) do
              TenantedApplicationRecord.with_tenant("bar") { }
            end
            assert_includes(e.message, "shard swapping is prohibited")
          end
        end

        test "overrides the current tenant if set with current_tenant=" do
          TenantedApplicationRecord.current_tenant = "foo"

          User.with_tenant("bar") do
            assert_equal("bar", TenantedApplicationRecord.current_tenant)
          end

          assert_equal("foo", TenantedApplicationRecord.current_tenant)
        end

        test "using a record outside of the block raises NoTenantError" do
          user = User.with_tenant("bar") do
            User.create!(email: "user1@example.org")
          end

          assert_raises(ActiveRecord::Tenanted::NoTenantError) do
            user.update!(email: "user1+bar@example.org")
          end
        end

        test "using a record in another block raises WrongTenantError" do
          user = User.with_tenant("foo") do
            User.create!(email: "user1@example.org")
          end

          User.with_tenant("bar") do
            assert_raises(ActiveRecord::Tenanted::WrongTenantError) do
              user.update!(email: "user1+bar@example.org")
            end
          end
        end

        test "may allow shard swapping if explicitly asked" do
          invoked = nil

          User.with_tenant("foo", prohibit_shard_swapping: false) do
            assert_nothing_raised do
              TenantedApplicationRecord.with_tenant("bar") { invoked = true }
            end
          end

          assert(invoked)
        end

        test "allow nesting with_tenant calls when the tenant is the same" do
          invoked = 0

          assert_nothing_raised do
            User.with_tenant("foo") do
              User.with_tenant("foo") { invoked += 1 }
            end

            User.with_tenant("foo") do
              TenantedApplicationRecord.with_tenant("foo") { invoked += 1 }
            end
          end

          assert_equal(2, invoked)
        end

        test "attempting to access a tenant that does not exist raises TenantDoesNotExistError" do
          assert_not(TenantedApplicationRecord.tenant_exist?("baz"))

          assert_nothing_raised do
            User.with_tenant("baz") { } # this is OK because it doesn't hit the database
          end

          assert_raises(ActiveRecord::Tenanted::TenantDoesNotExistError) do
            User.with_tenant("baz") { User.count }
          end
        end
      end
    end
  end

  describe ".without_tenant" do
    for_each_scenario do
      setup do
        TenantedApplicationRecord.create_tenant("foo")
        TenantedApplicationRecord.create_tenant("bar")
      end

      test "current_tenant is nil" do
        TenantedApplicationRecord.current_tenant = "foo"
        TenantedApplicationRecord.without_tenant do
          assert_nil(TenantedApplicationRecord.current_tenant)
        end
      end

      test "allows shard swapping" do
        TenantedApplicationRecord.current_tenant = "foo"
        TenantedApplicationRecord.without_tenant do
          TenantedApplicationRecord.with_tenant("bar") do
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
        TenantedApplicationRecord.create_tenant("foo")

        assert(TenantedApplicationRecord.tenant_exist?("foo"))
      end
    end
  end

  describe ".create_tenant" do
    for_each_scenario do
      test "raises an exception if the tenant already exists" do
        TenantedApplicationRecord.create_tenant("foo")

        assert_raises(ActiveRecord::Tenanted::TenantExistsError) do
          TenantedApplicationRecord.create_tenant("foo")
        end
      end

      test "does not raise an exception if the tenant already exists and if_not_exists is true" do
        TenantedApplicationRecord.create_tenant("foo")

        assert_nothing_raised do
          TenantedApplicationRecord.create_tenant("foo", if_not_exists: true)
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

        TenantedApplicationRecord.with_tenant("foo") do
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

  describe ".tenants" do
    for_each_scenario do
      test "it returns an array of existing tenants" do
        assert_empty(TenantedApplicationRecord.tenants)

        TenantedApplicationRecord.create_tenant("foo")

        assert_equal([ "foo" ], TenantedApplicationRecord.tenants)

        TenantedApplicationRecord.create_tenant("bar")

        assert_same_elements([ "foo", "bar" ], TenantedApplicationRecord.tenants)

        TenantedApplicationRecord.destroy_tenant("foo")

        assert_equal([ "bar" ], TenantedApplicationRecord.tenants)
      end
    end
  end

  describe ".with_each_tenant" do
    for_each_scenario do
      test "calls the block in a tenanted context once for each existing tenant" do
        result = []
        TenantedApplicationRecord.with_each_tenant do |tenant|
          result << [ tenant, TenantedApplicationRecord.current_tenant ]
        end
        assert_empty(result)

        TenantedApplicationRecord.create_tenant("foo")
        TenantedApplicationRecord.create_tenant("bar")

        result = []
        TenantedApplicationRecord.with_each_tenant do |tenant|
          result << [ tenant, TenantedApplicationRecord.current_tenant ]
        end
        assert_same_elements([ [ "foo", "foo" ], [ "bar", "bar" ] ], result)
      end
    end
  end

  describe "connection pools" do
    for_each_scenario do
      test "models should share connection pools" do
        TenantedApplicationRecord.create_tenant("foo") do
          assert_same(User.connection_pool, Post.connection_pool)
          assert_same(TenantedApplicationRecord.connection_pool, User.connection_pool)
        end
      end
    end
  end

  describe "creation and migration" do
    for_each_scenario do
      test "database should be created" do
        db_path = TenantedApplicationRecord.create_tenant("foo") do
          User.connection_db_config.database
        end

        assert(File.exist?(db_path))
      end

      test "database should be migrated" do
        ActiveRecord::Migration.verbose = true

        assert_output(/migrating.*create_table/m, nil) do
          TenantedApplicationRecord.create_tenant("foo")
        end

        version = TenantedApplicationRecord.with_tenant("foo") do
          User.connection_pool.migration_context.current_version
        end

        assert_equal(20250203191115, version)
      end

      test "database schema file should be created" do
        schema_path = TenantedApplicationRecord.create_tenant("foo") do
          ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(User.connection_db_config)
        end

        assert(File.exist?(schema_path))
      end

      test "database schema cache file should be created" do
        schema_cache_path = TenantedApplicationRecord.create_tenant("foo") do
          ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(User.connection_db_config)
        end

        assert(File.exist?(schema_cache_path))
      end

      describe "when schema dump file exists" do
        setup { with_schema_dump_file }

        test "database should load the schema dump file" do
          ActiveRecord::Migration.verbose = true

          assert_silent do
            TenantedApplicationRecord.create_tenant("bar")
          end

          version = TenantedApplicationRecord.with_tenant("bar") do
            User.connection_pool.migration_context.current_version
          end

          assert_equal(20250203191115, version)
        end

        describe "and there are pending migrations" do
          setup { with_new_migration_file }

          test "it runs the migrations after loading the schema" do
            ActiveRecord::Migration.verbose = true

            assert_output(/migrating.*add_column/m, nil) do
              TenantedApplicationRecord.create_tenant("foo")
            end

            version = TenantedApplicationRecord.with_tenant("foo") do
              User.connection_pool.migration_context.current_version
            end

            assert_equal(20250213005959, version)
            assert_same_elements([ "id", "email", "created_at", "updated_at", "age" ],
                                 User.new.attributes.keys)
          end
        end
      end

      describe "when an outdated schema cache dump file exists" do
        setup { with_schema_cache_dump_file }
        setup { with_new_migration_file }

        describe "before a connection is made" do
          test "models can be created but migration is not applied" do
            assert_same_elements([ "id", "email", "created_at", "updated_at" ],
                                 User.new.attributes.keys)
          end
        end

        describe "after a connection is made" do
          test "remaining migrations are applied" do
            ActiveRecord::Migration.verbose = true

            assert_output(/migrating.*add_column/m, nil) do
              TenantedApplicationRecord.create_tenant("foo")
            end

            version = TenantedApplicationRecord.with_tenant("foo") do
              User.connection_pool.migration_context.current_version
            end

            assert_equal(20250213005959, version)
            assert_same_elements([ "id", "email", "created_at", "updated_at", "age" ],
                                 User.new.attributes.keys)
          end
        end
      end
    end
  end

  describe "logging" do
    for_each_scenario do
      test "database logs should emit the tenant name" do
        TenantedApplicationRecord.create_tenant("foo")

        log = capture_log do
          TenantedApplicationRecord.with_tenant("foo") do
            User.count
          end
        end

        assert_includes(log.string, "[tenant=foo]")
      end
    end

    with_scenario(:primary_named_db, :primary_record) do
      describe "config log_tenant_tag" do
        describe "true" do
          setup { Rails.application.config.active_record_tenanted.log_tenant_tag = true }

          describe "untenanted" do
            test "logs still work" do
              log = capture_rails_log do
                Rails.logger.info("hello")
              end

              assert_equal("hello", log.string.strip)
            end
          end

          describe "tenanted" do
            test "database logs should emit the tenant name" do
              TenantedApplicationRecord.create_tenant("foo")

              log = capture_rails_log do
                TenantedApplicationRecord.with_tenant("foo") do
                  Rails.logger.info("hello")
                end
              end

              assert_equal("[tenant=foo] hello", log.string.strip)
            end
          end
        end

        describe "false" do
          setup { Rails.application.config.active_record_tenanted.log_tenant_tag = false }

          test "database logs should not emit the tenant name" do
            TenantedApplicationRecord.create_tenant("foo")

            log = capture_rails_log do
              TenantedApplicationRecord.with_tenant("foo") do
                Rails.logger.info("hello")
              end
            end

            assert_equal("hello", log.string.strip)
          end
        end
      end
    end
  end

  describe "#tenant" do
    for_each_scenario do
      describe "created in untenanted context" do
        setup { with_schema_cache_dump_file }

        test "returns nil" do
          user = User.new(email: "user1@example.org")
          assert_nil(user.tenant)
        end
      end

      describe "created in tenanted context" do
        setup { TenantedApplicationRecord.create_tenant("foo") }

        test "returns the tenant name even outside of tenant context" do
          ids = []

          user = TenantedApplicationRecord.with_tenant("foo") do
            User.new(email: "user1@example.org")
          end
          assert_equal("foo", user.tenant)

          user = TenantedApplicationRecord.with_tenant("foo") do
            User.create(email: "user1@example.org")
          end
          assert_equal("foo", user.tenant)
          ids << user.id

          user = TenantedApplicationRecord.with_tenant("foo") do
            User.create!(email: "user1@example.org")
          end
          assert_equal("foo", user.tenant)
          ids << user.id

          TenantedApplicationRecord.with_tenant("foo") do
            ids.each do |id|
              assert_equal("foo", User.find(user.id).tenant)
            end
          end
        end
      end

      describe "created by #load_async in another context" do
        setup do
          TenantedApplicationRecord.create_tenant("foo")
          TenantedApplicationRecord.create_tenant("bar")
        end

        test "is set correctly" do
          TenantedApplicationRecord.with_tenant("foo") do
            @user = User.create!(email: "foo@example.org")
            @users = User.where(email: "foo@example.org").load_async
            assert_predicate @users, :scheduled?
          end

          TenantedApplicationRecord.with_tenant("bar") do
            assert_predicate @users, :scheduled?
            @users.to_a
            assert_equal [ @user ], @users
            assert_equal "foo", @user.tenant
            assert_equal "foo", @users.first.tenant
          end
        end
      end
    end
  end

  describe "#cache_key" do
    for_each_scenario do
      describe "created in untenanted context" do
        setup { with_schema_cache_dump_file }

        test "includes the tenant name" do
          user = User.new(email: "user1@example.org")

          assert_equal("users/new", user.cache_key)
        end
      end

      describe "created in tenanted context" do
        test "includes the tenant name" do
          user = TenantedApplicationRecord.create_tenant("foo") do
            User.create!(email: "user1@example.org")
          end

          assert_equal("users/1?tenant=foo", user.cache_key)

          TenantedApplicationRecord.with_tenant("foo") do
            assert_equal("users/1?tenant=foo", User.find(user.id).cache_key)
          end
        end
      end
    end
  end
end
