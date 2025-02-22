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

      class Locator
        def locate(gid, options = {})
          ensure_tenant_context_safety(gid) if gid.model_class.tenanted?

          gid.model_class.find(gid.model_id)
        end

        private def ensure_tenant_context_safety(gid)
          tenant = gid.tenant
          raise MissingTenantError, "Tenant not present in #{gid.to_s.inspect}" unless tenant

          model_class = gid.model_class
          current_tenant = model_class.current_tenant
          unless current_tenant.present?
            raise NoTenantError, "Cannot connect to a tenanted database while untenanted (#{gid})"
          end

          if tenant != current_tenant
            raise WrongTenantError,
                  "GlobalID #{gid.to_s.inspect} does not belong the current tenant #{current_tenant.inspect}"
          end
        end
      end
    end
  end
end
