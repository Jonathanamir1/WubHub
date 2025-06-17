class UploadAssemblyJob < ApplicationJob
  queue_as :assembly
  
  # Retry failed jobs up to 3 times with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(upload_session_id)
    Rails.logger.info "🔧 Starting assembly for upload session #{upload_session_id}..."
    
    begin
      upload_session = UploadSession.find(upload_session_id)
      assembler = UploadAssembler.new(upload_session)
      
      # Check if assembly is ready
      unless assembler.can_assemble?
        status = assembler.assembly_status
        Rails.logger.error "❌ Upload session #{upload_session_id} not ready for assembly. Status: #{status}"
        upload_session.fail!
        return
      end
      
      Rails.logger.info "🔧 Assembling chunks for upload session #{upload_session_id}..."
      asset = assembler.assemble!
      
      Rails.logger.info "✅ Successfully assembled upload session #{upload_session_id} into asset #{asset.id}"
      
    rescue UploadAssembler::AssemblyError => e
      Rails.logger.error "❌ Assembly failed for upload session #{upload_session_id}: #{e.message}"
      # Don't call fail! here since UploadAssembler already handles it
      # Don't re-raise assembly errors - they're expected business logic failures
      
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Upload session not found: #{upload_session_id}"
      # Don't re-raise - this is an expected error condition
      
    rescue => e
      Rails.logger.error "❌ Unexpected error during assembly for upload session #{upload_session_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      upload_session&.fail! unless upload_session&.status == 'failed'
      # Re-raise unexpected errors for retry mechanism
      raise e
    end
  end
end