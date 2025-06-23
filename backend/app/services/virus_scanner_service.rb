class VirusScannerService
  # Configuration constants
  SCAN_TIMEOUT = 30.seconds
  CLAMAV_HOST = 'localhost'
  CLAMAV_PORT = 3310
  
  # Custom error classes
  class Error < StandardError; end
  class InvalidFileError < Error; end
  class InvalidStatusError < Error; end
  class FileNotFoundError < Error; end
  class ScannerUnavailableError < Error; end
  class ScanTimeoutError < Error; end
  
  def initialize
    Rails.logger.info "🦠 VirusScannerService initialized"
  end
  
  # Main entry point: Queue virus scan for assembled file
  def scan_assembled_file_async(upload_session)
    Rails.logger.info "🦠 Queueing virus scan for #{upload_session.filename}"
    
    validate_upload_session!(upload_session)
    
    if clamav_available?
      # Start virus scanning process
      upload_session.transaction do
        upload_session.update!(
          status: 'virus_scanning',
          virus_scan_queued_at: Time.current
        )
        
        # Update metadata
        upload_session.metadata ||= {}
        upload_session.metadata['virus_scan'] = {
          'scanner' => 'clamav',
          'queued_at' => Time.current.iso8601,
          'status' => 'scanning'
        }
        upload_session.save!
        
        # Enqueue background job
        VirusScanJob.perform_later(upload_session.id)
      end
      
      Rails.logger.info "✅ Virus scan queued for upload session #{upload_session.id}"
    else
      # ClamAV not available - skip scanning but allow upload to complete
      Rails.logger.warn "⚠️ ClamAV not available, skipping virus scan for #{upload_session.filename}"
      
      upload_session.transaction do
        upload_session.update!(status: 'completed')
        
        upload_session.metadata ||= {}
        upload_session.metadata['virus_scan'] = {
          'status' => 'unavailable',
          'error' => 'ClamAV not available - file uploaded without virus scan',
          'skipped_at' => Time.current.iso8601
        }
        upload_session.save!
      end
    end
  end
  
  # Synchronous file scanning (called by background job)
  def scan_file_sync(file_path)
    Rails.logger.debug "🔍 Starting virus scan for file: #{file_path}"
    
    raise ScannerUnavailableError, "ClamAV is not available" unless clamav_available?
    raise FileNotFoundError, "File not found: #{file_path}" unless File.exist?(file_path)
    
    start_time = Time.current
    file_size = File.size(file_path)
    
    begin
      # Execute ClamAV scan with timeout
      scan_output = Timeout.timeout(SCAN_TIMEOUT) do
        execute_clamav_scan(file_path)
      end
      
      scan_duration = Time.current - start_time
      
      # Parse ClamAV output
      result = parse_clamav_output(scan_output, file_size, scan_duration)
      
      Rails.logger.info "🦠 Virus scan completed: #{result.clean? ? 'CLEAN' : 'INFECTED'} (#{scan_duration.round(2)}s)"
      
      result
      
    rescue Timeout::Error
      raise ScanTimeoutError, "Virus scan timed out after #{SCAN_TIMEOUT} seconds"
    rescue => e
      Rails.logger.error "❌ Virus scan failed: #{e.message}"
      raise Error, "Virus scan failed: #{e.message}"
    end
  end
  
  # Handle scan result and update upload session
  def handle_scan_result(upload_session, scan_result)
    Rails.logger.info "🦠 Processing scan result for #{upload_session.filename}: #{scan_result.clean? ? 'CLEAN' : 'INFECTED'}"
    
    upload_session.transaction do
      upload_session.update!(
        virus_scan_completed_at: Time.current
      )
      
      # Update metadata with scan results
      upload_session.metadata ||= {}
      upload_session.metadata['virus_scan'] ||= {}
      upload_session.metadata['virus_scan'].merge!(scan_result.to_h.deep_stringify_keys)
      
      if scan_result.clean?
        # File is clean - proceed to finalization
        upload_session.update!(status: 'finalizing')
        upload_session.metadata['virus_scan']['status'] = 'clean'
        upload_session.save!
        
        # Enqueue finalization job
        FinalizeUploadJob.perform_later(upload_session.id)
        
        Rails.logger.info "✅ Clean file - proceeding to finalization"
        
      else
        # File is infected - block and cleanup
        upload_session.update!(status: 'virus_detected')
        upload_session.metadata['virus_scan']['status'] = 'infected'
        upload_session.save!
        
        # Delete infected file
        cleanup_infected_file(upload_session.assembled_file_path)
        
        Rails.logger.warn "🚫 VIRUS DETECTED: #{scan_result.virus_name} in #{upload_session.filename}"
      end
    end
  end
  
  # Check if ClamAV is available and running
  def clamav_available?
    # Try daemon connection first (faster)
    begin
      socket = TCPSocket.new(CLAMAV_HOST, CLAMAV_PORT)
      socket.write("PING\n")
      response = socket.gets
      socket.close
      
      return response&.strip == "PONG"
      
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      Rails.logger.warn "🦠 ClamAV daemon not reachable at #{CLAMAV_HOST}:#{CLAMAV_PORT} - #{e.message}"
    end
    
    # Fallback to command line check
    begin
      clamscan_path = `which clamscan 2>/dev/null`.strip
      return system('which clamscan 2>/dev/null >/dev/null') && !clamscan_path.empty?
    rescue => e
      Rails.logger.warn "🦠 ClamAV command line check failed: #{e.message}"
      return false
    end
  end
  
  private
  
  def validate_upload_session!(upload_session)
    if upload_session.assembled_file_path.blank?
      raise InvalidFileError, "assembled_file_path is required for virus scanning"
    end
    
    unless upload_session.status == 'assembling'
      raise InvalidStatusError, "Upload session must be in assembling status, got: #{upload_session.status}"
    end
    
    unless File.exist?(upload_session.assembled_file_path)
      raise FileNotFoundError, "Assembled file not found at: #{upload_session.assembled_file_path}"
    end
  end
  
  def execute_clamav_scan(file_path)
    # Use clamscan command line tool for scanning
    # --stdout: output to stdout
    # --no-summary: don't show summary
    # --infected: only show infected files
    cmd = "clamscan --stdout --no-summary '#{file_path}'"
    
    Rails.logger.debug "🦠 Executing: #{cmd}"
    
    output = `#{cmd} 2>&1`
    exit_code = $?.exitstatus
    
    Rails.logger.debug "🦠 ClamAV exit code: #{exit_code}"
    Rails.logger.debug "🦠 ClamAV output: #{output}"
    
    {
      output: output,
      exit_code: exit_code
    }
  end
  
  def parse_clamav_output(scan_output, file_size, scan_duration)
    output = scan_output[:output]
    exit_code = scan_output[:exit_code]
    
    case exit_code
    when 0
      # Clean file
      ScanResult.new(
        clean: true,
        virus_name: nil,
        scanner: 'clamav',
        scan_duration: scan_duration,
        file_size: file_size
      )
    when 1
      # Virus found
      virus_name = extract_virus_name(output)
      ScanResult.new(
        clean: false,
        virus_name: virus_name,
        scanner: 'clamav',
        scan_duration: scan_duration,
        file_size: file_size
      )
    else
      # Error occurred
      raise Error, "ClamAV scan error (exit code #{exit_code}): #{output}"
    end
  end
  
  def extract_virus_name(output)
    # ClamAV output format: "filename: VIRUS_NAME FOUND"
    if match = output.match(/:\s*(.+?)\s+FOUND/)
      match[1]
    else
      'Unknown virus'
    end
  end
  
  def cleanup_infected_file(file_path)
    return unless file_path && File.exist?(file_path)
    
    begin
      File.delete(file_path)
      Rails.logger.info "🗑️ Deleted infected file: #{file_path}"
    rescue => e
      Rails.logger.error "❌ Failed to delete infected file #{file_path}: #{e.message}"
      # Don't re-raise - we don't want cleanup errors to break the flow
    end
  end
  
  # Simple, clean ScanResult class
  class ScanResult
    attr_reader :scanner, :scan_duration, :file_size, :virus_name
    
    def initialize(clean:, virus_name:, scanner:, scan_duration:, file_size:)
      @clean = clean
      @virus_name = virus_name
      @scanner = scanner
      @scan_duration = scan_duration
      @file_size = file_size
      @scanned_at = Time.current
    end
    
    def clean?
      @clean
    end
    
    def infected?
      !@clean
    end
    
    def to_h
      {
        clean: clean?,
        infected: infected?,
        virus_name: @virus_name,
        scanner: @scanner,
        scan_duration: @scan_duration,
        file_size: @file_size,
        scanned_at: @scanned_at
      }
    end
  end
end