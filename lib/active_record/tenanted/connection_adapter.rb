# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module ConnectionAdapter # :nodoc:
      extend ActiveSupport::Concern

      prepended do
        attr_accessor :tenant
      end

      def log(sql, name = "SQL", binds = [], type_casted_binds = [], async: false, allow_retry: false, &block)
        name = [ name, "[tenant=#{tenant}]" ].compact.join(" ") if tenanted?
        super
      end

      def tenanted?
        tenant.present?
      end
    end
  end
end
