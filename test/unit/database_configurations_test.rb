# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::DatabaseConfigurations do
  let(:all_configs) { ActiveRecord::Base.configurations.configs_for(include_hidden: true) }
  let(:tenanted_config) { all_configs.find { |c| c.configuration_hash[:tenanted] } }

  describe Rails do
    with_scenario(:primary_named_db, :primary_record) do
      test "instantiates a RootConfig for the tenanted database" do
        assert_equal(
          {
            "tenanted" => ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig,
            "shared" => ActiveRecord::DatabaseConfigurations::HashConfig,
          },
          all_configs.each_with_object({}) { |c, h| h[c.name] = c.class }
        )
      end

      test "the RootConfig has tasks turned off by default" do
        assert_not tenanted_config.database_tasks?
      end
    end
  end

  describe "RootConfig" do
    describe ".database_path_for" do
      let(:config_hash) { { adapter: "sqlite3", database: "db/tenanted/%{tenant}/main.sqlite3" } }
      let(:config) { ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig.new("test", "foo", config_hash) }

      test "returns the path for a tenant" do
        assert_equal("db/tenanted/foo/main.sqlite3", config.database_path_for("foo"))
      end

      test "raises if the tenant name contains a path separator" do
        assert_raises(ActiveRecord::Tenanted::BadTenantNameError) { config.database_path_for("foo/bar") }
      end
    end

    for_each_scenario do
      test "raises if a connection is attempted" do
        assert(tenanted_config)
        assert_raises(ActiveRecord::Tenanted::NoTenantError) { tenanted_config.new_connection }
      end

      describe ".tenants" do
        test "returns an array of existing tenants" do
          assert_empty(tenanted_config.tenants)

          TenantedApplicationRecord.while_tenanted("foo") { User.count }

          assert_equal([ "foo" ], tenanted_config.tenants)

          TenantedApplicationRecord.while_tenanted("bar") { User.count }

          assert_same_elements([ "foo", "bar" ], tenanted_config.tenants)

          TenantedApplicationRecord.destroy_tenant("foo")

          assert_equal([ "bar" ], tenanted_config.tenants)
        end

        test "handles non-alphanumeric characters" do
          assert_empty(tenanted_config.tenants)

          crazy_name = 'a~!@#$%^&*()_-+=:;[{]}|,.?9' # please don't do this
          TenantedApplicationRecord.while_tenanted(crazy_name) { User.count }

          assert_equal([ crazy_name ], tenanted_config.tenants)
        end
      end
    end
  end

  describe "TenantConfig" do
    describe "#primary?" do
      for_each_scenario({ primary_db: [ :primary_record ], primary_named_db: [ :primary_record ] }) do
        it "returns true" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_predicate(config, :primary?)
        end
      end

      with_scenario(:secondary_db, :primary_record) do
        it "returns false" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_not_predicate(config, :primary?)
        end
      end
    end

    describe "schema dump" do
      with_scenario(:primary_db, :primary_record) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_equal("schema.rb", config.schema_dump)
        end

        test "can be overridden" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }

          config_hash = config.configuration_hash.dup.tap do |h|
            h[:schema_dump] = "custom_file_name.rb"
          end.freeze
          config.instance_variable_set(:@configuration_hash, config_hash)

          assert_equal("custom_file_name.rb", config.schema_dump)
        end
      end

      with_scenario(:primary_named_db, :primary_record) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_equal("schema.rb", config.schema_dump)
        end
      end

      with_scenario(:secondary_db, :primary_record) do
        test "to a named dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_equal("tenanted_schema.rb", config.schema_dump)
        end
      end
    end

    describe "schema cache dump" do
      with_scenario(:primary_db, :primary_record) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          path = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)

          expected = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "schema_cache.yml")
          assert_equal(expected, path)
        end

        test "can be overridden" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }

          config_hash = config.configuration_hash.dup.tap do |h|
            h[:schema_cache_path] = "db/custom_file_name.rb"
          end.freeze
          config.instance_variable_set(:@configuration_hash, config_hash)
          path = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)

          assert_equal("db/custom_file_name.rb", path)
        end
      end

      with_scenario(:primary_named_db, :primary_record) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          path = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)

          expected = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "schema_cache.yml")
          assert_equal(expected, path)
        end
      end

      with_scenario(:secondary_db, :primary_record) do
        test "to a named dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          path = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)

          expected = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "tenanted_schema_cache.yml")
          assert_equal(expected, path)
        end
      end
    end
  end
end
