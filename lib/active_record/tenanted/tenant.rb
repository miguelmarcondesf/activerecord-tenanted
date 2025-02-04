# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Tenant
      extend ActiveSupport::Concern

      # This is a sentinel value used to indicate that the class is not currently tenanted.
      #
      # It's the default value returned by `current_shard` when the class is not tenanted. The
      # `current_tenant` method's job is to recognizes that sentinel value and return `nil`, because
      # Active Record itself does not recognize `nil` as a valid shard value.
      UNTENANTED_SENTINEL = Object.new # :nodoc:

      included do
        connecting_to(shard: UNTENANTED_SENTINEL, role: ActiveRecord.writing_role)
      end

      class_methods do
        def tenanted?
          true
        end

        def tenanted_config_name
          @tenanted_config_name ||= (superclass.respond_to?(:tenanted_config_name) ? superclass.tenanted_config_name : nil)
        end

        def current_tenant
          shard = current_shard
          shard != UNTENANTED_SENTINEL ? shard.to_s : nil
        end

        def while_tenanted(tenant_name, &block)
          connected_to(shard: tenant_name, role: ActiveRecord.writing_role) do
            prohibit_shard_swapping(true, &block)
          end
        end

        def connection_pool
          raise NoTenantError unless current_tenant

          pool = connection_handler.retrieve_connection_pool(connection_specification_name, role: current_role, shard: current_tenant, strict: false)

          if pool.nil?
            create_tenanted_pool
            pool = connection_handler.retrieve_connection_pool(connection_specification_name, role: current_role, shard: current_tenant, strict: true)
          end

          pool
        end

        def create_tenanted_pool # :nodoc:
          # ensure all classes use the same connection pool
          return superclass.create_tenanted_pool unless connection_class?

          tenant = current_tenant
          base_config = ActiveRecord::Base.configurations.resolve(tenanted_config_name.to_sym)
          tenant_name = "#{tenanted_config_name}_#{tenant}"
          config_hash = base_config.configuration_hash.dup.tap do |hash|
            hash[:database] = base_config.database_path_for(tenant)
          end
          config = Tenanted::DatabaseConfigurations::TenantConfig.new(base_config.env_name, tenant_name, config_hash)

          establish_connection(config)
          ensure_schema_migrations(config)
        end

        def ensure_schema_migrations(config) # :nodoc:
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(config) do |conn|
            pool = conn.pool

            if pool.migration_context.pending_migration_versions.present?
              ActiveRecord::Tasks::DatabaseTasks.migrate(nil)
              # ActiveRecord::Tasks::DatabaseTasks.dump_schema(config) if Rails.env.development?
            end
          end
        end
      end
    end
  end
end
