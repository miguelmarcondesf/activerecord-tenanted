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
      end
    end
  end
end
