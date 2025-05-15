class UserSerializer < ActiveModel::Serializer
  attributes :id, :username, :name, :email, :bio, :profile_image_url, :created_at

  def profile_image_url
    if object.profile_image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(object.profile_image)
    else
      "/default-avatar.png"
    end
  end
end