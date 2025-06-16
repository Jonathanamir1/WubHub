# app/models/asset.rb
class Asset < ApplicationRecord
  include Privatable
  
  # Associations
  belongs_to :workspace
  belongs_to :container, optional: true
  belongs_to :user
  has_one_attached :file_blob
  
  # Validations
  validates :filename, presence: true
  validates :filename, uniqueness: {
    scope: [:workspace_id, :container_id],
    message: 'has already been taken'
  }
  
  validate :container_must_be_in_same_workspace
  
  # Callbacks
  before_save :update_path
  
  # Delegations
  delegate :accessible_by?, to: :workspace
  
  # Instance methods
  def full_path
    if container.present?
      "#{container.full_path}/#{filename}"
    else
      "/#{filename}"
    end
  end
  
  def uploaded_by
    user.email  # Changed from user.username to user.email
  end
  
  def file_extension
    File.extname(filename).downcase
  end
  
  def file_type
    case file_extension
    when '.mp3', '.wav', '.aiff', '.flac', '.m4a'
      'audio'
    when '.mp4', '.mov', '.avi'
      'video'
    when '.jpg', '.jpeg', '.png', '.gif', '.bmp'
      'image'
    when '.pdf'
      'document'
    when '.txt', '.md'
      'text'
    else
      'other'
    end
  end
  
  def humanized_size
    return 'Unknown' unless file_size.present?
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = file_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end
  
  def download_url
    return nil unless file_blob.attached?
    
    Rails.application.routes.url_helpers.rails_blob_url(file_blob)
  rescue => e
    Rails.logger.error("Error generating download URL: #{e.message}")
    nil
  end
  
  def extract_file_metadata!
    return unless file_blob.attached?
    
    # Force analyze the blob to get metadata
    file_blob.analyze unless file_blob.analyzed?
    
    update_columns(
      file_size: file_blob.byte_size,
      content_type: file_blob.content_type
    )
  end
  
  private
  
  def update_path
    self.path = full_path
  end
  
  def container_must_be_in_same_workspace
    return unless container.present?
    
    if container.workspace_id != workspace_id
      errors.add(:container, 'must be in the same workspace')
    end
  end
end