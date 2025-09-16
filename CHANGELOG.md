# `activerecord-tenanted` Changelog

## next / unreleased

- Rename `ActiveRecord::Tenanted::DatabaseConfigurations::RootConfig` to `BaseConfig`.
- Call `ActiveRecord::DatabaseConfigurations.register_db_config_handler` from the railtie.


## 0.3.0 / 2025-09-09

### Improved

- `#inspect` on instances of tenanted models includes the tenant. #155 @miguelmarcondesf @flavorjones
- `TenantSelector` middleware no longer directly renders a 404. Instead, it configures ActionDispatch::ShowExceptions middlware and raises an appropriate exception. #167 @flavorjones


## 0.2.0 / 2025-09-04

First release.


## 0.1.0

Empty gem file to claim the name.
