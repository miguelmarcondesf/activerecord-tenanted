# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Testing
      def self.connection_class
        Rails.application.config.active_record_tenanted.connection_class&.constantize
      end

      module TestCase
        extend ActiveSupport::Concern

        included do
          if klass = ActiveRecord::Tenanted::Testing.connection_class
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
            if klass = ActiveRecord::Tenanted::Testing.connection_class
              integration_session.host = "#{klass.current_tenant}.example.com"
            end
          end
        end
      end

      module IntegrationSession
        extend ActiveSupport::Concern

        prepended do
          # I'd prefer to just wrap `#process` here, but there are some method_missing conflicts
          # because there are so many modules mixed into the Session instance, and as currently
          # written we can't call `super` on that method.
          #
          # But we can call `super `on the verb methods mixed in by Integration::RequestHelpers.
          [ :delete, :follow_redirect!, :get, :head, :options, :patch, :post, :put ].each do |method|
            class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
              def #{method}(...)
                if klass = ActiveRecord::Tenanted::Testing.connection_class
                  klass.while_untenanted { super }
                else
                  super
                end
              end
            RUBY
          end
        end
      end
    end
  end
end
