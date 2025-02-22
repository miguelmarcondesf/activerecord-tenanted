# frozen_string_literal: true

require "globalid"

module ActiveRecord
  module Tenanted
    module GlobalId
      extend ActiveSupport::Concern

      included do
        def tenant
          params && params[:tenant]
        end
      end
    end
  end
end
