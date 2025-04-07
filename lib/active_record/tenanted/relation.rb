# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Relation # :nodoc:
      def initialize(...)
        super
        @tenant = @model.current_tenant
      end

      def instantiate_records(...)
        super.tap do |records|
          records.each { |record| record.instance_variable_set(:@tenant, @tenant) }
        end
      end
    end
  end
end
