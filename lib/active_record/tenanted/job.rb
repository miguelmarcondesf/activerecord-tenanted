# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Job # :nodoc:
      extend ActiveSupport::Concern

      included do
        attr_reader :tenant

        def initialize(...)
          super
          if klass = ActiveRecord::Tenanted.connection_class
            @tenant = klass.current_tenant
          end
        end

        def serialize
          super.merge!({ "tenant" => tenant })
        end

        def deserialize(job_data)
          super
          @tenant = job_data.fetch("tenant", nil)
        end

        def perform_now
          if tenant.present? && (klass = ActiveRecord::Tenanted.connection_class)
            klass.with_tenant(tenant) { super }
          else
            super
          end
        end
      end
    end
  end
end
