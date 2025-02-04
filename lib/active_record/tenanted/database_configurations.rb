# frozen_string_literal: true

require "active_record/database_configurations"

module ActiveRecord
  module Tenanted
    module DatabaseConfigurations
      class RootConfig < ActiveRecord::DatabaseConfigurations::HashConfig
        def database_tasks?
          false
        end

        def database_path_for(tenant_name)
          format_specifiers = {
            tenant: tenant_name,
          }
          database % format_specifiers
        end

        def new_connection
          raise NoTenantError, "Cannot use an untenanted ActiveRecord::Base connection. If you have a model that inherits directly from ActiveRecord::Base, make sure to use 'subtenant_of'. In development, you may see this error if constant reloading is not being done properly."
        end
      end

      class TenantConfig < ActiveRecord::DatabaseConfigurations::HashConfig
        def tenant
          configuration_hash.fetch(:tenant)
        end

        def new_connection
          conn = super
          log_addition = " [tenant=#{tenant}]"
          conn.instance_eval <<~CODE, __FILE__, __LINE__ + 1
            def log(sql, name = "SQL", binds = [], type_casted_binds = [], async: false, &block)
              name ||= ""
              name += "#{log_addition}"
              super(sql, name, binds, type_casted_binds, async: async, &block)
            end
          CODE
          conn
        end
      end
    end
  end
end
