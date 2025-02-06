# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Tenant do
  let(:all_configs) { ActiveRecord::Base.configurations.configs_for(include_hidden: true) }
  let(:tenanted_config) { all_configs.find { |c| c.configuration_hash[:tenanted] } }

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
      describe ".current_tenant" do
        test "is nil" do
          TenantedApplicationRecord.current_tenant = "foo"
          TenantedApplicationRecord.while_untenanted do
            assert_nil(TenantedApplicationRecord.current_tenant)
          end
        end
      end

      test "may allow shard swapping if explicitly asked" do
        TenantedApplicationRecord.current_tenant = "foo"
        TenantedApplicationRecord.while_untenanted do
          TenantedApplicationRecord.while_tenanted("bar") do
            assert_equal("bar", TenantedApplicationRecord.current_tenant)
          end
        end
      end
    end
  end

  describe ".current_tenant=" do
    for_each_scenario do
      test "sets tenant context" do
        assert_nil(TenantedApplicationRecord.current_tenant)

        TenantedApplicationRecord.current_tenant = "foo"

        assert_equal("foo", TenantedApplicationRecord.current_tenant)
        assert_nothing_raised { User.first }
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

      test "database should be migrated" do
        ActiveRecord::Migration.verbose = true

        TenantedApplicationRecord.while_tenanted("foo") do
          assert_output(/migrating.*create_table/m, nil) do
            User.first
          end
          assert_equal(20250203191115, User.connection_pool.migration_context.current_version)
        end
      end

      describe "when schema dump file exists" do
        setup do
          # migrate
          config = TenantedApplicationRecord.while_tenanted("foo") do
            User.count
            User.connection_db_config
          end

          # force a schema dump
          @db_dir, ActiveRecord::Tasks::DatabaseTasks.db_dir = ActiveRecord::Tasks::DatabaseTasks.db_dir, storage_path
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(config) do
            ActiveRecord::Tasks::DatabaseTasks.dump_schema(config)
          end
        end

        teardown do
          ActiveRecord::Tasks::DatabaseTasks.db_dir = @old_db_dir
        end

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
          setup do
            migrations_path = tenanted_config.configuration_hash[:migrations_paths]
            @new_migration_path = File.join(migrations_path, "20250203191116_create_posts.rb")

            File.open(@new_migration_path, "w") do |f|
              f.write(<<~RUBY)
                class CreatePosts < ActiveRecord::Migration[8.1]
                  def change
                    create_table :posts do |t|
                      t.string :title
                      t.timestamps
                    end
                  end
                end
              RUBY
            end
          end

          teardown do
            FileUtils.rm(@new_migration_path)
          end

          test "it runs the migrations after loading the schema" do
            ActiveRecord::Migration.verbose = true

            TenantedApplicationRecord.while_tenanted("bar") do
              assert_output(/migrating.*create_table/m, nil) do
                Post.first
              end
              assert_equal(20250203191116, User.connection_pool.migration_context.current_version)
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
