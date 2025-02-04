# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    class Railtie < ::Rails::Railtie
      config.before_configuration do
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, _, config|
            next unless config.fetch(:tenanted, false)
            ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig.new(env_name, name, config)
          end
        end
      end

      initializer "active_record_tenanted.base_records" do
        ActiveSupport.on_load(:active_record) do
          prepend ActiveRecord::Tenanted::Base
        end
      end

      initializer "active_record-tenanted.monkey_patches.active_record" do
        ActiveSupport.on_load(:active_record) do
          # require "rails/generators/active_record/migration.rb"
          # ActiveRecord::Generators::Migration.prepend(ActiveRecord::Tenanted::Patches::Migration)
          ActiveRecord::Tasks::DatabaseTasks.prepend(ActiveRecord::Tenanted::Patches::DatabaseTasks)
        end
      end
    end
  end
end
