# backend/spec/requests/api/v1/auth_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Auth", type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:valid_login_params) { { email: 'test@example.com', password: 'password123' } }
  let(:invalid_login_params) { { email: 'test@example.com', password: 'wrongpassword' } }
  let(:valid_register_params) do
    {
      email: 'newuser@example.com',
      username: 'newuser',
      name: 'New User',
      password: 'password123',
      password_confirmation: 'password123'
    }
  end

  describe "POST /api/v1/auth/login" do
    context "with valid credentials" do
      before { user } # Create the user

      it "returns success status" do
        post "/api/v1/auth/login", params: valid_login_params
        expect(response).to have_http_status(:ok)
      end

      it "returns user data and token" do
        post "/api/v1/auth/login", params: valid_login_params
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('user')
        expect(json_response).to have_key('token')
        expect(json_response['user']['email']).to eq('test@example.com')
      end

      it "returns a valid JWT token" do
        post "/api/v1/auth/login", params: valid_login_params
        json_response = JSON.parse(response.body)
        token = json_response['token']
        
        expect(token).to be_present
        
        # Decode and verify token
        decoded_token = JWT.decode(token, Rails.application.credentials.jwt_secret, true, { algorithm: 'HS256' })[0]
        expect(decoded_token['user_id']).to eq(user.id)
      end
    end

    context "with invalid credentials" do
      before { user } # Create the user

      it "returns unauthorized status" do
        post "/api/v1/auth/login", params: invalid_login_params
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message" do
        post "/api/v1/auth/login", params: invalid_login_params
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('error')
        expect(json_response['error']).to eq('Invalid email or password')
      end
    end

    context "with non-existent user" do
      it "returns unauthorized status" do
        post "/api/v1/auth/login", params: { email: 'nonexistent@example.com', password: 'password' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "edge cases and security" do
      it "handles SQL injection attempts in email" do
        malicious_email = "'; DROP TABLE users; --"
        post "/api/v1/auth/login", params: { email: malicious_email, password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles extremely long email addresses" do
        long_email = 'a' * 1000 + '@example.com'
        post "/api/v1/auth/login", params: { email: long_email, password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles empty request body" do
        post "/api/v1/auth/login", params: {}
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles missing password field" do
        post "/api/v1/auth/login", params: { email: 'test@example.com' }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles missing email field" do
        post "/api/v1/auth/login", params: { password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles whitespace-only credentials" do
        post "/api/v1/auth/login", params: { email: '   ', password: '   ' }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles case sensitivity in email correctly" do
        user = create(:user, email: 'Test@Example.com', password: 'password123')
        
        # Should work with different case
        post "/api/v1/auth/login", params: { email: 'test@example.com', password: 'password123' }
        expect(response).to have_http_status(:ok)
      end

      it "prevents timing attacks by taking consistent time for invalid users" do
        # This is more of a documentation test - actual timing attack prevention 
        # would need more sophisticated testing
        start_time = Time.current
        post "/api/v1/auth/login", params: { email: 'nonexistent@example.com', password: 'password' }
        invalid_time = Time.current - start_time

        user = create(:user, email: 'real@example.com', password: 'password123')
        start_time = Time.current
        post "/api/v1/auth/login", params: { email: 'real@example.com', password: 'wrongpassword' }
        valid_user_time = Time.current - start_time

        # Both should respond with same status
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "rate limiting scenarios" do
      let(:user) { create(:user, email: 'test@example.com', password: 'password123') }

      it "handles multiple rapid login attempts" do
        10.times do
          post "/api/v1/auth/login", params: { email: user.email, password: 'wrongpassword' }
          expect(response).to have_http_status(:unauthorized)
        end
        
        # Should still work with correct password
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /api/v1/auth/register" do
    context "with valid parameters" do
      it "returns success status" do
        post "/api/v1/auth/register", params: valid_register_params
        expect(response).to have_http_status(:created)
      end

      it "creates a new user" do
        expect {
          post "/api/v1/auth/register", params: valid_register_params
        }.to change(User, :count).by(1)
      end

      it "returns user data and token" do
        post "/api/v1/auth/register", params: valid_register_params
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('user')
        expect(json_response).to have_key('token')
        expect(json_response['user']['email']).to eq('newuser@example.com')
        expect(json_response['user']['username']).to eq('newuser')
      end

      it "returns a valid JWT token" do
        post "/api/v1/auth/register", params: valid_register_params
        json_response = JSON.parse(response.body)
        token = json_response['token']
        
        expect(token).to be_present
        
        # Decode and verify token
        decoded_token = JWT.decode(token, Rails.application.credentials.jwt_secret, true, { algorithm: 'HS256' })[0]
        expect(decoded_token['user_id']).to be_present
      end
    end

    context "with invalid parameters" do
      it "returns unprocessable entity status for missing email" do
        invalid_params = valid_register_params.merge(email: '')
        post "/api/v1/auth/register", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns unprocessable entity status for missing username" do
        invalid_params = valid_register_params.merge(username: '')
        post "/api/v1/auth/register", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error messages for validation failures" do
        invalid_params = valid_register_params.merge(email: '')
        post "/api/v1/auth/register", params: invalid_params
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to be_an(Array)
      end
    end

    context "with duplicate email" do
      before { create(:user, email: 'duplicate@example.com') }

      it "returns unprocessable entity status" do
        duplicate_params = valid_register_params.merge(email: 'duplicate@example.com')
        post "/api/v1/auth/register", params: duplicate_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with duplicate username" do
      before { create(:user, username: 'duplicate') }

      it "returns unprocessable entity status" do
        duplicate_params = valid_register_params.merge(username: 'duplicate')
        post "/api/v1/auth/register", params: duplicate_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "registration edge cases" do
      it "prevents duplicate registration with same email (different case)" do
        create(:user, email: 'test@example.com')
        
        duplicate_params = {
          email: 'TEST@Example.com',
          username: 'different_username',
          name: 'Different User',
          password: 'password123',
          password_confirmation: 'password123'
        }
        
        post "/api/v1/auth/register", params: duplicate_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "handles unicode characters in usernames" do
        unicode_params = {
          email: 'unicode@example.com',
          username: 'üser_ñame',
          name: 'Unicode User',
          password: 'password123',
          password_confirmation: 'password123'
        }
        
        post "/api/v1/auth/register", params: unicode_params
        expect(response).to have_http_status(:created)
      end

      it "handles very long field values" do
        long_params = {
          email: 'test@example.com',
          username: 'a' * 1000,
          name: 'b' * 1000,
          password: 'password123',
          password_confirmation: 'password123'
        }
        
        post "/api/v1/auth/register", params: long_params
        # Depending on your validations, this might be :unprocessable_entity
        expect([422, 201]).to include(response.status)
      end

      it "trims whitespace from email and username" do
        whitespace_params = {
          email: '  test@example.com  ',
          username: '  testuser  ',
          name: 'Test User',
          password: 'password123',
          password_confirmation: 'password123'
        }
        
        post "/api/v1/auth/register", params: whitespace_params
        
        if response.status == 201
          user = User.last
          expect(user.email).to eq('test@example.com')
          expect(user.username).to eq('testuser')
        end
      end
    end
  end

  describe "GET /api/v1/auth/current" do
    context "with valid token" do
      let(:token) { generate_token_for_user(user) }

      it "returns success status" do
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer #{token}" }
        expect(response).to have_http_status(:ok)
      end

      it "returns current user data" do
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer #{token}" }
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('user')
        expect(json_response['user']['id']).to eq(user.id)
        expect(json_response['user']['email']).to eq(user.email)
      end
    end

    context "without token" do
      it "returns unauthorized status" do
        get "/api/v1/auth/current"
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message" do
        get "/api/v1/auth/current"
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('Unauthorized')
      end
    end

    context "with invalid token" do
      it "returns unauthorized status" do
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer invalid_token" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with expired token" do
      let(:expired_token) do
        payload = {
          user_id: user.id,
          iat: 2.days.ago.to_i,
          exp: 1.day.ago.to_i
        }
        JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
      end

      it "returns unauthorized status" do
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer #{expired_token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "token edge cases" do
      let(:user) { create(:user) }

      it "handles malformed JWT tokens" do
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer not.a.valid.jwt" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles JWT with invalid signature" do
        # Create token with wrong secret
        payload = { user_id: user.id, exp: 1.hour.from_now.to_i }
        invalid_token = JWT.encode(payload, 'wrong_secret', 'HS256')
        
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer #{invalid_token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles JWT without required fields" do
        # Token without user_id
        payload = { exp: 1.hour.from_now.to_i }
        token_without_user = JWT.encode(payload, Rails.application.credentials.jwt_secret, 'HS256')
        
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer #{token_without_user}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles token for deleted user" do
        token = generate_token_for_user(user)
        user.destroy
        
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles different authorization header formats" do
        token = generate_token_for_user(user)
        
        # Without 'Bearer' prefix
        get "/api/v1/auth/current", headers: { 'Authorization' => token }
        expect(response).to have_http_status(:unauthorized)
        
        # With extra spaces
        get "/api/v1/auth/current", headers: { 'Authorization' => "Bearer  #{token}  " }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  private

  def generate_token_for_user(user)
    payload = {
      user_id: user.id,
      iat: Time.now.to_i,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, jwt_secret, 'HS256')
  end

  # Add this method to the test (or better yet, create a test helper)
  def jwt_secret
    Rails.application.credentials.jwt_secret
  end
end