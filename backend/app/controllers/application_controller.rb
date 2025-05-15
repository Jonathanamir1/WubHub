class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  
  # Important: Define and skip this for login/register
  before_action :authenticate_user!

  protected

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
      return nil unless token.present?
      
      decoded_token = decode_token(token)
      return nil unless decoded_token.present? && decoded_token['user_id'].present?
      
      User.find_by(id: decoded_token['user_id'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound => e
      Rails.logger.error("Authentication error: #{e.message}")
      nil
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
    rescue JWT::DecodeError => e
      Rails.logger.error("Token decode error: #{e.message}")
      {}
    end
  end

  def jwt_secret
    Rails.application.credentials.secret_key_base
  end
end