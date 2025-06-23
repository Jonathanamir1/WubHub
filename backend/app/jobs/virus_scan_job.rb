# app/jobs/virus_scan_job.rb
# Generated with: rails generate job VirusScan
class VirusScanJob < ApplicationJob
  queue_as :virus_scanning
  
  # Retry failed scans with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(upload_session_id)
    Rails.logger.info "🦠 Starting virus scan job for upload session #{upload_session_id}"
    
    upload_session = UploadSession.find(upload_session_id)
    scanner_service = VirusScannerService.new
    
    begin
      # Perform synchronous file scan
      scan_result = scanner_service.scan_file_sync(upload_session.assembled_file_path)
      
      # Handle the scan result
      scanner_service.handle_scan_result(upload_session, scan_result)
      
      Rails.logger.info "✅ Virus scan job completed for upload session #{upload_session_id}: #{scan_result.clean? ? 'CLEAN' : 'INFECTED'}"
      
    rescue VirusScannerService::FileNotFoundError => e
      Rails.logger.error "❌ Virus scan failed - file not found: #{e.message}"
      mark_scan_failed(upload_session, "File not found: #{e.message}")
      
    rescue VirusScannerService::ScanTimeoutError => e
      Rails.logger.error "❌ Virus scan failed - timeout: #{e.message}"
      mark_scan_failed(upload_session, "Scan timeout: #{e.message}")
      
    rescue VirusScannerService::ScannerUnavailableError => e
      Rails.logger.error "❌ Virus scan failed - scanner unavailable: #{e.message}"
      # If scanner becomes unavailable during job execution, complete upload anyway
      complete_upload_without_scan(upload_session, "Scanner became unavailable: #{e.message}")
      
    rescue => e
      Rails.logger.error "❌ Virus scan job failed with unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      mark_scan_failed(upload_session, "Unexpected error: #{e.message}")
      raise # Re-raise to trigger retry mechanism
    end
  end
  
  private
  
  def mark_scan_failed(upload_session, error_message)
    upload_session.transaction do
      upload_session.update!(
        status: 'virus_scan_failed',
        virus_scan_completed_at: Time.current
      )
      
      upload_session.metadata ||= {}
      upload_session.metadata['virus_scan'] = {
        'status' => 'failed',
        'error' => error_message,
        'failed_at' => Time.current.iso8601,
        'scanner' => 'clamav'
      }
      upload_session.save!
    end
  end
  
  def complete_upload_without_scan(upload_session, reason)
    upload_session.transaction do
      upload_session.update!(status: 'completed')
      
      upload_session.metadata ||= {}
      upload_session.metadata['virus_scan'] = {
        'status' => 'skipped',
        'reason' => reason,
        'skipped_at' => Time.current.iso8601
      }
      upload_session.save!
    end
  end
end