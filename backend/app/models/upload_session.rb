# app/models/upload_session.rb (UPDATED VERSION)
class UploadSession < ApplicationRecord
  # Custom exception for invalid state transitions
  class InvalidTransition < StandardError; end
  
  # Associations
  belongs_to :workspace
  belongs_to :container, optional: true
  belongs_to :user
  has_many :chunks, dependent: :destroy
  
  # Constants - UPDATED to include virus scanning statuses
  VALID_STATUSES = %w[
    pending uploading assembling virus_scanning finalizing 
    completed failed cancelled virus_detected virus_scan_failed finalization_failed
  ].freeze
  
  MAX_FILE_SIZE = 5.gigabytes
  
  # UPDATED: Define valid state transitions including virus scanning flow
  VALID_TRANSITIONS = {
    'pending' => %w[uploading failed cancelled],
    'uploading' => %w[assembling failed cancelled],
    'assembling' => %w[virus_scanning failed],                    # NEW: Must go through virus scanning
    'virus_scanning' => %w[finalizing virus_detected virus_scan_failed], # NEW: Virus scanning outcomes
    'finalizing' => %w[completed finalization_failed],           # NEW: Final asset creation
    'completed' => [],                                           # Terminal state
    'failed' => [],                                             # Terminal state
    'cancelled' => [],                                          # Terminal state
    'virus_detected' => [],                                     # NEW: Terminal state - blocked
    'virus_scan_failed' => [],                                  # NEW: Terminal state - scan error
    'finalization_failed' => []                                 # NEW: Terminal state - asset creation error
  }.freeze
  
  # Validations
  validates :filename, presence: true, length: { maximum: 255 }
  validates :total_size, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: MAX_FILE_SIZE }
  validates :chunks_count, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  
  # Custom validations
  validates :filename, uniqueness: { 
    scope: [:workspace_id, :container_id],
    conditions: -> { where(status: ['pending', 'uploading', 'assembling', 'virus_scanning', 'finalizing']) },
    message: 'is already being uploaded to this location'
  }
  
  validate :container_must_be_in_same_workspace
  validate :user_must_have_upload_permission
  validate :filename_must_be_safe
  validate :total_size_within_limits
  
  # UPDATED: Scopes to include new statuses
  scope :active, -> { where(status: ['pending', 'uploading', 'assembling', 'virus_scanning', 'finalizing']) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: ['failed', 'virus_detected', 'virus_scan_failed', 'finalization_failed']) }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :for_location, ->(workspace, container) { where(workspace: workspace, container: container) }
  
  # UPDATED: Expired scope to include new statuses
  scope :expired, -> do
    where(
      "(status IN ('failed', 'virus_detected', 'virus_scan_failed', 'finalization_failed') AND created_at < ?) OR " \
      "(status = 'pending' AND created_at < ?) OR " \
      "(status IN ('virus_scanning', 'finalizing') AND created_at < ?)",
      24.hours.ago, 1.hour.ago, 2.hours.ago
    )
  end
  
  # Metadata helper methods
  def file_type
    metadata&.dig('file_type')
  end
  
  def estimated_duration
    metadata&.dig('estimated_duration')
  end
  
  # NEW: Virus scanning helper methods
  def virus_scan_status
    metadata&.dig('virus_scan', 'status')
  end
  
  def virus_scan_result
    metadata&.dig('virus_scan')
  end
  
  def virus_detected?
    status == 'virus_detected'
  end
  
  def virus_scan_pending?
    status == 'virus_scanning'
  end
  
  def virus_scan_failed?
    status == 'virus_scan_failed'
  end
  
  # Status transition methods with validation
  def start_upload!
    transition_to!('uploading')
  end
  
  def start_assembly!
    transition_to!('assembling')
  end
  
  # NEW: Virus scanning transition methods
  def start_virus_scan!
    transition_to!('virus_scanning')
  end
  
  def virus_detected!
    transition_to!('virus_detected')
  end
  
  def virus_scan_failed!
    transition_to!('virus_scan_failed')
  end
  
  def start_finalization!
    transition_to!('finalizing')
  end
  
  def finalization_failed!
    transition_to!('finalization_failed')
  end
  
  def complete!
    transition_to!('completed')
  end
  
  def fail!
    transition_to!('failed')
  end
  
  def cancel!
    raise InvalidTransition, "Cannot cancel from #{status}" if completed_or_failed?
    transition_to!('cancelled')
  end
  
  # Upload location methods
  def upload_location
    container.present? ? container.full_path : '/'
  end
  
  def target_path
    container.present? ? "#{container.full_path}/#{filename}" : "/#{filename}"
  end
  
  def full_path
    target_path
  end
  
  # Upload progress tracking
  def progress_percentage
    return 0.0 if chunks_count.zero?
    
    completed_count = chunks.where(status: 'completed').count
    (completed_count.to_f / chunks_count * 100).round(2)
  end
  
  def all_chunks_uploaded?
    chunks.where(status: 'completed').count == chunks_count
  end
  
  def uploaded_size
    chunks.where(status: 'completed').sum(:size)
  end
  
  def missing_chunks
    existing_chunk_numbers = chunks.pluck(:chunk_number)
    expected_chunks = (1..chunks_count).to_a
    expected_chunks - existing_chunk_numbers
  end
  
  def recommended_chunk_size
    # Calculate optimal chunk size based on total file size
    case total_size
    when 0..10.megabytes
      1.megabyte
    when 10.megabytes..100.megabytes
      5.megabytes
    when 100.megabytes..1.gigabyte
      10.megabytes
    else
      25.megabytes
    end
  end
  
  # NEW: Status checking helper methods
  def completed_or_failed?
    %w[completed failed virus_detected virus_scan_failed finalization_failed cancelled].include?(status)
  end
  
  def terminal_status?
    completed_or_failed?
  end
  
  def can_be_cancelled?
    !completed_or_failed?
  end
  
  def processing?
    %w[virus_scanning finalizing].include?(status)
  end
  
  private
  
  def transition_to!(new_status)
    raise InvalidTransition, "Invalid transition from #{status} to #{new_status}" unless can_transition_to?(new_status)
    
    update!(status: new_status)
  end
  
  def can_transition_to?(new_status)
    VALID_TRANSITIONS[status]&.include?(new_status) || false
  end
  
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
    
    # Relaxed validation - let the MaliciousFileDetectionService handle security
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