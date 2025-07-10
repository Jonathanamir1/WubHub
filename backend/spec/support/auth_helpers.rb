# spec/support/auth_helpers.rb

module AuthHelpers
  def generate_token_for_user(user)
    payload = {
      user_id: user.id,
      iat: Time.now.to_i,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, jwt_secret, 'HS256')
  end

  def auth_headers_for(user)
    token = generate_token_for_user(user)
    { 'Authorization' => "Bearer #{token}" }
  end

  def login_as(user)
    @auth_headers = auth_headers_for(user)
  end

  def auth_headers
    @auth_headers || {}
  end

  private

  def jwt_secret
    # For tests, use a fixed secret or fallback
    Rails.application.credentials.jwt_secret || 
    ENV['JWT_SECRET'] || 
    'test_jwt_secret_for_development_only'
  end
end

# Include in RSpec configuration
RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
end