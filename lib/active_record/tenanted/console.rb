# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Console # :nodoc:
      module IRBConsole
        def start
          ActiveRecord::Tenanted::DatabaseTasks.set_current_tenant if Rails.env.local?
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
