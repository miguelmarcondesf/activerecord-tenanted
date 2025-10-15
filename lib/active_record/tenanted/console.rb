# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Console # :nodoc:
      module IRBConsole
        def start
          # TODO: we could be setting the current tenant for all tenanted configs.
          if Rails.env.local? && ActiveRecord::Tenanted.connection_class
            config = ActiveRecord::Tenanted.connection_class.connection_pool.db_config
            ActiveRecord::Tenanted::DatabaseTasks.new(config).set_current_tenant
          end
          super
        end
      end

      module ReloadHelper
        def execute
          tenant = if Rails.env.local? && (connection_class = ActiveRecord::Tenanted.connection_class)
            connection_class.current_tenant
          end

          super
        ensure
          # We need to reload the connection class to ensure that we get the new (reloaded) class.
          if tenant && (connection_class = ActiveRecord::Tenanted.connection_class)
            connection_class.current_tenant = tenant
          end
        end
      end
    end
  end
end
