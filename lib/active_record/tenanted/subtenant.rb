# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Subtenant
      extend ActiveSupport::Concern

      class_methods do
        def tenanted?
          true
        end

        def tenanted_subtenant_of
          # TODO: cache this / speed this up
          # but note that we should constantize as late as possible to avoid load order issues
          klass = @tenanted_subtenant_of&.constantize || superclass.tenanted_subtenant_of

          raise Error, "Class #{klass} is not tenanted" unless klass.tenanted?
          raise Error, "Class #{klass} is not a connection class" unless klass.abstract_class?

          klass
        end

        delegate :current_tenant, :connection_pool, to: :tenanted_subtenant_of
      end

      prepended do
        prepend TenantCommon
      end

      def tenanted?
        true
      end
    end
  end
end
