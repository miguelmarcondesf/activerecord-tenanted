# frozen_string_literal: true

require "active_record"

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem_extension(ActiveRecord)
loader.setup

module ActiveRecord
  module Tenanted
    # Base exception class for the library.
    class Error < StandardError; end

    # Raised when database access is attempted without a current tenant having been set.
    class NoTenantError < Error; end

    # Raised when database access is attempted on a record whose tenant does not match the current tenant.
    class WrongTenantError < Error; end

    # Raised when attempting to locate a GlobalID without a tenant.
    class MissingTenantError < Error; end

    # Raised when attempting to create a tenant that already exists.
    class TenantExistsError < Error; end

    # Raised when attempting to create a tenant with illegal characters in it.
    class BadTenantNameError < Error; end

    def self.connection_class
      # TODO: cache this / speed this up
      Rails.application.config.active_record_tenanted.connection_class&.constantize
    end
  end
end

loader.eager_load

ActiveSupport.run_load_hooks :active_record_tenanted, ActiveRecord::Tenanted
