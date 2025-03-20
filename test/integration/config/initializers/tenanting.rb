Rails.application.configure do
  config.hosts << /.*\..*\.localhost/ if Rails.env.development?

  config.action_mailer.default_url_options = { host: "%{tenant}.example.com" }
end
