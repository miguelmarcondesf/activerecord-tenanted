# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::DatabaseAdapter do
  describe ".adapter_for" do
    test "selects correct adapter for sqlite3" do
      adapter = ActiveRecord::Tenanted::DatabaseAdapter.adapter_for(create_config("sqlite3"))
      assert_instance_of ActiveRecord::Tenanted::DatabaseAdapters::SQLite, adapter
    end

    test "raises error for unsupported adapter" do
      unsupported_config = create_config("mongodb")

      error = assert_raises ActiveRecord::Tenanted::UnsupportedDatabaseError do
        ActiveRecord::Tenanted::DatabaseAdapter.adapter_for(unsupported_config)
      end

      assert_includes error.message, "Unsupported database adapter for tenanting: mongodb."
    end
  end

  describe "delegation" do
    ActiveRecord::Tenanted::DatabaseAdapter::ADAPTERS.each do |adapter, adapter_class_name|
      test "#{adapter} .create_database calls adapter's #create_database" do
        adapter_mock = Minitest::Mock.new
        adapter_mock.expect(:create_database, nil)

        adapter_class_name.constantize.stub(:new, adapter_mock) do
          ActiveRecord::Tenanted::DatabaseAdapter.create_database(create_config(adapter))
        end

        assert_mock adapter_mock
      end

      test "#{adapter} .drop_database calls adapter's #drop_database" do
        adapter_mock = Minitest::Mock.new
        adapter_mock.expect(:drop_database, nil)

        adapter_class_name.constantize.stub(:new, adapter_mock) do
          ActiveRecord::Tenanted::DatabaseAdapter.drop_database(create_config(adapter))
        end

        assert_mock adapter_mock
      end

      test "#{adapter} .database_exist? calls adapter's #database_exist?" do
        adapter_mock = Minitest::Mock.new
        adapter_mock.expect(:database_exist?, true)

        result = adapter_class_name.constantize.stub(:new, adapter_mock) do
          ActiveRecord::Tenanted::DatabaseAdapter.database_exist?(create_config(adapter))
        end

        assert_equal true, result
        assert_mock adapter_mock
      end

      test "#{adapter} .database_ready? calls adapter's #database_ready?" do
        adapter_mock = Minitest::Mock.new
        adapter_mock.expect(:database_ready?, true)

        result = adapter_class_name.constantize.stub(:new, adapter_mock) do
          ActiveRecord::Tenanted::DatabaseAdapter.database_ready?(create_config(adapter))
        end

        assert_equal true, result
        assert_mock adapter_mock
      end

      test "#{adapter} .tenant_databases calls adapter's #tenant_databases" do
        adapter_mock = Minitest::Mock.new
        adapter_mock.expect(:tenant_databases, [ "foo", "bar" ])

        result = adapter_class_name.constantize.stub(:new, adapter_mock) do
          ActiveRecord::Tenanted::DatabaseAdapter.tenant_databases(create_config(adapter))
        end

        assert_equal [ "foo", "bar" ], result
        assert_mock adapter_mock
      end

      test "#{adapter} .validate_tenant_name calls adapter's #validate_tenant_name" do
        adapter_mock = Minitest::Mock.new
        adapter_mock.expect(:validate_tenant_name, nil, [ "tenant1" ])

        adapter_class_name.constantize.stub(:new, adapter_mock) do
          ActiveRecord::Tenanted::DatabaseAdapter.validate_tenant_name(create_config(adapter), "tenant1")
        end

        assert_mock adapter_mock
      end

      test "#{adapter} .acquire_ready_lock calls adapter's #acquire_ready_lock" do
        fake_adapter = Object.new
        fake_adapter.define_singleton_method(:acquire_ready_lock) do |&blk|
          blk&.call
        end

        yielded = false
        result = adapter_class_name.constantize.stub(:new, fake_adapter) do
          ActiveRecord::Tenanted::DatabaseAdapter.acquire_ready_lock(create_config(adapter)) { yielded = true; :ok }
        end

        assert_equal true, yielded
        assert_equal :ok, result
      end
    end
  end

  private
    def create_config(adapter)
      ActiveRecord::DatabaseConfigurations::HashConfig.new(
        "test",
        "test_config",
        {
          adapter: adapter,
          database: "db_name",
        }
      )
    end
end
