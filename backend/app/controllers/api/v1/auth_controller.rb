module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:login, :register, :debug]

      # Debug method to check parameters
      def debug
        render json: {
          params: params.to_unsafe_h,
          headers: request.headers.to_h.select { |k, v| k.start_with?('HTTP_') }
        }
      end

      def login
        # Log parameters for debugging
        Rails.logger.info("Login attempt with params: #{params.to_unsafe_h}")
        
        user = User.find_by(email: params[:email])

        if user && user.authenticate(params[:password])
          token = generate_token(user)
          render json: {
            user: UserSerializer.new(user).as_json,
            token: token
          }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      rescue => e
        # Log the error
        Rails.logger.error("Login error: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
      end

      def register
        user = User.new(user_params)

        if user.save
          token = generate_token(user)
          render json: {
            user: UserSerializer.new(user).as_json,
            token: token
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      rescue => e
        # Log the error
        Rails.logger.error("Registration error: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
      end

      def current
        render json: {
          user: UserSerializer.new(current_user).as_json
        }, status: :ok
      end

      private

      def user_params
        params.permit(:email, :username, :name, :password, :password_confirmation)
      end

      def generate_token(user)
        payload = {
          user_id: user.id,
          iat: Time.now.to_i,
          exp: 24.hours.from_now.to_i
        }

        JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
      end
    end
  end
end