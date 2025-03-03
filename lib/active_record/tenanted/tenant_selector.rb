# frozen_string_literal: true

require "rack/contrib"

module ActiveRecord
  module Tenanted
    class TenantSelector
      attr_reader :app, :tenanted_class_name, :tenant_resolver

      def initialize(app, tenanted_class_name, tenant_resolver)
        @app = app
        @tenant_resolver = tenant_resolver
        @tenanted_class_name = tenanted_class_name
      end

      def call(env)
        request = ActionDispatch::Request.new(env)
        tenant_name = tenant_resolver.call(request)

        unless tenant_name.present?
          # run the request without wrapping it in a tenanted context
          @app.call(env)
        else
          if tenanted_class.tenant_exist?(tenant_name)
            tenanted_class.while_tenanted(tenant_name) { @app.call(env) }
          else
            Rails.logger.info("ActiveRecord::Tenanted::TenantSelector: Tenant not found: #{tenant_name.inspect}")
            Rack::NotFound.new(Rails.root.join("public/404.html")).call(env)
          end
        end
      end

      def tenanted_class
        # Note: we'll probably want to cache this when we look at performance, but don't cache it
        # when class reloading is enabled.
        @tenanted_class_name.constantize
      end
    end
  end
end
