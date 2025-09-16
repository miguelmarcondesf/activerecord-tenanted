# frozen_string_literal: true

require "active_record/database_configurations"

module ActiveRecord
  module Tenanted
    module DatabaseConfigurations
      def self.register_db_config_handler # :nodoc:
        ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, _, config|
          next unless config.fetch(:tenanted, false)

          ActiveRecord::Tenanted::DatabaseConfigurations::BaseConfig.new(env_name, name, config)
        end
      end
    end
  end
end
