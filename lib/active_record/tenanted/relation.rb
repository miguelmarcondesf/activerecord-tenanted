# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Relation # :nodoc:
      def initialize(...)
        super
        @tenant = @model.current_tenant if @model.tenanted?
      end

      def instantiate_records(...)
        super.tap do |records|
          if @tenant
            records.each do |record|
              record.instance_variable_set(:@tenant, @tenant)
            end
          end
        end
      end
    end
  end
end
