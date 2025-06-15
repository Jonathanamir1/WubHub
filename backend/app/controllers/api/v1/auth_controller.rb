module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:login, :register]

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
    end
  end
end