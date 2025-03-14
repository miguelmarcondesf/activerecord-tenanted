# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module StorageService # :nodoc:
      def initialize(root:, public: false, tenanted: false, **options)
        @root = root
        @public = public
        @tenanted = tenanted
      end

      def tenanted?
        @tenanted
      end

      def root
        if tenanted?
          unless klass = ActiveRecord::Tenanted.connection_class
            raise TenantConfigurationError, "Active Storage is tenanted, but no connection_class is configured"
          end

          unless tenant = klass.current_tenant
            raise NoTenantError, "Cannot access ActiveStorage Disk service without a tenant"
          end

          @root % { tenant: tenant }
        else
          @root
        end
      end
    end
  end
end
