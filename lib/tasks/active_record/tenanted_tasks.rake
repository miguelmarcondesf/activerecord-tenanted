# frozen_string_literal: true

namespace :db do
  desc "Migrate the database for tenant ARTENANT"
  task "migrate:tenant" => "load_config" do
    unless ActiveRecord::Tenanted::DatabaseTasks.root_database_config
      warn "WARNING: No tenanted database found, skipping tenanted migration"
    else
      begin
        verbose_was = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = ActiveRecord::Tenanted::DatabaseTasks.verbose?

        ActiveRecord::Tenanted::DatabaseTasks.migrate_tenant
      ensure
        ActiveRecord::Migration.verbose = verbose_was
      end
    end
  end

  desc "Migrate the database for all existing tenants"
  task "migrate:tenant:all" => "load_config" do
    verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = ActiveRecord::Tenanted::DatabaseTasks.verbose?

    ActiveRecord::Tenanted::DatabaseTasks.migrate_all
  ensure
    ActiveRecord::Migration.verbose = verbose_was
  end

  desc "Set the current tenant to ARTENANT if present, else the environment default"
  task "tenant" => "load_config" do
    ActiveRecord::Tenanted::DatabaseTasks.set_current_tenant
  end
end

if Rails.env.local?
  task "db:migrate" => "db:migrate:tenant"
  task "db:prepare" => "db:migrate:tenant"
  task "db:fixtures:load" => "db:tenant"
end
