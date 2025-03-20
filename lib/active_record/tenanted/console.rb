# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Console # :nodoc:
      def start
        ActiveRecord::Tenanted::DatabaseTasks.set_current_tenant if Rails.env.local?
        super
      end
    end
  end
end
