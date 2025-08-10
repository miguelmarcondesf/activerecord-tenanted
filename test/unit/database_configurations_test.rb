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
    describe ".database_path_for and .tenants" do
      let(:config_hash) { { adapter: "sqlite3", database: database } }
      let(:config) { ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig.new("test", "foo", config_hash) }

      describe "file path" do
        let(:dir) { Dir.mktmpdir("database-path-for-tenants") }
        let(:database) { "storage/db/tenanted/%{tenant}/main.sqlite3" }

        test "returns the path for a tenant" do
          assert_equal("storage/db/tenanted/foo/main.sqlite3", config.database_path_for("foo"))
        end

        test "parallel test workers have unique files" do
          config.test_worker_id = 99

          assert_equal("storage/db/tenanted/foo/main.sqlite3_99", config.database_path_for("foo"))
        end

        test "raises if the tenant name contains a path separator" do
          assert_raises(ActiveRecord::Tenanted::BadTenantNameError) { config.database_path_for("foo/bar") }
        end

        test "raises if the tenant name contains a quote or double-quote or back-quote" do
          assert_raises(ActiveRecord::Tenanted::BadTenantNameError) { config.database_path_for("foo'bar") }
          assert_raises(ActiveRecord::Tenanted::BadTenantNameError) { config.database_path_for("foo\"bar") }
          assert_raises(ActiveRecord::Tenanted::BadTenantNameError) { config.database_path_for("foo`bar") }
        end

        test "returns all tenants" do
          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end

        test "parallel test worker returns all tenants" do
          config.test_worker_id = 99

          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end
      end

      describe "absolute URI" do
        let(:dir) { Dir.mktmpdir("database-path-for-tenants") }
        let(:database) { "file:#{dir}/storage/db/tenanted/%{tenant}/main.sqlite3" }

        test "returns the path for a tenant" do
          assert_equal("file:#{dir}/storage/db/tenanted/foo/main.sqlite3", config.database_for("foo"))
          assert_equal("#{dir}/storage/db/tenanted/foo/main.sqlite3", config.database_path_for("foo"))
        end

        test "parallel test workers have unique files" do
          config.test_worker_id = 99

          assert_equal("file:#{dir}/storage/db/tenanted/foo/main.sqlite3_99", config.database_for("foo"))
          assert_equal("#{dir}/storage/db/tenanted/foo/main.sqlite3_99", config.database_path_for("foo"))
        end

        test "returns all tenants" do
          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end
          end

          assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
        end

        test "parallel test worker returns all tenants" do
          config.test_worker_id = 99

          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end
      end

      describe "absolute URI with query params" do
        let(:dir) { Dir.mktmpdir("database-path-for-tenants") }
        let(:database) { "file:#{dir}/storage/db/tenanted/%{tenant}/main.sqlite3?vfs=unix-dotfile" }

        test "returns the path for a tenant" do
          assert_equal("file:#{dir}/storage/db/tenanted/foo/main.sqlite3?vfs=unix-dotfile", config.database_for("foo"))
          assert_equal("#{dir}/storage/db/tenanted/foo/main.sqlite3", config.database_path_for("foo"))
        end

        test "parallel test workers have unique files" do
          config.test_worker_id = 99

          assert_equal("file:#{dir}/storage/db/tenanted/foo/main.sqlite3_99?vfs=unix-dotfile", config.database_for("foo"))
          assert_equal("#{dir}/storage/db/tenanted/foo/main.sqlite3_99", config.database_path_for("foo"))
        end

        test "returns all tenants" do
          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end
          end

          assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
        end

        test "parallel test worker returns all tenants" do
          config.test_worker_id = 99

          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end
      end

      describe "relative URI" do
        let(:dir) { Dir.mktmpdir("database-path-for-tenants") }
        let(:database) { "file:storage/db/tenanted/%{tenant}/main.sqlite3" }

        test "returns the path for a tenant" do
          assert_equal("file:storage/db/tenanted/foo/main.sqlite3", config.database_for("foo"))
          assert_equal("storage/db/tenanted/foo/main.sqlite3", config.database_path_for("foo"))
        end

        test "parallel test workers have unique files" do
          config.test_worker_id = 99

          assert_equal("file:storage/db/tenanted/foo/main.sqlite3_99", config.database_for("foo"))
          assert_equal("storage/db/tenanted/foo/main.sqlite3_99", config.database_path_for("foo"))
        end

        test "returns all tenants" do
          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end

        test "parallel test worker returns all tenants" do
          config.test_worker_id = 99

          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end
      end

      describe "relative URI with query params" do
        let(:dir) { Dir.mktmpdir("database-path-for-tenants") }
        let(:database) { "file:storage/db/tenanted/%{tenant}/main.sqlite3?vfs=unix-dotfile" }

        test "returns the path for a tenant" do
          assert_equal("file:storage/db/tenanted/foo/main.sqlite3?vfs=unix-dotfile", config.database_for("foo"))
          assert_equal("storage/db/tenanted/foo/main.sqlite3", config.database_path_for("foo"))
        end

        test "parallel test workers have unique files" do
          config.test_worker_id = 99

          assert_equal("file:storage/db/tenanted/foo/main.sqlite3_99?vfs=unix-dotfile", config.database_for("foo"))
          assert_equal("storage/db/tenanted/foo/main.sqlite3_99", config.database_path_for("foo"))
        end

        test "returns all tenants" do
          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              FileUtils.mkdir_p("storage/db/tenanted/#{tenant}")
              FileUtils.touch("storage/db/tenanted/#{tenant}/main.sqlite3")
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end

        test "parallel test worker returns all tenants" do
          config.test_worker_id = 99

          Dir.chdir(dir) do
            [ "foo", "bar", "baz" ].each do |tenant|
              path = config.database_path_for(tenant)
              FileUtils.mkdir_p(File.dirname(path))
              FileUtils.touch(path)
            end

            assert_equal(Set.new(config.tenants), Set.new([ "foo", "bar", "baz" ]))
          end
        end
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

          TenantedApplicationRecord.create_tenant("foo")

          assert_equal([ "foo" ], tenanted_config.tenants)

          TenantedApplicationRecord.create_tenant("bar")

          assert_same_elements([ "foo", "bar" ], tenanted_config.tenants)

          TenantedApplicationRecord.destroy_tenant("foo")

          assert_equal([ "bar" ], tenanted_config.tenants)
        end
      end
    end

    with_scenario(:primary_db, :primary_record) do
      test "handles non-alphanumeric characters" do
        assert_empty(tenanted_config.tenants)

        crazy_name = 'a~!@#$%^&*()_-+=:;[{]}|,.?9' # please don't do this
        TenantedApplicationRecord.create_tenant(crazy_name)

        assert_equal([ crazy_name ], tenanted_config.tenants)
      end
    end
  end

  describe "TenantConfig" do
    describe "#primary?" do
      for_each_scenario({ primary_db: [ :primary_record ], primary_named_db: [ :primary_record ] }) do
        it "returns true" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          assert_predicate(config, :primary?)
        end
      end

      with_scenario(:secondary_db, :primary_record) do
        it "returns false" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          assert_not_predicate(config, :primary?)
        end
      end
    end

    describe "implicit file creation" do
      with_scenario(:primary_db, :primary_record) do
        # This is probably not behavior we want, long-term. See notes about the sqlite3 adapter in
        # tenant.rb. This test is descriptive, not prescriptive.
        test "creates a file if one does not exist" do
          config = tenanted_config.new_tenant_config("foo")
          conn = config.new_connection

          assert_not(File.exist?(config.database))

          conn.execute("SELECT 1")

          assert(File.exist?(config.database))
          assert_operator(File.size(config.database), :>, 0)
        end
      end
    end

    describe "schema dump" do
      with_scenario(:primary_db, :primary_record) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          assert_equal("schema.rb", config.schema_dump)
        end

        test "can be overridden" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }

          config_hash = config.configuration_hash.dup.tap do |h|
            h[:schema_dump] = "custom_file_name.rb"
          end.freeze
          config.instance_variable_set(:@configuration_hash, config_hash)

          assert_equal("custom_file_name.rb", config.schema_dump)
        end
      end

      with_scenario(:primary_named_db, :primary_record) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          assert_equal("schema.rb", config.schema_dump)
        end
      end

      with_scenario(:secondary_db, :primary_record) do
        test "to a named dump file" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          assert_equal("tenanted_schema.rb", config.schema_dump)
        end
      end

      with_scenario(:primary_uri_db, :primary_record) do
        test "the URI is preserved in the config" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          assert_operator(config.database, :start_with?, "file:")
          assert_operator(config.database, :end_with?, "?foo=bar")
        end
      end
    end

    describe "schema cache dump" do
      with_scenario(:primary_db, :primary_record) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          path = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)

          expected = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "schema_cache.yml")
          assert_equal(expected, path)
        end

        test "can be overridden" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }

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
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          path = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)

          expected = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "schema_cache.yml")
          assert_equal(expected, path)
        end
      end

      with_scenario(:secondary_db, :primary_record) do
        test "to a named dump file" do
          config = TenantedApplicationRecord.create_tenant("foo") { User.connection_db_config }
          path = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)

          expected = File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, "tenanted_schema_cache.yml")
          assert_equal(expected, path)
        end
      end
    end
  end
end
