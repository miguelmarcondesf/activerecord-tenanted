# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    # I'm not happy with this class's design. When I circle back, I want to:
    #
    # - Extract code that's in TenantSelector and this class (request.subdomain)
    # - I don't love the `tenanted_connection` method, which only exists as a compromise so I can
    #   reliably wrap a method that may be defined after `tenanted` is called
    #
    module CableConnection # :nodoc:
      # this module is included into ActionCable::Connection::Base
      module Base
        extend ActiveSupport::Concern

        class_methods do
          def initialize(...)
            super

            @tenanted_connection_class = nil
          end

          def tenanted_connection(connection_class = "ApplicationRecord", &block)
            raise Error, "Class #{self} is already tenanted" if tenanted?

            prepend Tenant

            @tenanted_connection_class = connection_class
            @tenanted_connection_block = block
          end

          def tenanted?
            false
          end
        end
      end

      # this module is dynamically included if `tenanted_connection` is called
      module Tenant
        extend ActiveSupport::Concern

        class_methods do
          attr_accessor :tenanted_connection_block

          def tenanted?
            true
          end

          def tenanted_with_class
            klass = @tenanted_connection_class&.constantize

            raise Error, "Class #{klass} is not tenanted" unless klass.tenanted?
            raise Error, "Class #{klass} is not a connection class" unless klass.abstract_class?

            klass
          end
        end

        prepended do
          identified_by :current_tenant
          around_command :set_current_tenant
        end

        def connect
          unless (self.current_tenant = request.subdomain) &&
                 (klass = self.class.tenanted_with_class) &&
                 klass.tenant_exist?(current_tenant)
            reject_unauthorized_connection
          end

          if block = self.class.tenanted_connection_block
            set_current_tenant { instance_eval(&block) }
          end
        end

        def set_current_tenant(&block)
          self.current_tenant ||= request.subdomain

          tenanted_with_class.with_tenant(current_tenant, &block)
        end

        def tenanted_with_class
          self.class.tenanted_with_class
        end
      end
    end
  end
end
