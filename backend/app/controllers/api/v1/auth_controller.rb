module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:login, :register, :google]

      def login
        user = User.find_by(email: params[:email])

        if user && user.authenticate(params[:password])
          token = generate_token(user)
          render json: {
            user: UserSerializer.new(user, scope: { current_user: user }).as_json,
            token: token
          }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      def register
        user = User.new(user_params)

        if user.save
          token = generate_token(user)
          render json: {
            user: UserSerializer.new(user, scope: { current_user: user }).as_json,
            token: token
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique => e
        # Handle database constraint violations gracefully
        if e.message.include?('email')
          render json: { errors: ['Email has already been taken'] }, status: :unprocessable_entity
        else
          render json: { errors: ['A record with these details already exists'] }, status: :unprocessable_entity
        end
      end

      def google
        # Validate that ID token is provided
        id_token = params[:id_token]
        
        if id_token.blank?
          render json: { error: 'Google ID token is required' }, status: :bad_request
          return
        end

        # Verify the Google ID token
        google_user_info = verify_google_token(id_token)
        
        if google_user_info.nil?
          render json: { error: 'Invalid Google token' }, status: :unauthorized
          return
        end

        # Extract user information from Google
        google_id = google_user_info['sub']
        email = google_user_info['email']
        name = google_user_info['name']
        
        # Find or create user
        user = find_or_create_google_user(google_id, email, name)
        
        if user.persisted?
          # Generate JWT token
          token = generate_token(user)
          
          # Return user and token
          render json: {
            user: UserSerializer.new(user, scope: { current_user: user }).as_json,
            token: token
          }, status: user.previously_new_record? ? :created : :ok
        else
          render json: { 
            errors: user.errors.full_messages 
          }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Google authentication error: #{e.message}"
        render json: { error: 'Authentication failed' }, status: :internal_server_error
      end

      def current
        render json: {
          user: UserSerializer.new(current_user, scope: { current_user: current_user }).as_json
        }, status: :ok
      end

      private

      def user_params
        params.permit(:email, :name, :password, :password_confirmation)
      end

      def generate_token(user)
        payload = {
          user_id: user.id,
          iat: Time.now.to_i,
          exp: 24.hours.from_now.to_i
        }

        JWT.encode(payload, jwt_secret, 'HS256')
      end

      def verify_google_token(token)
        require 'net/http'  # Add this require statement
        require 'json'
        require 'base64'
        
        Rails.logger.info "🔍 Google token verification started"
        Rails.logger.info "🔍 Token received: #{token[0..50]}..." # First 50 chars only
        Rails.logger.info "🔍 GOOGLE_CLIENT_ID: #{ENV['GOOGLE_CLIENT_ID']}"
        
        begin
          # Decode our custom token format
          Rails.logger.info "🔍 Attempting to decode Base64 token..."
          decoded_data = JSON.parse(Base64.decode64(token))
          Rails.logger.info "🔍 Decoded data keys: #{decoded_data.keys}"
          
          # Verify with Google using the access token
          access_token = decoded_data['access_token']
          
          if access_token.blank?
            Rails.logger.error "❌ No access token in Google response"
            return nil
          end
          
          Rails.logger.info "🔍 Access token found: #{access_token[0..20]}..."
          
          # Verify the access token with Google
          uri = URI("https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=#{access_token}")
          Rails.logger.info "🔍 Making request to Google: #{uri}"
          
          response = Net::HTTP.get_response(uri)
          Rails.logger.info "🔍 Google response code: #{response.code}"
          Rails.logger.info "🔍 Google response body: #{response.body}"
          
          if response.code == '200'
            token_info = JSON.parse(response.body)
            Rails.logger.info "🔍 Token info keys: #{token_info.keys}"
            Rails.logger.info "🔍 Token audience: #{token_info['audience']}"
            
            # Check if audience matches (it might be different for OAuth2 tokens)
            if token_info['audience'] == ENV['GOOGLE_CLIENT_ID'] || token_info['issued_to'] == ENV['GOOGLE_CLIENT_ID']
              Rails.logger.info "✅ Google token verification successful"
              # Return user info in expected format
              result = {
                'sub' => decoded_data['sub'],
                'email' => decoded_data['email'],
                'name' => decoded_data['name'],
                'picture' => decoded_data['picture'],
                'email_verified' => decoded_data['email_verified']
              }
              Rails.logger.info "✅ Returning user data: #{result.except('picture')}"
              return result
            else
              Rails.logger.error "❌ Google token verification failed: Invalid audience. Expected: #{ENV['GOOGLE_CLIENT_ID']}, Got: #{token_info['audience']} or #{token_info['issued_to']}"
              return nil
            end
          else
            Rails.logger.error "❌ Google token verification failed: #{response.code} - #{response.body}"
            return nil
          end
        rescue JSON::ParserError => e
          Rails.logger.error "❌ JSON parsing error: #{e.message}"
          return nil
        rescue => e
          Rails.logger.error "❌ Google token verification error: #{e.message}"
          Rails.logger.error "❌ Backtrace: #{e.backtrace[0..5]}"
          return nil
        end
      end

      def find_or_create_google_user(google_id, email, name)
        # Try to find existing user by Google ID
        user = User.find_by(google_id: google_id)
        
        if user
          # User exists with this Google ID, just return them
          return user
        end
        
        # Try to find existing user by email (to link accounts)
        user = User.find_by(email: email)
        
        if user
          # User exists with this email but no Google ID, link the accounts
          user.update!(
            google_id: google_id,
            name: name # Update name from Google profile
          )
          return user
        end
        
        # Create new user from Google profile
        User.create!(
          google_id: google_id,
          email: email,
          name: name,
          password: SecureRandom.hex(20) # Random password for Google users
        )
      end
    end
  end
end