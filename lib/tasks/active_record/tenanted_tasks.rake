# frozen_string_literal: true

namespace :db do
  desc "Migrate the database for tenant AR_TENANT"
  task "migrate:tenant" => "load_config" do
    tenant = ENV["AR_TENANT"]
    unless tenant.present?
      raise ArgumentError, "AR_TENANT must be set in a non-local environment" unless Rails.env.local?

      tenant = "#{Rails.env}-tenant"
      warn "WARNING: AR_TENANT is not set, defaulting to #{tenant.inspect}"
    end

    verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = ActiveRecord::Tenanted::DatabaseTasks.verbose?

    ActiveRecord::Tenanted::DatabaseTasks.migrate_tenant(tenant)
  ensure
    ActiveRecord::Migration.verbose = verbose_was
  end

  desc "Migrate the database for all existing tenants"
  task "migrate:tenant:all" => "load_config" do
    verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = ActiveRecord::Tenanted::DatabaseTasks.verbose?

    ActiveRecord::Tenanted::DatabaseTasks.migrate_all
  ensure
    ActiveRecord::Migration.verbose = verbose_was
  end
end

if Rails.env.local?
  task "db:migrate" => "db:migrate:tenant"
  task "db:prepare" => "db:migrate:tenant"
end
