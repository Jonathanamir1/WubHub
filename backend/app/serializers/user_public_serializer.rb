# For viewing other users' profiles - public info only, NO email
class UserPublicSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  
  attributes :id, :username, :bio, :profile_image_url, :created_at

  def profile_image_url
    if object.profile_image.attached?
      begin
        rails_blob_url(object.profile_image)
      rescue ArgumentError => e
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
end