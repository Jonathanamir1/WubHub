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
  # Note: status and draggable_type presence is automatically validated by Rails enums
  
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
  
  # Instance methods
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
end