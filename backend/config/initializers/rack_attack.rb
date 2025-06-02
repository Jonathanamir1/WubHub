# Only enable rate limiting in production and development, not in tests
unless Rails.env.test?
  class Rack::Attack
    # Enable logging
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    
    # Login protection (GitHub-style)
    throttle('logins/ip', limit: 10, period: 60.seconds) do |req|
      if req.path == '/api/v1/auth/login' && req.post?
        req.ip
      end
    end
    
    # Registration protection (prevent spam accounts)
    throttle('registrations/ip', limit: 5, period: 300.seconds) do |req|
      if req.path == '/api/v1/auth/register' && req.post?
        req.ip
      end
    end
    
    # File upload protection (critical for music files!)
    throttle('uploads/ip', limit: 20, period: 3600.seconds) do |req|
      if req.path.include?('track_contents') && req.post?
        req.ip
      end
    end
    
    # General API protection (GitHub-style)
    throttle('api/ip', limit: 300, period: 300.seconds) do |req|
      if req.path.start_with?('/api/') && !req.path.include?('auth')
        req.ip
      end
    end
    
    # Custom response for throttled requests
    self.throttled_response = lambda do |env|
      [
        429, # Too Many Requests
        { 'Content-Type' => 'application/json' },
        [{ error: 'Too many requests. Please try again later.' }.to_json]
      ]
    end
  end
end