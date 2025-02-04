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
      end

      class TenantConfig < RootConfig
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
