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

  private

  def jwt_secret
    Rails.application.credentials.jwt_secret
  end
end

# Include in RSpec configuration
RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
end