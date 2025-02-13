# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Base
      extend ActiveSupport::Concern

      class_methods do
        def initialize(...)
          super

          @tenanted_config_name = nil
          @tenanted_subtenant_of = nil
        end

        def tenanted(config_name = "primary")
          raise Error, "Class #{self} is already tenanted" if tenanted?
          raise Error, "Class #{self} is not an abstract connection class" unless abstract_class?

          include Tenant

          self.connection_class = true
          @tenanted_config_name = config_name

          unless tenanted_root_config.configuration_hash[:tenanted]
            raise Error, "The '#{tenanted_config_name}' database is not configured as tenanted."
          end
        end

        def subtenant_of(class_name)
          include Subtenant

          @tenanted_subtenant_of = class_name
        end

        def tenanted?
          false
        end

        # TODO: This monkey patch shouldn't be necessary after 8.1 lands and the need for a
        # connection is removed. For details see https://github.com/rails/rails/pull/54348
        def _default_attributes # :nodoc:
          @default_attributes ||= begin
            # I've removed the `with_connection` block here.
            nil_connection = nil
            attributes_hash = columns_hash.transform_values do |column|
              ActiveModel::Attribute.from_database(column.name, column.default, type_for_column(nil_connection, column))
            end

            attribute_set = ActiveModel::AttributeSet.new(attributes_hash)
            apply_pending_attribute_modifications(attribute_set)
            attribute_set
          end
        end
      end
    end
  end
end
