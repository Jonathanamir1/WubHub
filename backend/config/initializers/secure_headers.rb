SecureHeaders::Configuration.default do |config|
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.referrer_policy = "strict-origin-when-cross-origin"
  
  config.csp = {
    default_src: %w('none'),
    script_src: %w('none'),
    frame_ancestors: %w('none')
  }
  
  # HSTS only in production (handled by infrastructure)
  config.hsts = Rails.env.production? ? "max-age=31536000; includeSubDomains" : SecureHeaders::OPT_OUT
  
  config.x_download_options = SecureHeaders::OPT_OUT
  config.x_permitted_cross_domain_policies = SecureHeaders::OPT_OUT
end