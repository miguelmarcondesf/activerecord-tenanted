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

# Do this here instead of the railtie so we register the handlers before Rails's rake tasks get
# loaded. If the handler is not present, then the BaseConfigs will not return false from
# `#database_tasks?` and the database tasks will get created anyway.
#
# TODO: This can be moved back into the railtie if https://github.com/rails/rails/pull/54959 is merged.
ActiveRecord::Tenanted::DatabaseConfigurations.register_db_config_handler
