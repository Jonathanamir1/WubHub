# app/jobs/upload_cleanup_job.rb
class UploadCleanupJob < ApplicationJob
  queue_as :cleanup
  
  # Retry failed jobs up to 3 times with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform
    Rails.logger.info "🧹 Starting upload cleanup job..."
    
    start_time = Time.current
    
    # Clean up expired upload sessions
    cleanup_expired_sessions
    
    # Handle stuck assembling sessions
    cleanup_stuck_assembling_sessions
    
    end_time = Time.current
    duration = (end_time - start_time).round(2)
    
    Rails.logger.info "🧹 Upload cleanup completed in #{duration} seconds"
  end
  
  private
  
  def cleanup_expired_sessions
    expired_count = 0
    error_count = 0
    
    Rails.logger.info "🧹 Cleaning up expired upload sessions..."
    
    # Get expired sessions from model scope
    expired_sessions = UploadSession.expired
    
    # Also include old cancelled sessions (older than 24 hours)
    old_cancelled = UploadSession.where(
      status: 'cancelled',
      created_at: ..24.hours.ago
    )
    
    # Combine both sets of sessions to clean up
    all_sessions_to_cleanup = UploadSession.where(
      id: expired_sessions.pluck(:id) + old_cancelled.pluck(:id)
    )
    
    # Use find_each for memory efficiency with large datasets
    all_sessions_to_cleanup.find_each(batch_size: 50) do |upload_session|
      begin
        cleanup_single_session(upload_session)
        expired_count += 1
      rescue => e
        error_count += 1
        Rails.logger.error "❌ Failed to cleanup upload session #{upload_session.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Continue processing other sessions even if one fails
        next
      end
    end
    
    Rails.logger.info "🧹 Cleaned up #{expired_count} expired sessions (#{error_count} errors)"
  end
  
  def cleanup_stuck_assembling_sessions
    stuck_count = 0
    
    Rails.logger.info "🧹 Checking for stuck assembling sessions..."
    
    # Find sessions stuck in assembling state for more than 1 hour
    stuck_sessions = UploadSession.where(
      status: 'assembling',
      updated_at: ..1.hour.ago
    )
    
    stuck_sessions.find_each(batch_size: 50) do |upload_session|
      begin
        Rails.logger.warn "⚠️ Marking stuck assembling session #{upload_session.id} as failed"
        upload_session.fail!
        stuck_count += 1
      rescue => e
        Rails.logger.error "❌ Failed to mark session #{upload_session.id} as failed: #{e.message}"
      end
    end
    
    if stuck_count > 0
      Rails.logger.info "🧹 Marked #{stuck_count} stuck sessions as failed"
    end
  end
  
  def cleanup_single_session(upload_session)
    session_id = upload_session.id
    Rails.logger.debug "🧹 Cleaning up session #{session_id} (#{upload_session.status}, #{upload_session.filename})"
    
    # Clean up chunk files before destroying the session
    cleanup_chunk_files(upload_session)
    
    # Destroy the upload session (chunks will be destroyed via dependent: :destroy)
    upload_session.destroy!
    
    Rails.logger.debug "✅ Successfully cleaned up session #{session_id}"
  end
  
  def cleanup_chunk_files(upload_session)
    chunk_files_deleted = 0
    chunk_files_failed = 0
    
    upload_session.chunks.each do |chunk|
      next unless chunk.storage_key.present?
      
      begin
        if File.exist?(chunk.storage_key)
          File.delete(chunk.storage_key)
          chunk_files_deleted += 1
          Rails.logger.debug "🗑️ Deleted chunk file: #{chunk.storage_key}"
        else
          Rails.logger.debug "📁 Chunk file already missing: #{chunk.storage_key}"
        end
      rescue => e
        chunk_files_failed += 1
        Rails.logger.warn "⚠️ Failed to delete chunk file #{chunk.storage_key}: #{e.message}"
        
        # Continue processing other chunk files even if one fails
        next
      end
    end
    
    if chunk_files_deleted > 0 || chunk_files_failed > 0
      Rails.logger.debug "🗑️ Chunk files: #{chunk_files_deleted} deleted, #{chunk_files_failed} failed"
    end
  end
end