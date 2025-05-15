# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  before_action :authenticate_user!

  # Authentication methods
  def authenticate_user!
    unless current_user
      render json: { error: 'Unauthorized - Please log in to continue' }, status: :unauthorized
      return false
    end
    true
  end

  def current_user
    @current_user ||= begin
      token = extract_token_from_request
      user_id = decode_token(token)['user_id'] if token.present?
      User.find_by(id: user_id) if user_id
    end
  end

  def user_signed_in?
    current_user.present?
  end

  private

  def extract_token_from_request
    header = request.headers['Authorization']
    header.present? ? header.split(' ').last : nil
  end

  def decode_token(token)
    begin
      JWT.decode(token, jwt_secret, true, { algorithm: 'HS256' })[0]
    rescue JWT::DecodeError
      {}
    end
  end

  def jwt_secret
    Rails.application.credentials.secret_key_base
  end
end