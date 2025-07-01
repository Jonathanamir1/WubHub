# app/models/queue_item.rb
class QueueItem < ApplicationRecord
  # Associations
  belongs_to :workspace
  belongs_to :user
  has_many :upload_sessions, dependent: :destroy
  
  # Enums (integer-backed for Rails conventions)
  enum status: {
    pending: 0,
    processing: 1, 
    completed: 2,
    failed: 3,
    cancelled: 4
  }
  
  enum draggable_type: {
    folder: 0,
    file: 1, 
    mixed: 2
  }
  
  # Validations
  validates :batch_id, presence: true
  validates :draggable_name, presence: true
  validates :total_files, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :completed_files, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :failed_files, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  
  # Custom validations
  validate :completed_files_within_total
  validate :failed_files_within_total
  
  # Scopes
  scope :active, -> { where(status: ['pending', 'processing']) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :for_batch, ->(batch_id) { where(batch_id: batch_id) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  after_update :trigger_progress_update, if: :saved_change_to_completed_files_or_failed_files?
  
  # Core progress calculation methods (keep these - they're fundamental to the model)
  def progress_percentage
    return 0.0 if total_files.zero?
    (completed_files.to_f / total_files * 100).round(1)
  end
  
  def pending_files
    total_files - completed_files - failed_files
  end
  
  def is_complete?
    (completed_files + failed_files) >= total_files
  end
  
  def has_failures?
    failed_files > 0
  end
  
  # State mutation methods (keep these - they're core model behavior)
  def mark_file_completed!
    increment!(:completed_files)
    update_status_if_complete!
  end
  
  def mark_file_failed!
    increment!(:failed_files)
    update_status_if_complete!
  end
  
  def start_processing!
    update!(status: :processing)
  end
  
  def cancel!
    update!(status: :cancelled)
  end
  
  # Progress tracking integration
  def create_progress_tracker
    ProgressTracker.new(self)
  end
  
  def current_progress_tracker
    @current_progress_tracker ||= create_progress_tracker
  end
  
  # Get comprehensive progress (delegates to ProgressTracker when needed)
  def detailed_progress
    if current_progress_tracker.tracking_active?
      current_progress_tracker.calculate_progress
    else
      # Return basic progress when no active tracking
      {
        queue_id: id,
        batch_id: batch_id,
        draggable_name: draggable_name,
        total_files: total_files,
        completed_files: completed_files,
        failed_files: failed_files,
        pending_files: pending_files,
        overall_progress_percentage: progress_percentage,
        queue_status: status,
        tracking_active: false
      }
    end
  end
  
  # Calculate estimated completion time (delegates to ProgressTracker)
  def estimated_completion_time
    if current_progress_tracker.tracking_active?
      current_progress_tracker.estimate_completion_time
    else
      0 # No estimate available without tracking
    end
  end
  
  # Get current upload speed (delegates to ProgressTracker)
  def current_upload_speed
    if current_progress_tracker.tracking_active?
      current_progress_tracker.calculate_upload_speed
    else
      0.0
    end
  end
  
  # Get progress trend analysis (delegates to ProgressTracker)
  def progress_trend
    if current_progress_tracker.tracking_active?
      current_progress_tracker.progress_trend
    else
      { direction: :steady, files_per_minute: 0, bytes_per_second: 0, trend_confidence: 0.0 }
    end
  end
  
  # Batch operations
  def self.batch_update_progress(batch_id, completed_delta: 0, failed_delta: 0)
    queue_items = for_batch(batch_id)
    
    queue_items.each do |item|
      item.completed_files += completed_delta if completed_delta > 0
      item.failed_files += failed_delta if failed_delta > 0
      item.save!
    end
  end
  
  # Statistics methods
  def completion_rate
    return 0.0 if total_files.zero?
    completed_files.to_f / total_files
  end
  
  def failure_rate  
    return 0.0 if total_files.zero?
    failed_files.to_f / total_files
  end
  
  def processing_efficiency
    processed_files = completed_files + failed_files
    return 0.0 if processed_files.zero?
    completed_files.to_f / processed_files
  end
  
  # Workspace-level statistics
  def self.workspace_statistics(workspace)
    queue_items = for_workspace(workspace)
    
    {
      total_queues: queue_items.count,
      active_queues: queue_items.active.count,
      completed_queues: queue_items.completed.count,
      failed_queues: queue_items.failed.count,
      total_files: queue_items.sum(:total_files),
      completed_files: queue_items.sum(:completed_files),
      failed_files: queue_items.sum(:failed_files),
      overall_completion_rate: calculate_workspace_completion_rate(queue_items),
      average_queue_size: calculate_average_queue_size(queue_items)
    }
  end
  
  private
  
  def completed_files_within_total
    return unless completed_files && total_files
    
    if completed_files > total_files
      errors.add(:completed_files, 'cannot exceed total files')
    end
  end
  
  def failed_files_within_total
    return unless failed_files && total_files
    
    if failed_files > total_files
      errors.add(:failed_files, 'cannot exceed total files')
    end
  end
  
  def update_status_if_complete!
    return unless is_complete?
    
    if has_failures?
      update!(status: :failed)
    else
      update!(status: :completed)
    end
  end
  
  def saved_change_to_completed_files_or_failed_files?
    saved_change_to_completed_files? || saved_change_to_failed_files?
  end
  
  def trigger_progress_update
    # Trigger progress update event when files complete/fail
    ActiveSupport::Notifications.instrument(
      'queue_item.progress_updated',
      {
        queue_id: id,
        batch_id: batch_id,
        completed_files: completed_files,
        failed_files: failed_files,
        total_files: total_files,
        progress_percentage: progress_percentage
      }
    )
  rescue => e
    Rails.logger.error "Failed to trigger progress update notification: #{e.message}"
  end
  
  def self.calculate_workspace_completion_rate(queue_items)
    total_files = queue_items.sum(:total_files)
    return 0.0 if total_files.zero?
    
    completed_files = queue_items.sum(:completed_files)
    (completed_files.to_f / total_files * 100).round(2)
  end
  
  def self.calculate_average_queue_size(queue_items)
    return 0.0 if queue_items.empty?
    
    queue_items.average(:total_files).to_f
  end
end