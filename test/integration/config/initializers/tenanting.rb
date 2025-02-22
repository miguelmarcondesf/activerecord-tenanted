Rails.application.configure do
  config.middleware.use ActiveRecord::Tenanted::TenantSelector, "ApplicationRecord", ->(request) { request.subdomain }

  config.hosts << /.*\..*\.localhost/ if Rails.env.development?
end
