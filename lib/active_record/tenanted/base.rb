# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Base
      extend ActiveSupport::Concern

      class_methods do
        def initialize(...)
          super

          @tenanted_config_name = nil
        end

        def tenanted(config_name = "primary")
          raise Error, "Class #{self} is already tenanted" if tenanted?
          raise Error, "Class #{self} is not an abstract connection class" unless abstract_class?

          include Tenant

          @tenanted_config_name = config_name
          self.connection_class = true
        end

        def tenanted_config_name
          @tenanted_config_name ||= (superclass.respond_to?(:tenanted_config_name) ? superclass.tenanted_config_name : nil)
        end

        def tenanted?
          tenanted_config_name.present?
        end
      end
    end
  end
end
