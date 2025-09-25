# `activerecord-tenanted` Changelog

## next / unreleased

### Changed

- The return value from an Active Record model `#cache_key` has changed from `users/1?tenant=foo` to `foo/users/1`. For existing applications, this will invalidate any relevant cache entries. #187 @miguelmarcondesf


### Improved

- For tenanted model instances, `#inspect` now outputs the tenant attribute first, before the column attributes. #191 @lairtonmendes


## v0.4.1 / 2025-09-17

No functional changes from v0.4.0.


## v0.4.0 / 2025-09-17

### Added

- Introduce `max_connection_pools` database configuration to limit the number of tenanted databases with open connections. Pools are reaped in least-recently-used order. #182 @flavorjones
- Documentation: Improved `GUIDE.md`. @flavorjones


### Changed

- Rename `ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig` to `BaseConfig`. @flavorjones
- Rails dependency bumped to `>= 8.1.beta` #172 @andrewmarkle


## v0.3.0 / 2025-09-09

### Improved

- `#inspect` on instances of tenanted models includes the tenant. #155 @miguelmarcondesf @flavorjones
- `TenantSelector` middleware no longer directly renders a 404. Instead, it configures ActionDispatch::ShowExceptions middlware and raises an appropriate exception. #167 @flavorjones


## v0.2.0 / 2025-09-04

First release.


## v0.1.0

Empty gem file to claim the name.
