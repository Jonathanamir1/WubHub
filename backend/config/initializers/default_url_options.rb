Rails.application.routes.default_url_options = {
  host: ENV.fetch('DEFAULT_URL_HOST', 'localhost'),
  port: ENV.fetch('DEFAULT_URL_PORT', 3000),
  protocol: ENV.fetch('DEFAULT_URL_PROTOCOL', 'http')
}
