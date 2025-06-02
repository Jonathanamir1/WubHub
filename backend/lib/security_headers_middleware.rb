class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    add_security_headers(headers)
    [status, headers, response]
  rescue StandardError => e
    # Handle the error case - create a minimal response with security headers
    headers = {
      'Content-Type' => 'application/json'
    }
    add_security_headers(headers)
    
    # Let Rails handle the actual error response, but ensure headers are set
    # We'll return a 500 with our security headers
    response_body = ['{"error":"Internal Server Error"}']
    [500, headers, response_body]
  end

  private

  def add_security_headers(headers)
    # Set strict security headers for API
    headers['X-Frame-Options'] = 'DENY'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'"
    
    # Remove server information
    headers.delete('Server')
    headers.delete('X-Powered-By')
    
    # Add HSTS in production
    if Rails.env.production?
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end
  end
end