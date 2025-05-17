Rails.application.routes.default_url_options = {
  host: ENV.fetch('DEFAULT_URL_HOST', 'localhost'),
  port: ENV.fetch('DEFAULT_URL_PORT', 3000),
  protocol: ENV.fetch('DEFAULT_URL_PROTOCOL', 'http')
}

# Alternative approach for Active Storage URL generation
Rails.application.config.after_initialize do
  # Set Active Storage service host
  ActiveStorage::Current.host = "#{Rails.application.routes.default_url_options[:protocol]}://#{Rails.application.routes.default_url_options[:host]}"
  ActiveStorage::Current.host += ":#{Rails.application.routes.default_url_options[:port]}" if Rails.application.routes.default_url_options[:port].present?
end