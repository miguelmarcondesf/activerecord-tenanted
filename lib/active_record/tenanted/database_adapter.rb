# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    class DatabaseAdapter # :nodoc:
      ADAPTERS = {
        "sqlite3" => "ActiveRecord::Tenanted::DatabaseAdapters::SQLite",
      }.freeze

      class << self
        def create_database(db_config)
          adapter_for(db_config).create_database
        end

        def drop_database(db_config)
          adapter_for(db_config).drop_database
        end

        def database_exist?(db_config)
          adapter_for(db_config).database_exist?
        end

        def database_ready?(db_config)
          adapter_for(db_config).database_ready?
        end

        def acquire_ready_lock(db_config, &block)
          adapter_for(db_config).acquire_ready_lock(db_config, &block)
        end

        def list_tenant_databases(db_config)
          adapter_for(db_config).list_tenant_databases
        end

        def validate_tenant_name(db_config, tenant_name)
          adapter_for(db_config).validate_tenant_name(tenant_name)
        end

        def adapter_for(db_config)
          adapter_class_name = ADAPTERS[db_config.adapter]

          if adapter_class_name.nil?
            raise ActiveRecord::Tenanted::UnsupportedDatabaseError,
                  "Unsupported database adapter for tenanting: #{db_config.adapter}. " \
                  "Supported adapters: #{ADAPTERS.keys.join(', ')}"
          end

          adapter_class_name.constantize.new(db_config)
        end
      end
    end
  end
end
