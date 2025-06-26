# app/services/malicious_file_detection_service.rb
class MaliciousFileDetectionService
  # File extension categories for musicians
  AUDIO_EXTENSIONS = %w[mp3 wav aiff flac m4a ogg wma aac].freeze
  PROJECT_EXTENSIONS = %w[logicx als flp ptx reason cwp reapeaks rpp cpr npr].freeze
  DOCUMENT_EXTENSIONS = %w[pdf txt doc docx rtf md].freeze
  SPREADSHEET_EXTENSIONS = %w[xls xlsx csv].freeze
  IMAGE_EXTENSIONS = %w[jpg jpeg png gif bmp tiff svg].freeze
  VIDEO_EXTENSIONS = %w[mp4 mov avi mkv wmv].freeze
  ARCHIVE_EXTENSIONS = %w[zip rar 7z tar gz].freeze
  
  # Plugin extensions - medium risk but allowed for musicians
  PLUGIN_EXTENSIONS = %w[dll vst vst3 component au aax].freeze
  
  # Executable extensions - require verification
  EXECUTABLE_EXTENSIONS = %w[exe msi pkg dmg app].freeze
  
  # Script extensions - high risk
  SCRIPT_EXTENSIONS = %w[bat cmd ps1 vbs js sh py rb].freeze
  
  # Always blocked extensions - critical risk
  BLOCKED_EXTENSIONS = %w[scr pif com].freeze
  
  # Suspicious keywords in filenames
  SUSPICIOUS_KEYWORDS = %w[
    virus malware trojan keylogger backdoor rootkit
    hack crack keygen patch loader
  ].freeze
  
  def initialize
    Rails.logger.info "🛡️ MaliciousFileDetectionService initialized"
  end
  
  def scan_file(filename, content_type = nil)
    Rails.logger.debug "🔍 Scanning file: #{filename} (#{content_type})"
    
    result = ScanResult.new(filename, content_type)
    
    # Step 1: Basic validation - immediate high risk
    if filename.blank? || filename.strip.empty?
      result.add_threat('Invalid or missing filename')
      result.set_risk_level(:high)
      return result
    end
    
    sanitized_filename = filename.strip.downcase
    extension = extract_extension(sanitized_filename)
    
    # Step 2: Check for multiple extensions FIRST
    has_multiple_ext = has_multiple_extensions?(sanitized_filename)
    if has_multiple_ext
      result.add_threat('Multiple file extensions detected')
    end
    
    # Step 3: Check for immediate blocking conditions - critical risk
    if BLOCKED_EXTENSIONS.include?(extension)
      result.block_file('File type is always blocked for security')
      result.set_risk_level(:critical)
      return result
    end
    
    # Step 4: Check for other high-risk conditions
    high_risk_detected = has_multiple_ext
    
    if filename.length > 255
      result.add_threat('Filename exceeds safe length limits')
      high_risk_detected = true
    end
    
    if contains_path_traversal?(filename)
      result.add_threat('Path traversal attempt detected')
      high_risk_detected = true
    end
    
    if contains_suspicious_keywords?(sanitized_filename)
      result.add_threat('Executable with suspicious naming pattern')
      high_risk_detected = true
    end
    
    if SCRIPT_EXTENSIONS.include?(extension)
      result.add_threat('Script file with potential for malicious execution')
      high_risk_detected = true
    end
    
    # Step 5: MIME type validation - can trigger high risk
    if content_type.present? && has_mime_type_mismatch?(extension, content_type)
      result.add_threat('MIME type mismatch detected')
      high_risk_detected = true
    end
    
    # Step 6: Determine final risk level
    if high_risk_detected
      result.set_risk_level(:high)
    elsif PLUGIN_EXTENSIONS.include?(extension) || EXECUTABLE_EXTENSIONS.include?(extension)
      result.set_risk_level(:medium)
      result.require_verification
      result.add_warning('Executable file detected')
    else
      result.set_risk_level(:low)
      result.mark_safe
    end
    
    Rails.logger.debug "🔍 Scan complete: #{result.safe? ? 'SAFE' : 'THREAT'} (#{result.risk_level})"
    result
  end
  
  def scan_content(content, filename, content_type)
    Rails.logger.debug "🔍 Scanning content for: #{filename}"
    
    result = scan_file(filename, content_type)
    return result unless result.safe? || result.requires_verification?
    
    # Content analysis
    return result if content.nil? || content.empty?
    
    begin
      # Handle binary content safely
      safe_content = content.to_s.force_encoding(Encoding::BINARY)
      
      # Check for suspicious content patterns
      if analyze_content_patterns(safe_content, filename, content_type)
        result.add_threat('Suspicious binary content in text file')
        result.set_risk_level(:high)
      end
      
      result
    rescue => e
      Rails.logger.error "Content analysis failed: #{e.message}"
      result
    end
  end
  
  private
  
  def extract_extension(filename)
    return '' if filename.blank?
    
    # Handle multiple extensions by taking the last one
    parts = filename.split('.')
    return '' if parts.length < 2
    
    parts.last.downcase
  end
  
  def contains_path_traversal?(filename)
    return false if filename.blank?
    
    # Check for path traversal patterns
    filename.include?('../') || filename.include?('..\\') || filename.include?('../')
  end
  
  def has_multiple_extensions?(filename)
    return false if filename.blank?
    
    # Count dots that are followed by alphanumeric characters
    parts = filename.split('.')
    return false if parts.length < 3  # Need at least 3 parts for multiple extensions
    
    # Check if the last two parts look like extensions
    second_last = parts[-2]
    last = parts[-1]
    
    # Both should be 2-4 characters and alphanumeric
    second_last.length.between?(2, 4) && second_last.match?(/\A[a-z0-9]{2,4}\z/) &&
    last.length.between?(2, 4) && last.match?(/\A[a-z0-9]{2,4}\z/)
  end
  
  def contains_suspicious_keywords?(filename)
    SUSPICIOUS_KEYWORDS.any? { |keyword| filename.include?(keyword) }
  end
  
  def has_mime_type_mismatch?(extension, content_type)
    return false if content_type.blank?
    
    # Audio file claiming to be executable
    if AUDIO_EXTENSIONS.include?(extension) && content_type.include?('executable')
      return true
    end
    
    # Executable MIME type with non-executable extension
    if content_type.include?('executable') && !EXECUTABLE_EXTENSIONS.include?(extension)
      return true
    end
    
    false
  end
  
  def analyze_content_patterns(binary_content, filename, content_type)
    extension = extract_extension(filename.downcase)
    
    # Check for PE (Windows executable) headers in non-executable files
    if binary_content.start_with?("MZ") && !EXECUTABLE_EXTENSIONS.include?(extension)
      return true
    end
    
    false
  end
  
  # Simple, clean ScanResult class
  class ScanResult
    attr_reader :filename, :content_type, :risk_level, :threats, :warnings
    
    def initialize(filename, content_type)
      @filename = filename
      @content_type = content_type
      @risk_level = :low
      @threats = []
      @warnings = []
      @safe = true
      @blocked = false
      @requires_verification = false
    end
    
    def safe?
      @safe && @threats.empty?
    end
    
    def blocked?
      @blocked
    end
    
    def requires_verification?
      @requires_verification
    end
    
    def mark_safe
      @safe = true
    end
    
    def require_verification
      @requires_verification = true
    end
    
    def block_file(reason)
      @blocked = true
      @safe = false
      add_threat(reason)
      self
    end
    
    def add_threat(message)
      @threats << message
      @safe = false
      self
    end
    
    def add_warning(message)
      @warnings << message
      self
    end
    
    def set_risk_level(level)
      @risk_level = level
    end
    
    def details
      {
        filename: @filename,
        content_type: @content_type,
        risk_level: @risk_level,
        threats: @threats,
        warnings: @warnings,
        safe: safe?,
        blocked: blocked?,
        requires_verification: requires_verification?
      }
    end
    
    def file_type
      # Determine file type from extension
      extension = filename.to_s.split('.').last&.downcase || ''
      
      case extension
      when *AUDIO_EXTENSIONS then 'audio'
      when *PROJECT_EXTENSIONS then 'project'
      when *PLUGIN_EXTENSIONS then 'plugin'
      when *EXECUTABLE_EXTENSIONS then 'executable'
      when *SCRIPT_EXTENSIONS then 'script'
      when *BLOCKED_EXTENSIONS then 'blocked'
      else 'unknown'
      end
    end
    
    def extensions
      return [] if filename.blank?
      
      parts = filename.split('.')
      return [] if parts.length < 2
      
      parts[1..-1].map(&:downcase)
    end
  end
end