class UserSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  
  attributes :id, :username, :bio, :profile_image_url, :created_at
  
  # Only include email for the user's own profile
  attribute :email, if: :show_email?

  def profile_image_url
    if object.profile_image.attached?
      begin
        rails_blob_url(object.profile_image)
      rescue ArgumentError
        begin
          Rails.application.routes.url_helpers.rails_blob_path(object.profile_image, only_path: true)
        rescue => e
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
  
  def show_email?
    # Show email only if this is the current user viewing their own profile
    scope && scope[:current_user] && scope[:current_user] == object
  end
  

end