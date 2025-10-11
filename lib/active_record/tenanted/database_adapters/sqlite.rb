# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module DatabaseAdapters
      class SQLite # :nodoc:
        def initialize(db_config)
          @db_config = db_config
        end

        def create_database
          ensure_database_directory_exists
          FileUtils.touch(database_path)
        end

        def drop_database
          # Remove the SQLite database file and associated files
          FileUtils.rm_f(database_path)
          FileUtils.rm_f("#{database_path}-wal")  # Write-Ahead Logging file
          FileUtils.rm_f("#{database_path}-shm")  # Shared Memory file
        end

        def database_exist?
          File.exist?(database_path)
        end

        def database_ready?
          File.exist?(database_path) && !ActiveRecord::Tenanted::Mutex::Ready.locked?(database_path)
        end

        def tenant_databases
          glob = db_config.database_path_for("*")
          scanner = Regexp.new(db_config.database_path_for("(.+)"))

          Dir.glob(glob).filter_map do |path|
            result = path.scan(scanner).flatten.first
            if result.nil?
              Rails.logger.warn "ActiveRecord::Tenanted: Cannot parse tenant name from filename #{path.inspect}"
            end
            result
          end
        end

        def acquire_ready_lock(db_config, &block)
          ActiveRecord::Tenanted::Mutex::Ready.lock(database_path, &block)
        end

        def validate_tenant_name(tenant_name)
          if tenant_name.match?(%r{[/'"`]})
            raise BadTenantNameError, "Tenant name contains an invalid character: #{tenant_name.inspect}"
          end
        end

        def ensure_database_directory_exists
          return unless database_path

          database_dir = File.dirname(database_path)
          unless File.directory?(database_dir)
            FileUtils.mkdir_p(database_dir)
          end
        end

        private
          attr_reader :db_config

          def database_path
            db_config.database_path
          end
      end
    end
  end
end
