# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Testing
      def self.connection_class
        Rails.application.config.active_record_tenanted.connection_class&.constantize
      end

      module TestCase
        extend ActiveSupport::Concern

        included do
          if klass = ActiveRecord::Tenanted::Testing.connection_class
            klass.current_tenant = "#{Rails.env}-tenant"

            parallelize_setup do |worker|
              klass.current_tenant = "#{Rails.env}-tenant-#{worker}"
            end

            # clean up any non-default tenants left over from the last test run
            klass.tenants.each do |tenant|
              next if tenant.start_with?("#{Rails.env}-tenant")
              klass.destroy_tenant(tenant)
            end
          end
        end
      end

      module IntegrationTest
        extend ActiveSupport::Concern

        included do
          setup do
            if klass = ActiveRecord::Tenanted::Testing.connection_class
              integration_session.host = "#{klass.current_tenant}.example.com"
            end
          end
        end
      end

      module IntegrationSession
        extend ActiveSupport::Concern

        prepended do
          # I'd prefer to just wrap `#process` here, but there are some method_missing conflicts
          # because there are so many modules mixed into the Session instance, and as currently
          # written we can't call `super` on that method.
          #
          # But we can call `super `on the verb methods mixed in by Integration::RequestHelpers.
          [ :delete, :follow_redirect!, :get, :head, :options, :patch, :post, :put ].each do |method|
            class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
              def #{method}(...)
                if klass = ActiveRecord::Tenanted::Testing.connection_class
                  klass.while_untenanted { super }
                else
                  super
                end
              end
            RUBY
          end
        end
      end

      module TestFixtures
        def transactional_tests_for_pool?(pool)
          config = pool.db_config

          # Prevent the tenanted RootConfig from creating transactional fixtures on an unnecessary
          # database, which would result in sporadic locking errors.
          is_root_config = config.instance_of?(Tenanted::DatabaseConfigurations::RootConfig)

          # Any tenanted database that isn't the default test fixture database should not be wrapped
          # in a transaction, for a couple of reasons:
          #
          # 1. we migrate the database using a temporary pool, which will wrap the schema load in a
          #    transaction that will not be visible to any connection used by the code under test to
          #    insert data.
          # 2. having an open transaction will prevent the test from being able to destroy the tenant.
          is_non_default_tenant = (
            config.instance_of?(Tenanted::DatabaseConfigurations::TenantConfig) &&
            !config.tenant.start_with?("#{Rails.env}-tenant")
          )

          return false if is_root_config || is_non_default_tenant

          super
        end
      end
    end
  end
end
