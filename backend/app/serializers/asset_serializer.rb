class AssetSerializer < ActiveModel::Serializer
  attributes :id, :filename, :path, :file_size, :content_type, :workspace_id, :container_id, :user_id, :created_at, :updated_at, :download_url

  def file_size
    # Return actual byte size for API consistency, but keep humanized version available
    object.file_size
  end

  def humanized_size
    object.humanized_size
  end

  def uploader_email
    object.user.email
  end

  def download_url
    return nil unless object.file_blob.attached?
    
    begin
      Rails.application.routes.url_helpers.rails_blob_url(object.file_blob)
    rescue => e
      Rails.logger.error("Error generating download URL: #{e.message}")
      nil
    end
  end
end