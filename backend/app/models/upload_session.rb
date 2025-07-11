# app/models/upload_session.rb
# Updated state machine to allow failed -> pending for retries

class UploadSession < ApplicationRecord
  # Custom exception for invalid state transitions
  class InvalidTransition < StandardError; end
  
  # Associations
  belongs_to :workspace
  belongs_to :container, optional: true
  belongs_to :user
  belongs_to :queue_item, optional: true
  has_many :chunks, dependent: :destroy
  
  # Constants
  VALID_STATUSES = %w[
    pending uploading assembling virus_scanning finalizing 
    completed failed cancelled virus_detected virus_scan_failed finalization_failed
  ].freeze
  
  MAX_FILE_SIZE = 5.gigabytes
  
  # UPDATED: Define valid state transitions - allow failed to go back to pending for retries
  VALID_TRANSITIONS = {
    'pending' => %w[uploading failed cancelled],
    'uploading' => %w[assembling failed cancelled pending],  # Allow pause: uploading -> pending
    'assembling' => %w[virus_scanning failed pending],       # Allow pause: assembling -> pending  
    'virus_scanning' => %w[finalizing virus_detected virus_scan_failed pending], # Allow pause
    'finalizing' => %w[completed finalization_failed pending], # Allow pause
    'completed' => [],
    'failed' => %w[pending],           # ALLOW RETRY: failed -> pending
    'cancelled' => %w[pending],        # ALLOW RETRY: cancelled -> pending  
    'virus_detected' => [],            # TERMINAL: No retries for security
    'virus_scan_failed' => %w[pending], # Allow retry of scan failures
    'finalization_failed' => %w[pending] # Allow retry of finalization failures
  }.freeze
  
  # Validations
  validates :filename, presence: true, length: { maximum: 255 }
  validates :total_size, presence: true, numericality: { 
    greater_than: 0,
    message: "must be greater than 0"
  }
  validates :total_size, numericality: { 
    less_than_or_equal_to: MAX_FILE_SIZE,
    message: "cannot exceed 5GB"
  }
  validates :chunks_count, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  
  # Custom validations
  validates :filename, uniqueness: { 
    scope: [:workspace_id, :container_id], 
    conditions: -> { where(status: %w[pending uploading assembling virus_scanning finalizing]) },
    message: 'is already being uploaded to this location'
  }
  
  validate :user_must_have_upload_permissions
  validate :valid_status_transition, on: :update, if: :status_changed?
  validate :container_must_belong_to_workspace
  validate :filename_must_be_safe
  
  # Scopes
  scope :active, -> { where(status: %w[pending uploading assembling virus_scanning finalizing]) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: %w[failed virus_detected virus_scan_failed finalization_failed]) }
  scope :retryable, -> { where(status: %w[failed cancelled virus_scan_failed finalization_failed]) }
  scope :terminal, -> { where(status: %w[completed virus_detected]) }
  scope :expired, -> { 
    where(
      "(status IN ('pending') AND created_at < ?) OR (status IN ('failed', 'cancelled') AND created_at < ?)",
      1.hour.ago, 24.hours.ago
    )
  }
  scope :for_location, ->(workspace, container) { 
    where(workspace: workspace, container: container) 
  }
  scope :recent, -> { order(created_at: :desc) }
  
  # Queue-related scopes
  scope :queued, -> { where.not(queue_item_id: nil) }
  scope :standalone, -> { where(queue_item_id: nil) }
  scope :for_queue_item, ->(queue_item) { where(queue_item: queue_item) }
  
  # Callbacks
  after_update :notify_queue_item_of_status_change, if: :saved_change_to_status?
  
  # Instance methods
  def progress_percentage
    return 100.0 if status == 'completed'
    return 0.0 if chunks.count == 0
    
    completed_chunks = chunks.where(status: 'completed').count
    (completed_chunks.to_f / chunks.count * 100).round(2)
  end
  
  def all_chunks_uploaded?
    chunks.where(status: 'completed').count == chunks_count
  end
  
  # Upload location methods
  def upload_location
    return '/' if container.nil?
    container.full_path
  end
  
  def target_path
    return "/#{filename}" if container.nil?
    "#{container.full_path}/#{filename}"
  end
  
  # Chunk management methods
  def missing_chunks
    expected_chunk_numbers = (1..chunks_count).to_a
    existing_chunk_numbers = chunks.pluck(:chunk_number)
    expected_chunk_numbers - existing_chunk_numbers
  end
  
  def uploaded_size
    chunks.where(status: 'completed').sum(:size)
  end
  
  # File size and chunk methods
  def recommended_chunk_size
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
  
  # Metadata helper methods
  def file_type
    metadata&.dig('file_type')
  end
  
  def estimated_duration
    metadata&.dig('estimated_duration')
  end
  
  def original_path
    metadata&.dig('original_path')
  end
  
  def client_info
    metadata&.dig('client_info')
  end
  
  def part_of_queue?
    queue_item_id.present?
  end
  
  def queue_batch_id
    queue_item&.batch_id
  end
  
  def queue_progress_context
    return nil unless part_of_queue?
    
    {
      queue_item_id: queue_item.id,
      batch_id: queue_item.batch_id,
      draggable_name: queue_item.draggable_name,
      total_files_in_queue: queue_item.total_files,
      file_position: queue_item.upload_sessions.where('created_at <= ?', created_at).count
    }
  end
  
  # State transition methods
  def start_upload!
    transition_to!('uploading')
  end
  
  def start_assembly!
    transition_to!('assembling')
  end
  
  def start_virus_scan!
    transition_to!('virus_scanning')
  end
  
  def start_finalization!
    transition_to!('finalizing')
  end
  
  def complete!
    transition_to!('completed')
  end
  
  def fail!
    transition_to!('failed')
  end
  
  def cancel!
    transition_to!('cancelled')
  end
  
  def detect_virus!
    transition_to!('virus_detected')
  end
  
  def virus_scan_failed!
    transition_to!('virus_scan_failed')
  end
  
  def finalization_failed!
    transition_to!('finalization_failed')
  end
  
  # NEW: Retry method for failed uploads
  def retry!
    transition_to!('pending')
  end
  
  # NEW: Pause method for active uploads  
  def pause!
    transition_to!('pending')
  end
  
  # NEW: Check if upload can be retried
  def retryable?
    status.in?(%w[failed cancelled virus_scan_failed finalization_failed])
  end
  
  # NEW: Check if upload is in terminal state
  def terminal?
    status.in?(%w[completed virus_detected])
  end
  
  after_update :notify_queue_item_of_status_change, if: :saved_change_to_status?

  private

  def notify_queue_item_of_status_change
    # Early return if no queue_item_id
    return unless queue_item_id.present?
    
    Rails.logger.debug "🔔 UploadSession #{id} status changed to #{status}, notifying queue item #{queue_item_id}"
    
    begin
      # Try to find the queue item explicitly instead of using the association
      queue = QueueItem.find(queue_item_id)
      
      case status
      when 'completed'
        Rails.logger.debug "📈 Upload session #{id} completed, updating queue item #{queue_item_id}"
        queue.mark_file_completed!
        Rails.logger.debug "✅ Queue item updated: completed_files=#{queue.reload.completed_files}"
      when 'failed', 'cancelled', 'virus_detected'
        Rails.logger.debug "📉 Upload session #{id} failed (#{status}), updating queue item #{queue_item_id}"
        queue.mark_file_failed!
        Rails.logger.debug "✅ Queue item updated: failed_files=#{queue.reload.failed_files}"
      else
        Rails.logger.debug "📝 Upload session #{id} status changed to #{status} (no queue update needed)"
      end
      
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "❌ Queue item #{queue_item_id} not found for upload session #{id}: #{e.message}"
    rescue => e
      Rails.logger.error "❌ Failed to notify queue item #{queue_item_id} of status change: #{e.message}"
      Rails.logger.error "❌ Error class: #{e.class.name}"
      # Don't re-raise - we don't want to break the upload session update
    end
  end
  
  def transition_to!(new_status)
    unless valid_transition?(status, new_status)
      raise InvalidTransition, "Invalid transition from #{status} to #{new_status}"
    end
    
    update!(status: new_status)
  end
  
  def valid_transition?(from_status, to_status)
    VALID_TRANSITIONS[from_status]&.include?(to_status) || false
  end
  
  def user_must_have_upload_permissions
    return if user.nil? || workspace.nil?
    
    # Owner can always upload
    return if workspace.user_id == user.id
    
    # Check for collaborator role
    unless user.roles.where(roleable_type: 'Workspace', roleable_id: workspace.id, name: 'collaborator').exists?
      errors.add(:user, 'must have upload permissions for this workspace')
    end
  end
  
  def valid_status_transition
    return unless status_was.present?
    
    unless valid_transition?(status_was, status)
      errors.add(:status, "cannot transition from #{status_was} to #{status}")
    end
  end
  
  def container_must_belong_to_workspace
    return unless container.present? && workspace.present?
    
    unless container.workspace_id == workspace.id
      errors.add(:container, 'must belong to the same workspace')
    end
  end
  
  def filename_must_be_safe
    return unless filename.present?
    
    # Collect all validation issues
    issues = []
    
    # Check for path traversal
    if filename.include?('../') || filename.include?('..\\')
      issues << 'path traversal'
    end
    
    # Check for Windows reserved names (without extension)
    basename = File.basename(filename, '.*').upcase
    windows_reserved = %w[CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9]
    
    if windows_reserved.include?(basename)
      issues << 'reserved system name'
    end
    
    # Check for hidden files and other suspicious patterns
    if filename.start_with?('.')
      issues << 'hidden file'
    end
    
    # Check for null bytes or other control characters
    if filename.include?("\x00") || filename.match?(/[\x00-\x1f\x7f]/)
      issues << 'invalid characters'
    end
    
    # Add comprehensive error message if any issues found
    if issues.any?
      errors.add(:filename, 'contains unsafe characters or patterns')
    end
  end
  
  def notify_queue_item_of_status_change
    return unless queue_item.present?
    
    case status
    when 'completed'
      queue_item.mark_file_completed!
    when 'failed', 'cancelled', 'virus_detected', 'virus_scan_failed', 'finalization_failed'
      queue_item.mark_file_failed!
    end
  end
end