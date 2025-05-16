class TrackContentSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  
  attributes :id, :content_type, :text_content, :title, :description, :created_at, :updated_at, :metadata, :file_url, :file_name, :file_size

  def file_url
    if object.file.attached?
      # Get URL for the attached file
      rails_blob_url(object.file)
    else
      nil
    end
  end
  
  def file_name
    if object.file.attached?
      object.file.filename.to_s
    else
      nil
    end
  end
  
  def file_size
    if object.file.attached?
      object.file.byte_size
    else
      nil
    end
  end
end