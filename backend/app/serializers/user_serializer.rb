# backend/app/serializers/user_serializer.rb
class UserSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  
  attributes :id, :username, :name, :email, :bio, :profile_image_url, :created_at

  def profile_image_url
    if object.profile_image.attached?
      begin
        # Try to generate a URL with host
        rails_blob_url(object.profile_image)
      rescue ArgumentError => e
        # Fall back to a relative path if host is not available
        begin
          Rails.application.routes.url_helpers.rails_blob_path(object.profile_image, only_path: true)
        rescue => e
          # Last resort - return nil if we can't generate any URL
          Rails.logger.error("Unable to generate URL for profile_image: #{e.message}")
          nil
        end
      end
    else
      nil
    end
  rescue => e
    Rails.logger.error("Error generating profile_image_url: #{e.message}")
    nil
  end
end