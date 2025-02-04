# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Subtenant
      extend ActiveSupport::Concern

      class_methods do
        def tenanted?
          true
        end

        def tenanted_with_class
          klass = @tenanted_subtenant_of&.constantize || superclass.tenanted_with_class

          raise Error, "Class #{klass} is not tenanted" unless klass.tenanted?
          raise Error, "Class #{klass} is not a connection class" unless klass.abstract_class?

          klass
        end

        def connection_pool
          tenanted_with_class.connection_pool
        end
      end
    end
  end
end
