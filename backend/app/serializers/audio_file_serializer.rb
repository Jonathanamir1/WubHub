# backend/app/serializers/audio_file_serializer.rb
class AudioFileSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  
  attributes :id, :filename, :file_type, :file_size, :duration, :created_at, :updated_at, :metadata, :waveform_data, :file_url
  
  belongs_to :folder
  belongs_to :user
  belongs_to :project
  
  def file_url
    if object.file.attached?
      begin
        # Try to generate a URL with host
        rails_blob_url(object.file)
      rescue ArgumentError => e
        # Fall back to a relative path if host is not available
        begin
          Rails.application.routes.url_helpers.rails_blob_path(object.file, only_path: true)
        rescue => e
          # Last resort - return nil if we can't generate any URL
          Rails.logger.error("Unable to generate URL for file: #{e.message}")
          nil
        end
      end
    else
      nil
    end
  end
  
  def file_size
    object.file.attached? ? object.file.byte_size : object.file_size
  end
  
  def file_type
    object.file.attached? ? object.file.content_type : object.file_type
  end
end