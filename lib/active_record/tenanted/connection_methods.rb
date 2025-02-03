# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module ConnectionMethods
      extend ActiveSupport::Concern

      class_methods do
        def tenanted
        end
      end
    end
  end
end
