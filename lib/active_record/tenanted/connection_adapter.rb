# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    #
    #  Extends ActiveRecord::ConnectionAdapters::AbstractAdapter with a `tenant` attribute.
    #
    #  This is useful in conjunction with the `:tenant` query log tag, which configures logging of
    #  the tenant in SQL query logs (when `config.active_record.query_log_tags_enabled` is set to
    #  `true`). For example:
    #
    #      Rails.application.config.active_record.query_log_tags_enabled = true
    #      Rails.application.config.active_record.query_log_tags = [ :tenant ]
    #
    #  will cause the application to emit logs like:
    #
    #      User Load (0.2ms)  SELECT "users".* FROM "users" ORDER BY "users"."id" ASC LIMIT 1 /*tenant='foo'*/
    #
    module ConnectionAdapter
      extend ActiveSupport::Concern

      prepended do
        attr_accessor :tenant
      end

      def tenanted?
        tenant.present?
      end
    end
  end
end
