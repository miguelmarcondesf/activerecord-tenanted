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
          if tenant_name.match?(%r{[/'"`]})
            raise BadTenantNameError, "Tenant name contains an invalid character: #{tenant_name.inspect}"
          end

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

        def new_tenant_config(tenant)
          tenant_name = "#{name}_#{tenant}"
          config_hash = configuration_hash.dup.tap do |hash|
            hash[:tenant] = tenant
            hash[:database] = database_path_for(tenant)
            hash[:tenanted_config_name] = name
          end
          Tenanted::DatabaseConfigurations::TenantConfig.new(env_name, tenant_name, config_hash)
        end

        def new_connection
          raise NoTenantError, "Cannot use an untenanted ActiveRecord::Base connection. " \
                               "If you have a model that inherits directly from ActiveRecord::Base, " \
                               "make sure to use 'subtenant_of'. In development, you may see this error " \
                               "if constant reloading is not being done properly."
        end
      end

      class TenantConfig < ActiveRecord::DatabaseConfigurations::HashConfig
        def tenant
          configuration_hash.fetch(:tenant)
        end

        def new_connection # :nodoc:
          super.tap do |conn|
            # Let's preserve the tenant name as a string literal in the log method for all tenanted
            # connections at construction time, so that regardless of whether we're in a proper
            # tenanted context we are able to log the tenant name when any tenanted connection is
            # used.
            #
            # TODO: this could be upstreamed as a shard-related feature unrelated to tenanting.
            conn.class_eval <<~CODE, __FILE__, __LINE__ + 1
              private def log(sql, name = "SQL", *args, **kwargs, &block)
                super(sql, "\#{name} [tenant=#{tenant}]", *args, **kwargs, &block)
              end
            CODE
          end
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

      # Invoked by the railtie
      def self.register_db_config_handler # :nodoc:
        ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, _, config|
          next unless config.fetch(:tenanted, false)

          ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig.new(env_name, name, config)
        end
      end
    end
  end
end
