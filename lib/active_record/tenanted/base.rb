# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Base
      extend ActiveSupport::Concern

      class_methods do
        def initialize(...)
          super

          @tenanted_config_name = nil
          @tenanted_subtenant_of = nil
        end

        def tenanted(config_name = "primary")
          raise Error, "Class #{self} is already tenanted" if tenanted?
          raise Error, "Class #{self} is not an abstract connection class" unless abstract_class?

          include Tenant

          self.connection_class = true
          @tenanted_config_name = config_name

          unless tenanted_root_config.configuration_hash[:tenanted]
            raise Error, "The '#{tenanted_config_name}' database is not configured as tenanted."
          end
        end

        def subtenant_of(class_name)
          include Subtenant

          @tenanted_subtenant_of = class_name
        end

        def tenanted?
          false
        end

        def table_exists?
          super
        rescue ActiveRecord::Tenanted::NoTenantError
          # If this exception was raised, then Rails is trying to determine if a non-tenanted
          # table exists by accessing the tenanted primary database config, probably during eager
          # loading.
          #
          # This happens for Record classes that late-bind to their database, like
          # SolidCable::Record, SolidQueue::Record, and SolidCache::Record (all of which inherit
          # directly from ActiveRecord::Base but call `connects_to` to set their database later,
          # during initialization).
          #
          # In non-tenanted apps, this method just returns false during eager loading. So let's
          # follow suit. Rails will figure it out later.
          false
        end
      end
    end
  end
end
