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
          raise BadTenantNameError, "Tenant name cannot contain path separators: #{tenant_name.inspect}" if tenant_name.include?("/")
          sprintf(database, tenant: tenant_name)
        end

        def tenants
          glob = sprintf(database, tenant: "*")
          scanner = Regexp.new(sprintf(database, tenant: "(.+)"))

          Dir.glob(glob).map do |path|
            result = path.scan(scanner).flatten.first
            if result.nil?
              warn "WARN: ActiveRecord::Tenanted: Cannot parse tenant name from filename #{path.inspect}. " \
                   "This is a bug, please report it to https://github.com/basecamp/active_record-tenanted/issues"
            end
            result
          end
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

        def tenanted_config_name
          configuration_hash.fetch(:tenanted_config_name)
        end

        def primary?
          ActiveRecord::Base.configurations.primary?(tenanted_config_name)
        end

        def schema_dump(format = ActiveRecord.schema_format)
          if configuration_hash.key?(:schema_dump) || primary?
            super
          else
            "#{tenanted_config_name}_#{schema_file_type(format)}"
          end
        end

        def default_schema_cache_path(db_dir = "db")
          if primary?
            super
          else
            File.join(db_dir, "#{tenanted_config_name}_schema_cache.yml")
          end
        end
      end
    end
  end
end
