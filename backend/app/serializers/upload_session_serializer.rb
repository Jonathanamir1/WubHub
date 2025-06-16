# app/serializers/upload_session_serializer.rb
class UploadSessionSerializer < ActiveModel::Serializer
  attributes :id, :filename, :total_size, :chunks_count, :status, :metadata,
             :workspace_id, :container_id, :user_id, :created_at, :updated_at,
             :upload_location, :target_path, :progress_percentage, :all_chunks_uploaded,
             :missing_chunks, :uploaded_size, :recommended_chunk_size

  # Include uploader information
  def uploader_email
    object.user.email
  end

  # File type helper
  def file_type
    object.file_type
  end

  # Duration helper (if available in metadata)
  def estimated_duration
    object.estimated_duration
  end

  # Chunk statistics
  def total_chunks
    object.chunks_count
  end

  def completed_chunks
    object.chunks.where(status: 'completed').count
  end

  def pending_chunks
    object.chunks.where(status: 'pending').count
  end

  def failed_chunks
    object.chunks.where(status: 'failed').count
  end

  # Timestamps in user-friendly format
  def created_at_formatted
    object.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')
  end

  def updated_at_formatted
    object.updated_at.strftime('%Y-%m-%d %H:%M:%S UTC')
  end

  # Container information (if present)
  def container_name
    object.container&.name
  end

  def container_path
    object.container&.full_path
  end

  # Workspace information
  def workspace_name
    object.workspace.name
  end

  # File size in human readable format
  def total_size_human
    humanize_bytes(object.total_size)
  end

  def uploaded_size_human
    humanize_bytes(object.uploaded_size)
  end

  # Upload speed estimation (if chunks have timestamps)
  def estimated_completion_time
    return nil unless object.status == 'uploading'
    return nil if object.progress_percentage.zero?

    completed_chunks = object.chunks.where(status: 'completed')
    return nil if completed_chunks.empty?

    # Calculate average time per chunk
    total_time = completed_chunks.sum { |chunk| 
      chunk.updated_at - chunk.created_at 
    }
    avg_time_per_chunk = total_time / completed_chunks.count
    
    remaining_chunks = object.chunks_count - completed_chunks.count
    estimated_seconds = remaining_chunks * avg_time_per_chunk
    
    Time.current + estimated_seconds.seconds
  end

  # Error information (if failed)
  def error_message
    object.metadata['error_message'] if object.status == 'failed'
  end

  # Client information from metadata
  def client_info
    object.metadata['client_info']
  end

  def original_path
    object.metadata['original_path']
  end

  def upload_source
    object.metadata['upload_source']
  end

  private

  def humanize_bytes(bytes)
    return '0 B' if bytes.nil? || bytes.zero?

    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end
end