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
  
  # 🔧 FIX: Define valid state transitions
  VALID_TRANSITIONS = {
    'pending' => %w[uploading failed cancelled],
    'uploading' => %w[assembling failed cancelled],
    'assembling' => %w[completed failed],
    'completed' => [],  # Terminal state - no transitions allowed
    'failed' => [],     # Terminal state - no transitions allowed
    'cancelled' => []   # Terminal state - no transitions allowed
  }.freeze
  
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
  
  # Metadata helper methods
  def file_type
    metadata&.dig('file_type')
  end
  
  def estimated_duration
    metadata&.dig('estimated_duration')
  end
  
  # Status transition methods with validation
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
    completed_chunks_count >= chunks_count
  end
  
  def completed_chunks_count
    chunks.where(status: 'completed').count
  end
  
  def pending_chunks_count
    chunks.where(status: 'pending').count
  end
  
  def failed_chunks_count
    chunks.where(status: 'failed').count
  end
  
  # Missing chunks method for serializer
  def missing_chunks
    completed_chunk_numbers = chunks.completed.pluck(:chunk_number)
    expected_chunks = (1..chunks_count).to_a
    expected_chunks - completed_chunk_numbers
  end
  
  # Recommended chunk size method for serializer
  def recommended_chunk_size
    # 🔧 FIX: Precise chunk size ranges to match all test expectations
    case total_size
    when 0..10.megabytes
      1.megabyte
    when 10.megabytes...1.gigabyte  # ← Use exclusive range (does not include 1GB)
      5.megabytes
    when 1.gigabyte..5.gigabytes     # ← 1GB exactly gets 10MB chunks
      10.megabytes
    else
      25.megabytes
    end
  end
  
  # File size calculations
  def uploaded_size
    chunks.where(status: 'completed').sum(:size)
  end
  
  def remaining_size
    total_size - uploaded_size
  end
  
  private
  
  # 🔧 FIX: Add state transition validation
  def transition_to!(new_status)
    unless can_transition_to?(new_status)
      raise InvalidTransition, "Cannot transition from #{status} to #{new_status}"
    end
    
    update!(status: new_status)
  end
  
  def can_transition_to?(new_status)
    VALID_TRANSITIONS[status]&.include?(new_status) || false
  end
  
  # 🔧 FIX: Change error message to match test expectation
  def container_must_be_in_same_workspace
    return unless container.present? && workspace.present?
    
    unless container.workspace_id == workspace.id
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
    
    # 🛡️ UPDATED: Much more relaxed validation - let the MaliciousFileDetectionService handle security
    dangerous_patterns = [
      /\A\s*\z/,           # Only whitespace
      /\A\.+\z/,           # Only dots
      /\.\./,              # Contains ../
      /[<>:"|*?]/,         # Windows forbidden chars  
      /\A(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)/i  # Windows reserved names
    ]
    
    dangerous_patterns.each do |pattern|
      if filename.match?(pattern)
        errors.add(:filename, 'contains unsafe characters or patterns')
        break
      end
    end
    
    # Check filename length (most filesystems have 255 char limit)
    if filename.length > 255
      errors.add(:filename, 'is too long (maximum 255 characters)')
    end
  end
  
  def total_size_within_limits
    return unless total_size.present?
    
    if total_size > MAX_FILE_SIZE
      errors.add(:total_size, "cannot exceed #{MAX_FILE_SIZE / 1.gigabyte}GB")
    end
  end
end