# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module DatabaseConfigurations
      class BaseConfig < ActiveRecord::DatabaseConfigurations::HashConfig
        attr_accessor :test_worker_id

        def initialize(...)
          super
          @test_worker_id = nil
        end

        def database_tasks?
          false
        end

        def database_for(tenant_name)
          tenant_name = tenant_name.to_s

          validate_tenant_name(tenant_name)

          path = sprintf(database, tenant: tenant_name)

          if test_worker_id
            test_worker_path(path)
          else
            path
          end
        end

        def database_path_for(tenant_name)
          coerce_path(database_for(tenant_name))
        end

        def tenants
          glob = database_path_for("*")
          scanner = Regexp.new(database_path_for("(.+)"))

          Dir.glob(glob).map do |path|
            result = path.scan(scanner).flatten.first
            if result.nil?
              warn "WARN: ActiveRecord::Tenanted: Cannot parse tenant name from filename #{path.inspect}. " \
                   "This is a bug, please report it to https://github.com/basecamp/activerecord-tenanted/issues"
            end
            result
          end
        end

        def new_tenant_config(tenant_name)
          config_name = "#{name}_#{tenant_name}"
          config_hash = configuration_hash.dup.tap do |hash|
            hash[:tenant] = tenant_name
            hash[:database] = database_for(tenant_name)
            hash[:database_path] = database_path_for(tenant_name)
            hash[:tenanted_config_name] = name
          end
          Tenanted::DatabaseConfigurations::TenantConfig.new(env_name, config_name, config_hash)
        end

        def new_connection
          raise NoTenantError, "Cannot use an untenanted ActiveRecord::Base connection. " \
                               "If you have a model that inherits directly from ActiveRecord::Base, " \
                               "make sure to use 'subtenant_of'. In development, you may see this error " \
                               "if constant reloading is not being done properly."
        end

        private
          # A sqlite database path can be a file path or a URI (either relative or absolute).
          # We can't parse it as a standard URI in all circumstances, though, see https://sqlite.org/uri.html
          def coerce_path(path)
            if path.start_with?("file:/")
              URI.parse(path).path
            elsif path.start_with?("file:")
              URI.parse(path.sub(/\?.*$/, "")).opaque
            else
              path
            end
          end

          def validate_tenant_name(tenant_name)
            if tenant_name.match?(%r{[/'"`]})
              raise BadTenantNameError, "Tenant name contains an invalid character: #{tenant_name.inspect}"
            end
          end

          def test_worker_path(path)
            test_worker_suffix = "_#{test_worker_id}"

            if path.start_with?("file:") && path.include?("?")
              path.sub(/(\?.*)$/, "#{test_worker_suffix}\\1")
            else
              path + test_worker_suffix
            end
          end
      end
    end
  end
end
