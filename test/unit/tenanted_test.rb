# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted do
  with_scenario(:primary_db, :primary_record) do
    test ".connection_class" do
      Rails.application.config.active_record_tenanted.connection_class = "TenantedApplicationRecord"
      assert_equal TenantedApplicationRecord, ActiveRecord::Tenanted.connection_class

      Rails.application.config.active_record_tenanted.connection_class = nil
      assert_nil ActiveRecord::Tenanted.connection_class
    end
  end

  describe ".base_configs" do
    describe "single tenanted config" do
      for_each_db_scenario do
        test "returns the base config" do
          configs = ActiveRecord::Tenanted.base_configs
          assert_equal 1, configs.size
          assert_kind_of ActiveRecord::Tenanted::DatabaseConfigurations::BaseConfig, configs.first
        end
      end
    end

    describe "multiple tenanted configs" do
      let(:input_yml) { <<~YAML }
        test:
          primary:
            tenanted: true
            adapter: sqlite3
            database: "tmp"
          secondary:
            tenanted: true
            adapter: sqlite3
            database: "tmp"
          tertiary:
            tenanted: true
            adapter: sqlite3
            database: "tmp"
      YAML

      describe "passing configs directly" do
        test "returns all the tenanted base configs" do
          configurations = ActiveRecord::DatabaseConfigurations.new(YAML.load(input_yml))

          configs = ActiveRecord::Tenanted.base_configs(configurations)
          assert_equal 3, configs.size
          assert(configs.all? { ActiveRecord::Tenanted::DatabaseConfigurations::BaseConfig === _1 })
        end
      end

      with_db_scenario(:primary_db) do
        # override the actual database.yml
        let(:db_config_yml) { input_yml }

        test "returns all the tenanted base configs" do
          configs = ActiveRecord::Tenanted.base_configs
          assert_equal 3, configs.size
          assert(configs.all? { ActiveRecord::Tenanted::DatabaseConfigurations::BaseConfig === _1 })
        end
      end
    end
  end
end
