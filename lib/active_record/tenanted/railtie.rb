# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    class Railtie < ::Rails::Railtie
      config.active_record_tenanted = ActiveSupport::OrderedOptions.new

      # Set this in an initializer if you're tenanting a connection class other than
      # ApplicationRecord. This value controls how Rails integrates with your tenanted application.
      #
      # By default, Rails will configure the test database, test fixtures to use
      # "ApplicationRecord", but this can be set to `nil` to turn off the integrations entirely,
      # including Rails records (see `tenanted_rails_records` below).
      config.active_record_tenanted.connection_class = "ApplicationRecord"

      # Set this to false in an initializer if you don't want Rails records to share a connection
      # pool with the tenanted connection class.
      #
      # By default, this gem will configure ActionMailbox::Record, ActiveStorage::Record, and
      # ActionText::Record to create/use tables in the database associated with the
      # `connection_class`, and will share a connection pool with that class.
      #
      # This should only be turned off if your primary database configuration is not tenanted, and
      # that is where you want Rails to create the tables for these records.
      config.active_record_tenanted.tenanted_rails_records = true

      config.before_configuration do
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, _, config|
            next unless config.fetch(:tenanted, false)
            ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig.new(env_name, name, config)
          end
        end
      end

      initializer "active_record_tenanted.active_record_base" do
        ActiveSupport.on_load(:active_record) do
          prepend ActiveRecord::Tenanted::Base
        end
      end

      initializer("active_record_tenanted.active_record_schema_cache",
                  before: "active_record.copy_schema_cache_config") do
        # Rails must be able to load the schema for a tenanted model without a database connection
        # (e.g., boot-time eager loading, or calling User.new to build a form). This gem relies on
        # reading from the schema cache dump to do that.
        #
        # Rails defaults use_schema_cache_dump to true, but we explicitly re-set it here because if
        # this is ever turned off, Rails will not work as expected.
        Rails.application.config.active_record.use_schema_cache_dump = true

        # The schema cache version check needs to query the database, which isn't always possible
        # for tenanted models.
        Rails.application.config.active_record.check_schema_cache_dump_version = false
      end

      initializer "active_record-tenanted.monkey_patches" do
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Tasks::DatabaseTasks.prepend ActiveRecord::Tenanted::Patches::DatabaseTasks
        end
      end

      config.after_initialize do
        ActiveSupport.on_load(:action_mailbox_record) do
          if Rails.application.config.active_record_tenanted.connection_class.present? &&
             Rails.application.config.active_record_tenanted.tenanted_rails_records
            subtenant_of Rails.application.config.active_record_tenanted.connection_class
          end
        end

        ActiveSupport.on_load(:active_storage_record) do
          if Rails.application.config.active_record_tenanted.connection_class.present? &&
             Rails.application.config.active_record_tenanted.tenanted_rails_records
            subtenant_of Rails.application.config.active_record_tenanted.connection_class
          end
        end

        ActiveSupport.on_load(:action_text_record) do
          if Rails.application.config.active_record_tenanted.connection_class.present? &&
             Rails.application.config.active_record_tenanted.tenanted_rails_records
            subtenant_of Rails.application.config.active_record_tenanted.connection_class
          end
        end

        ActiveSupport.on_load(:active_support_test_case) do
          include ActiveRecord::Tenanted::Testing::TestCase
        end

        ActiveSupport.on_load(:active_record_fixtures) do
          include ActiveRecord::Tenanted::Testing::TestFixtures
        end

        ActiveSupport.on_load(:action_dispatch_integration_test) do
          include ActiveRecord::Tenanted::Testing::IntegrationTest

          ActionDispatch::Integration::Session.prepend ActiveRecord::Tenanted::Testing::IntegrationSession
        end
      end
    end
  end
end
