# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Testing
      module TestCase
        extend ActiveSupport::Concern

        included do
          if Rails.application.config.active_record_tenanted.connection_class.present?
            klass = Rails.application.config.active_record_tenanted.connection_class.constantize

            klass.current_tenant = "#{Rails.env}-tenant" if Rails.env.test?
            parallelize_setup do |worker|
              klass.current_tenant = "#{Rails.env}-tenant-#{worker}"
            end
          end
        end
      end

      module IntegrationTest
        extend ActiveSupport::Concern

        included do
          setup do
            if Rails.application.config.active_record_tenanted.connection_class.present?
              klass = Rails.application.config.active_record_tenanted.connection_class.constantize

              integration_session.host = "#{klass.current_tenant}.example.com"
            end
          end
        end
      end
    end
  end
end
