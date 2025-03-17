# Active Record Tenanting

This file will eventually become a complete "Rails Guide"-style document explaining Active Record tenanting with this gem.

In the meantime, it is a work-in-progress containing:

- skeleton outline for documentation
- functional roadmap represented as to-do checklists


## Introduction

> [!TIP]
> If you're not familiar with how Rails's built-in horizontal sharding works, it may be worth reading the Rails Guide on [Multiple Databases with Active Record](https://guides.rubyonrails.org/active_record_multiple_databases.html#setting-up-your-application) before proceeding.

Documentation outline:

- this gem primarily extends Active Record,
  - essentially creating a new Connection Pool for each tenant,
  - and extending horizontal shard swapping to support these pools.
  - also provides test helpers to make it easy to handle tenanting in your test suite
- but also touches many other parts of Rails
  - integrations for Middleware, Action View Caching, Active Job, Action Cable, Active Storage, Action Mailbox, and Action Text
  - support and documentation for Solid Cache, Solid Queue, Solid Cable, and Turbo Rails
- a Tenant is just a string that is used for:
  - the sqlite database filename (or perhaps the pg/mysql database name in the future)
  - the subdomain (or path element)
  - fragment cache disambiguation
  - global id disambiguation
  - invalid characters in a tenant name
    - and how the application may want to do additional validation (e.g. ICANN subdomain restrictions)
  - `#tenant` is a readonly attribute on all tenanted model instances
  - `.current_tenant` returns the execution context for the model connection class
- talk a bit about busted assumptions about shared state
  - database ids are no longer unique
  - global ids are no longer global
  - cache is no longer global
  - cable channels are no longer global
  - jobs are no longer global
- and what we do in this gem to help manage that "current tenant" state
- reference existing approaches/projects, maybe talk about differences
  - discussion at https://www.reddit.com/r/rails/comments/1ik7caq/multitenancy_vs_multi_instances/
  - [Kolide's 30 Line Rails Multi-Tenant Strategy](https://www.kolide.com/blog/kolide-s-30-line-rails-multi-tenant-strategy)
  - [citusdata/activerecord-multi-tenant: Rails/ActiveRecord support for distributed multi-tenant databases like Postgres+Citus](https://github.com/citusdata/activerecord-multi-tenant)
  - [rails-on-services/apartment: Database multi-tenancy for Rack (and Rails) applications](https://github.com/rails-on-services/apartment)
  - [ErwinM/acts_as_tenant: Easy multi-tenancy for Rails in a shared database setup.](https://github.com/ErwinM/acts_as_tenant)
- logging
  - SQL query logs
  - TaggedLogging and config.log_tenant_tag
  - suggest how to add to structured logs if people are doing that

## Active Record

### Configuration

Documentation outline:

- how to configure database.yml
  - for tenanting a primary database
  - for tenanting a non-primary database

- how to configure model classes and records
  - variations for primary or non-primary records
  - how to make a class that inherits from ActiveRecord::Base "subtenant" from a tenanted database
    - and note how we do it out of the box for Rails records

- Rails configuration
  - explain why we set some options
    - `active_record.use_schema_cache_dump = true`
    - `active_record.check_schema_cache_dump_version = false`
  - explain gem railtie config options
    - `connection_class`
    - `tenanted_rails_records`
  - demonstrate how to configure an app for subdomain tenants
    - app.config.hosts
    - example TenantSelector proc

- operations
  - how to run database tasks
    - db:migrate:tenant AR_TENANT, default value of AR_TENANT
    - db:migrate:tenant:all
  - and what assumptions have changed
    - tenants will be migrated by `db:migrate` in dev/test but not production
    - tenants will be migrated by `db:prepare` in dev/test but not production
    - other database tasks do not work yet (db:create, db:seed, db:drop)

TODO:

- implement `AR::Tenanted::DatabaseConfigurations::RootConfig`
  - [x] create the specialized RootConfig for `tenanted: true` databases
  - [x] RootConfig disables database tasks initially
  - [x] RootConfig raises if a connection is attempted
  - [x] `#database_path_for(tenant_name)`
  - [x] `#tenants` returns all the tenants on disk (for iteration)
  - [x] raise an exception if tenant name contains a path separator
  - [ ] bucketed database paths

- implement `AR::Tenanted::DatabaseConfigurations::TenantConfig`
  - [x] make sure the logs include the tenant name (via `#new_connection`)

- Active Record class methods
  - [x] `.tenanted`
    - [x] mixin `Tenant`
    - [x] should error if self is not an abstract base class
    - [x] `Tenant.with_tenant` and `.current_tenant`
    - [x] `Tenant#tenant`
    - [x] use a sentinel value to avoid needing a protoshard
    - [x] `tenant_config_name` and `.tenanted?`
  - [x] `.tenanted_with`
    - [x] mixin `Subtenant`
    - [x] should error if self is not an abstract base class or if target is not tenanted abstract base class
    - [x] `.tenanted?`
  - [x] shared connection pools
  - [x] all the creation and schema migration complications (we have existing tests for this)
    - [x] read and write to the schema dump file
    - [x] write to the schema cache dump file
    - [x] make sure we read from the schema cache dump file when untenanted
    - [x] test production eager loading of the schema cache from dump files
  - [ ] feature to turn off automatic creation/migration
    - [ ] pay attention to Rails.config.active_record.migration_error when we turn off auto-migrating
    - [ ] file creation shouldn't be implicit in the sqlite3 adapter, it should be explicit like in the other adapters
      - see working branch `flavorjones/rails/flavorjones-sqlite3-adapter-explicit-create` for a start here
  - [ ] UntenantedConnectionPool should peek at its stack and if it happened during schema cache load, output a friendly message to let people know what to do
  - [ ] be explicit about what happens when a non-abstract class sets current_tenant, e.g. `User.current_tenant=`
    - right now it seems like it silently fails
  - [x] make it OK to call `while_tenanted("foo") { while_tenanted("foo") { ... } }`
  - [x] rename `while_tenanted` to `with_tenant`
  - [x] introduce `.with_each_tenant` which is sugar for `ApplicationRecord.tenants.each { ApplicationRecord.while_tenanted(_1) { } }`

- tenant selector
  - [x] rebuild `AR::Tenanted::TenantSelector` to take a proc
    - [x] make sure it sets the tenant and prohibits shard swapping
    - [x] or explicitly untenanted, we allow shard swapping
    - [x] or else 404s if an unrecognized tenant

- old `Tenant` singleton methods that need to be migrated to the AR model
  - [x] `.current_tenant`
  - [x] `.current_tenant=`
  - [x] `.tenant_exist?`
  - [x] `.while_tenanted`
  - [x] `.create_tenant`
  - [x] `.destroy_tenant`

- autoloading and configuration hooks
  - [x] create a zeitwerk loader
  - [x] install a load hook

- database tasks
  - [x] make `db:migrate:tenant:all` iterate over all the tenants on disk
  - [x] make `db:migrate:tenant AR_TENANT=asdf` run migrations on just that tenant
  - [x] make `db:migrate:tenant` run migrations on `development-tenant` in dev
  - [x] make `db:migrate` run `db:migrate:tenant` in dev
  - [x] make `db:prepare` run `db:migrate:tenant` in dev
  - [ ] implement other database tasks like `db:create`, `db:seed`, `db:fixtures:load`, etc.

- installation
  - [ ] install a variation on the default database.yml with primary tenanted and non-primary "global" untenanted
  - initializer
    - [ ] install `TenantSelector` and configure it with a proc
    - [ ] commented line like `self.connection_class = "ApplicationRecord"`
    - [ ] commented line like `self.tenanted_rails_records = true`

- [ ] think about race conditions
  - maybe use a file lock to figure it out?
  - [ ] create
    - if two threads are racing
  - [ ] migrations
    - done in a transaction, but the second thread's migration may fail resulting in a 500?
  - [ ] schema load
    - if first thread loads the schema and inserts data, can the second thread accidentally drop/load causing data loss?
  - [ ] destroy
    - should delete the wal and shm files, too
    - we need to be close existing connections / statements / transactions(?)
      - relevant adapter code https://github.com/rails/rails/blob/91d456366638ac6c3f6dec38670c8ada5e7c69b1/activerecord/lib/active_record/tasks/sqlite_database_tasks.rb#L23-L26
      - relevant issue/pull-request https://github.com/rails/rails/pull/53893

- pruning connections and connection pools
  - [ ] look into whether the proposed Reaper changes will allow us to set appropriate connection min/max/timeouts
    - and if not, figure out how to prune unused/timed-out connections
  - [ ] we should also look into how to cap the number of connection pools, and prune them

- integration test coverage
  - [x] connection_class
    - [x] fixture tenant
    - [x] fixture tenant in parallel suite
    - [x] clean up non-default tenants
    - [x] integration test session host
    - [x] integration test session verbs
  - [x] fixtures are loaded
  - [x] tenanted_rails_records


### Tenanting in your application

Documentation outline:

- introduce the `ActiveRecord::Tenanted::Tenant` module
  - demonstrate how to create a tenant, destroy a tenant, etc.
  - explain `.while_tenanted` and `current_tenant`
- troubleshooting: what errors you might see in your app and how to deal with it
  - specifically when running untenanted


### Testing

Documentation outline:

- explain the concept of a default tenant
  - and that database connection is wrapped in a transaction
- explain creating a new tenant
  - and how that database is NOT wrapped in a transaction during the test,
  - but those non-fixture databases will be cleaned up at the start of the test suite
- explain `while_untenanted`
- example of:
  - unit test with fixtures
  - integration test
  - sytem test

TODO:

- testing
  - [x] a `while_untenanted` test helper
  - [x] set up test helper to default to a tenanted named "test-tenant"
  - [x] set up test helpers to deal with parallelized tests, too (e.g. "test-tenant-19")
  - [x] set up integration tests to do the right things ...
    - [x] set the domain name in integration tests
    - [x] wrap the HTTP verbs with `while_untenanted`
    - [x] set the domain name in system tests
  - [x] allow the creation of tenants within transactional tests


## Caching

Documentation outline:

- explain why we need to be careful
- explain how active record objects' cache keys have tenanting built in
- explain why we're not worried about collection caching and partial caching (?)
- explain why we're not worried about russian doll caching
- explain why calling Rails.cache directly requires care that it's either explicitly tenanted or global
- explain why we're not worried about sql query caching (it belongs to the connection pool)


TODO:

- [x] make basic fragment caching work
- [x] investigate: is collection caching going to be tenanted properly
- [x] investigate: make sure the QueryCache executor is clearing query caches for tenanted pool
- [x] do we need to do some exploration on how to make sure all caching is tenanted?
  - I'm making the call not to pursue this. Rails.cache is a primitive. Just document it.

## Action View Fragment Caching

Documentation outline:

- explain how it works (cache keys)

TODO:

- [x] extend `#cache_key` on Base
- [x] extend `#cache_key` on Subtenant


### Solid Cache

Documentation outline:

- describe one-big-cache and cache-in-the-tenanted-database strategies
  - note that cache-in-the-tenanted-database means there is no global cache
  - note that cache-in-the-tenanted-database is not easily purgeable (today)
  - and so we recommend (?) one big cache in a dedicated database
- how to configure Solid Cache for one-big-cache
- how to configure Solid Cache for tenanted-cache

TODO:

- upstream
  - [ ] feature: make shard swap prohibition database-specific
    - which would work around Solid Cache config wonkiness caused by https://github.com/rails/solid_cache/pull/219


## Action Cable

Documentation outline:

- explain why we need to be careful
- how to tenant a channel
 - `tenanted_connection`
- how the global id contains tenant also
- do we need to document each adapter?
  - async
  - test
  - solid_cable
  - redis?

TODO:

- [x] extend the base connection to support tenanting with a `tenanted_connection` method
- [ ] test disconnection
  - `ActionCable.server.remote_connections.where(current_tenant: "foo", current_user: User.find(1)).disconnect`
  - can we make this easier to use by implying the current tenant?
- [ ] add tenant to the action_cable logger tags
- [ ] add integration testing around executing a command (similar to Job testing)


### Turbo Rails

Documentation outline:

- explain why we need to be careful
- explain how it works (global IDs)

TODO:

- [x] extend `to_global_id` and friends for Base
- [x] extend `to_global_id` and friends for Subtenant
- [x] some testing around global id would be good here
- [x] system test of a broadcast update


## Active Job

Documentation outline:

- explain why we need to be careful
- explain belt-and-suspenders of
  - ActiveJob including the current tenant,
  - and any passed record being including the tenant in global_id


TODO:

- [x] extend `ActiveJob` to set the tenant in `perform_now`
- [x] extend `to_global_id` and friends for Base
- [x] extend `to_global_id` and friends for Subtenant
- [x] create a tenanted GlobalID locator
- [x] inject the tenanted GlobalID locator as the default app locator
- [x] make sure the test helper `perform_enqueued_jobs` wraps everything in a `while_untenanted` block


## Active Storage

Documentation outline:

- explain why we need to be careful
- how to configure Disk Service so that each client is in a tenanted subdirectory
  - similar to database config,
    - `tenanted: true` config param
    - disk path parameterized with `%{tenant}`
- how to configure S3 so that each client is in a tenanted bucket

TODO:

- [x] extend Disk Service
- [ ] extend S3 Service
  - waiting until we have a concrete need and some opinions


## ActionMailbox

TODO:

- [ ] I need a use case here around mail routing before I tackle it


## Known issues

### LOW

- [ ] When running code outside of a `while_tenanted` block (e.g., the console), it's probably
      possible to read associations from an object belonging to tenant A while in tenant B context
      and getting back records from the wrong tenant. This is low priority because normally
      application code will be sandboxed by the framework with a `while_tenanted` block that
      prevents shard switching; but we should fix it to prevent errors in tests and while executing
      code from the console.
- [ ] The `db:purge` rake task, which is run before the test suite, will emit a harmless but
      annoying `NoTenantError` because the task doesn't run with a temporary pool. See some
      information at https://github.com/rails/rails/pull/46270 and my first (wrong) attempt to fix
      it at https://github.com/rails/rails/pull/54536
