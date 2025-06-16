# app/models/upload_session.rb
class UploadSession < ApplicationRecord
  # Custom exception for invalid state transitions
  class InvalidTransition < StandardError; end
  
  # Associations
  belongs_to :workspace
  belongs_to :container, optional: true
  belongs_to :user
  has_many :chunks, dependent: :destroy
  
  # Constants
  VALID_STATUSES = %w[pending uploading assembling completed failed cancelled].freeze
  MAX_FILE_SIZE = 5.gigabytes
  
  # Validations
  validates :filename, presence: true, length: { maximum: 255 }
  validates :total_size, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: MAX_FILE_SIZE }
  validates :chunks_count, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  
  # Custom validations
  validates :filename, uniqueness: { 
    scope: [:workspace_id, :container_id],
    conditions: -> { where(status: ['pending', 'uploading', 'assembling']) },
    message: 'is already being uploaded to this location'
  }
  
  validate :container_must_be_in_same_workspace
  validate :user_must_have_upload_permission
  validate :filename_must_be_safe
  validate :total_size_within_limits
  
  # Scopes
  scope :active, -> { where(status: ['pending', 'uploading', 'assembling']) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :for_location, ->(workspace, container) { where(workspace: workspace, container: container) }
  scope :expired, -> do
    where(
      "(status = 'failed' AND created_at < ?) OR (status = 'pending' AND created_at < ?)",
      24.hours.ago, 1.hour.ago
    )
  end
  
  # Status transition methods
  def start_upload!
    transition_to!('uploading')
  end
  
  def start_assembly!
    transition_to!('assembling')
  end
  
  def complete!
    transition_to!('completed')
  end
  
  def fail!
    transition_to!('failed')
  end
  
  def cancel!
    raise InvalidTransition, "Cannot cancel from #{status}" if %w[completed failed].include?(status)
    transition_to!('cancelled')
  end
  
  # Upload location methods
  def upload_location
    container.present? ? container.full_path : '/'
  end
  
  def target_path
    container.present? ? "#{container.full_path}/#{filename}" : "/#{filename}"
  end
  
  # Chunk management methods
  def progress_percentage
    return 0.0 if chunks_count.zero?
    (completed_chunks_count.to_f / chunks_count * 100).round(2)
  end
  
  def all_chunks_uploaded?
    completed_chunks_count == chunks_count
  end
  
  def missing_chunks
    uploaded_chunk_numbers = chunks.where(status: 'completed').pluck(:chunk_number)
    (1..chunks_count).to_a - uploaded_chunk_numbers
  end
  
  def uploaded_size
    chunks.where(status: 'completed').sum(:size)
  end
  
  # File size helpers
  def recommended_chunk_size
    case total_size
    when 0..50.megabytes
      1.megabyte
    when 50.megabytes..500.megabytes
      5.megabytes
    else
      10.megabytes
    end
  end
  
  # Metadata helpers
  def file_type
    metadata['file_type']
  end
  
  def estimated_duration
    metadata['estimated_duration']
  end
  
  private
  
  def completed_chunks_count
    chunks.where(status: 'completed').count
  end
  
  def transition_to!(new_status)
    # Check if transition is valid
    if new_status == 'failed'
      # Can fail from any state
    elsif status == 'pending' && new_status == 'uploading'
      # Valid transition
    elsif status == 'uploading' && new_status == 'assembling'
      # Valid transition
    elsif status == 'assembling' && new_status == 'completed'
      # Valid transition
    elsif %w[pending uploading].include?(status) && new_status == 'cancelled'
      # Can cancel from non-terminal states
    elsif %w[completed failed cancelled].include?(status) && new_status != 'failed'
      # Cannot transition from terminal states (except to failed)
      raise InvalidTransition, "Cannot transition from #{status} to #{new_status}"
    else
      # Invalid transition
      raise InvalidTransition, "Invalid transition from #{status} to #{new_status}"
    end
    
    update!(status: new_status)
  end
  
  def container_must_be_in_same_workspace
    return unless container.present?
    
    if container.workspace_id != workspace_id
      errors.add(:container, 'must belong to the same workspace')
    end
  end
  
  def user_must_have_upload_permission
    return unless workspace.present? && user.present?
    
    # Check if user is owner
    return if workspace.user_id == user.id
    
    # Check if user has collaborator role
    user_role = user.roles.find_by(roleable: workspace)
    return if user_role&.name == 'collaborator'
    
    errors.add(:user, 'must have upload permissions for this workspace')
  end
  
  def filename_must_be_safe
    return unless filename.present?
    
    dangerous_patterns = [
      /\A\s*\z/,           # Only whitespace
      /\A\.+/,             # Starts with dots (including single dot)
      /\.\./,              # Contains ../
      /[<>:"|*?]/,         # Windows forbidden chars
      /\A(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)/i  # Windows reserved names
    ]
    
    # Don't reject .exe.mp3 - that's a valid audio filename
    # Only reject actual executables without audio extensions
    if filename.match?(/\.(exe|bat|cmd|com|scr|pif)$/i) && !filename.match?(/\.(mp3|wav|aiff|flac|m4a)$/i)
      errors.add(:filename, 'contains unsafe file extension')
      return
    end
    
    dangerous_patterns.each do |pattern|
      if filename.match?(pattern)
        errors.add(:filename, 'contains unsafe characters or patterns')
        break
      end
    end
  end
  
  def total_size_within_limits
    return unless total_size.present?
    
    if total_size > MAX_FILE_SIZE
      errors.add(:total_size, 'cannot exceed 5GB')
    end
  end
end