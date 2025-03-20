# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    # instance methods common to both Tenant and Subtenant
    module TenantCommon # :nodoc:
      extend ActiveSupport::Concern

      prepended do
        attr_reader :tenant

        after_initialize :initialize_tenant_attribute
        before_save :ensure_tenant_context_safety
      end

      def cache_key
        if tenant
          "#{super}?tenant=#{tenant}"
        else
          super
        end
      end

      def to_global_id(options = {})
        super(options.merge(tenant: tenant))
      end

      def to_signed_global_id(options = {})
        super(options.merge(tenant: tenant))
      end

      private def initialize_tenant_attribute
        @tenant = self.class.current_tenant
      end

      private def ensure_tenant_context_safety
        self_tenant = self.tenant
        current_tenant = self.class.current_tenant

        if self_tenant != current_tenant
          raise WrongTenantError,
                "#{self.class} model belongs to tenant #{self_tenant.inspect}, " \
                "but current tenant is #{current_tenant.inspect}"
        end
      end
    end

    module Tenant
      extend ActiveSupport::Concern

      # This is a sentinel value used to indicate that the class is not currently tenanted.
      #
      # It's the default value returned by `current_shard` when the class is not tenanted. The
      # `current_tenant` method's job is to recognizes that sentinel value and return `nil`, because
      # Active Record itself does not recognize `nil` as a valid shard value.
      UNTENANTED_SENTINEL = Object.new.freeze # :nodoc:

      class_methods do
        def tenanted?
          true
        end

        def current_tenant
          shard = current_shard
          shard != UNTENANTED_SENTINEL ? shard : nil
        end

        def current_tenant=(tenant_name)
          tenant_name = tenant_name.to_s unless tenant_name == UNTENANTED_SENTINEL

          connection_class_for_self.connecting_to(shard: tenant_name, role: ActiveRecord.writing_role)
        end

        def tenant_exist?(tenant_name)
          # this will have to be an adapter-specific implementation if we support other than sqlite
          File.exist?(tenanted_root_config.database_path_for(tenant_name))
        end

        def with_tenant(tenant_name, prohibit_shard_swapping: true, &block)
          tenant_name = tenant_name.to_s unless tenant_name == UNTENANTED_SENTINEL

          if tenant_name == current_tenant
            yield
          else
            connection_class_for_self.connected_to(shard: tenant_name, role: ActiveRecord.writing_role) do
              prohibit_shard_swapping(prohibit_shard_swapping) do
                log_tenant_tag(tenant_name, &block)
              end
            end
          end
        end

        def create_tenant(tenant_name, if_not_exists: false, &block)
          if tenant_exist?(tenant_name)
            return if if_not_exists
            raise TenantExistsError
          end

          # NOTE: This is obviously a sqlite-specific implementation.
          # TODO: Add a `create_database` method upstream in the sqlite3 adapter, and call it.
          #       Then this would delegate to the adapter and become adapter-agnostic.
          database_path = tenanted_root_config.database_path_for(tenant_name)
          FileUtils.mkdir_p(File.dirname(database_path))
          FileUtils.touch(database_path)

          with_tenant(tenant_name) do
            connection_pool
            yield if block_given?
          end
        end

        def destroy_tenant(tenant_name)
          return unless tenant_exist?(tenant_name)

          with_tenant(tenant_name) do
            lease_connection.send(:log, "/* destroying tenant database */", "DESTROY [tenant=#{tenant_name}]")
          ensure
            remove_connection
          end

          # NOTE: This is obviously a sqlite-specific implementation.
          # TODO: Create a `drop_database` method upstream in the sqlite3 adapter, and call it.
          #       Then this would delegate to the adapter and become adapter-agnostic.
          FileUtils.rm(tenanted_root_config.database_path_for(tenant_name))
        end

        def tenants
          tenanted_root_config.tenants
        end

        def with_each_tenant(&block)
          tenants.each { |tenant| with_tenant(tenant) { yield tenant } }
        end

        # This method is really only intended to be used for testing.
        def without_tenant(&block) # :nodoc:
          with_tenant(ActiveRecord::Tenanted::Tenant::UNTENANTED_SENTINEL, prohibit_shard_swapping: false, &block)
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
            Tenanted::UntenantedConnectionPool.new(tenanted_root_config, self)
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
          unless tenant_exist?(tenant)
            raise TenantDoesNotExistError, "The referenced tenant #{tenant.inspect} does not exist."
          end

          config = tenanted_root_config.new_tenant_config(tenant)

          establish_connection(config)
          ActiveRecord::Tenanted::DatabaseTasks.migrate(config)
        end

        private def retrieve_connection_pool(strict:)
          connection_handler.retrieve_connection_pool(connection_specification_name,
                                                      role: current_role,
                                                      shard: current_tenant,
                                                      strict: strict)
        end

        private def log_tenant_tag(tenant_name, &block)
          if Rails.application.config.active_record_tenanted.log_tenant_tag
            Rails.logger.tagged("tenant=#{tenant_name}", &block)
          else
            yield
          end
        end
      end

      prepended do
        self.default_shard = ActiveRecord::Tenanted::Tenant::UNTENANTED_SENTINEL

        prepend TenantCommon
      end
    end
  end
end
