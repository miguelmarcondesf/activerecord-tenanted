# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::DatabaseConfigurations do
  let(:all_configs) { ActiveRecord::Base.configurations.configs_for(include_hidden: true) }
  let(:tenanted_config) { all_configs.find { |c| c.configuration_hash[:tenanted] } }

  describe Rails do
    with_scenario(:vanilla_named_primary, :tenanted_primary) do
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
    with_each_scenario do
      test "raises if a connection is attempted" do
        assert(tenanted_config)
        assert_raises(ActiveRecord::Tenanted::NoTenantError) { tenanted_config.new_connection }
      end
    end
  end

  describe "TenantConfig" do
    describe "schema dump" do
      with_scenario(:vanilla, :tenanted_primary) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_equal("schema.rb", config.schema_dump)
        end
      end

      with_scenario(:vanilla_named_primary, :tenanted_primary) do
        test "to the default primary dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_equal("schema.rb", config.schema_dump)
        end
      end

      with_scenario(:vanilla_named_primary, :tenanted_secondary) do
        test "to a named dump file" do
          config = TenantedApplicationRecord.while_tenanted("foo") { User.connection_db_config }
          assert_equal("schema.rb", config.schema_dump)
        end
      end
    end
  end
end
