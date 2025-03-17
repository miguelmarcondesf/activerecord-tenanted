Rails.application.configure do
  config.hosts << /.*\..*\.localhost/ if Rails.env.development?
end
