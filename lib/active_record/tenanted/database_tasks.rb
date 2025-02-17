# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module DatabaseTasks # :nodoc:
      extend self

      def migrate_all
        raise ArgumentError, "Could not find a tenanted database" unless root_config = root_database_config

        root_config.tenants.each do |tenant|
          tenant_config = root_config.new_tenant_config(tenant)
          migrate(tenant_config)
        end
      end

      def migrate_tenant(tenant_name)
        raise ArgumentError, "Could not find a tenanted database" unless root_config = root_database_config

        tenant_config = root_config.new_tenant_config(tenant_name)

        migrate(tenant_config)
      end

      def root_database_config
        db_configs = ActiveRecord::Base.configurations.configs_for(
          env_name: ActiveRecord::Tasks::DatabaseTasks.env,
          include_hidden: true
        )
        db_configs.detect { |c| c.configuration_hash[:tenanted] }
      end

      # This is essentially a simplified implementation of ActiveRecord::Tasks::DatabaseTasks.migrate
      def migrate(config)
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

      def verbose?
        ENV["VERBOSE"] ? ENV["VERBOSE"] != "false" : true
      end
    end
  end
end
