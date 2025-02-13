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
      UNTENANTED_SENTINEL = Object.new.freeze # :nodoc:

      included do
        connecting_to(shard: UNTENANTED_SENTINEL, role: ActiveRecord.writing_role)
      end

      class_methods do
        def tenanted?
          true
        end

        def current_tenant
          shard = current_shard
          shard != UNTENANTED_SENTINEL ? shard.to_s : nil
        end

        def current_tenant=(tenant_name)
          connecting_to(shard: tenant_name, role: ActiveRecord.writing_role)
        end

        def tenant_exist?(tenant_name)
          # this will have to be an adapter-specific implementation if we support other than sqlite
          File.exist?(tenanted_root_config.database_path_for(tenant_name))
        end

        def while_tenanted(tenant_name, prohibit_shard_swapping: true, &block)
          connected_to(shard: tenant_name, role: ActiveRecord.writing_role) do
            prohibit_shard_swapping(prohibit_shard_swapping, &block)
          end
        end

        def create_tenant(tenant_name, &block)
          raise TenantExistsError if tenant_exist?(tenant_name)

          while_tenanted(tenant_name) do
            connection_pool
            yield if block_given?
          end
        end

        def destroy_tenant(tenant_name)
          return unless tenant_exist?(tenant_name)

          while_tenanted(tenant_name) do
            lease_connection.log("/* destroying tenant database */", "DESTROY [tenant=#{tenant_name}]")
          ensure
            remove_connection
          end

          FileUtils.rm(tenanted_root_config.database_path_for(tenant_name))
        end

        # This method is really only intended to be used for testing.
        def while_untenanted(&block) # :nodoc:
          while_tenanted(ActiveRecord::Tenanted::Tenant::UNTENANTED_SENTINEL, prohibit_shard_swapping: false, &block)
        end

        def connection_pool # :nodoc:
          if current_tenant
            pool = retrieve_connection_pool(strict: false)

            if pool.nil?
              _create_tenanted_pool
              pool = retrieve_connection_pool(strict: true)
            end

            pool
          else
            Tenanted::UntenantedConnectionPool.new(tenanted_root_config)
          end
        end

        def tenanted_root_config # :nodoc:
          ActiveRecord::Base.configurations.resolve(tenanted_config_name.to_sym)
        end

        def tenanted_config_name # :nodoc:
          @tenanted_config_name ||= (superclass.respond_to?(:tenanted_config_name) ? superclass.tenanted_config_name : nil)
        end

        def _create_tenanted_pool # :nodoc:
          # ensure all classes use the same connection pool
          return superclass._create_tenanted_pool unless connection_class?

          tenant = current_tenant
          root_config = tenanted_root_config
          tenant_name = "#{tenanted_config_name}_#{tenant}"
          config_hash = root_config.configuration_hash.dup.tap do |hash|
            hash[:tenant] = tenant
            hash[:database] = root_config.database_path_for(tenant)
            hash[:tenanted_config_name] = tenanted_config_name
          end
          config = Tenanted::DatabaseConfigurations::TenantConfig.new(root_config.env_name, tenant_name, config_hash)

          establish_connection(config)
          ensure_schema_migrations(config)
        end

        # this is essentially a simplified implementation of ActiveRecord::Tasks::DatabaseTasks.migrate
        private def ensure_schema_migrations(config)
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(config) do |conn|
            pool = conn.pool

            # initialize_database
            unless pool.schema_migration.table_exists?
              schema_dump_path = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(config)
              if schema_dump_path && File.exist?(schema_dump_path)
                ActiveRecord::Tasks::DatabaseTasks.load_schema(config)
              end
            end

            # migrate
            migrated = false
            if pool.migration_context.pending_migration_versions.present?
              pool.migration_context.migrate(nil)
              pool.schema_cache.clear!
              migrated = true
            end

            # dump the schema and schema cache
            if Rails.env.development? || ENV["AR_TENANT_SCHEMA_DUMP"].present?
              if migrated
                ActiveRecord::Tasks::DatabaseTasks.dump_schema(config)
              end

              cache_dump = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(config)
              if migrated || !File.exist?(cache_dump)
                ActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(pool, cache_dump)
              end
            end
          end
        end

        private def retrieve_connection_pool(strict:)
          connection_handler.retrieve_connection_pool(connection_specification_name,
                                                      role: current_role,
                                                      shard: current_tenant,
                                                      strict: strict)
        end
      end
    end
  end
end
