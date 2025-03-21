# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Mailer
      def url_options(...)
        super.tap do |options|
          if ActiveRecord::Tenanted.connection_class && options.key?(:host)
            options[:host] = sprintf(options[:host], tenant: ActiveRecord::Tenanted.connection_class.current_tenant)
          end
        end
      end
    end
  end
end
