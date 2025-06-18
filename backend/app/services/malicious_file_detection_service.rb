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
    
    # Step 2: Check for multiple extensions BEFORE blocking (to get proper error message)
    has_multiple_ext = has_multiple_extensions?(sanitized_filename)
    if has_multiple_ext
      result.add_threat('Multiple file extensions detected')
      high_risk_detected = true
    end
    
    # Step 3: Check for immediate blocking conditions - critical risk
    if BLOCKED_EXTENSIONS.include?(extension)
      result.block_file('File type is always blocked for security')
      result.set_risk_level(:critical)
      return result
    end
    
    # Step 4: Check for other high-risk conditions
    # Step 4: Check for other high-risk conditions
    high_risk_detected = has_multiple_ext  # Already checked above
    
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
    
    # Content analysis - handle binary content safely from the start
    return result if content.nil? || content.empty?
    
    begin
      # Handle encoding issues immediately
      safe_content = content.dup
      
      # Force to binary encoding first to avoid UTF-8 issues
      if safe_content.respond_to?(:force_encoding)
        safe_content = safe_content.force_encoding(Encoding::BINARY)
      else
        safe_content = safe_content.to_s.force_encoding(Encoding::BINARY)
      end
      
      # Now convert \xNN sequences to actual bytes
      if safe_content.include?('\\x'.force_encoding(Encoding::BINARY))
        safe_content = safe_content.gsub(/\\x([0-9a-fA-F]{2})/) do |match|
          $1.hex.chr(Encoding::BINARY)
        end
      end
      
      if analyze_content_patterns(safe_content, filename, content_type)
        result.add_threat('Suspicious binary content in text file')
        result.set_risk_level(:high)
      end
      
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      Rails.logger.warn "🔍 Content encoding error: #{e.message}"
      result.add_warning('Unable to scan file content due to encoding issues')
    rescue ArgumentError => e
      Rails.logger.warn "🔍 Content argument error: #{e.message}"
      result.add_warning('Unable to scan file content for security patterns')
    rescue => e
      Rails.logger.warn "🔍 Content scanning error: #{e.message}"
      result.add_warning('Unable to scan file content for security patterns')
    end
    
    result
  end
  
  private
  
  def extract_extension(filename)
    parts = filename.split('.')
    return '' if parts.length < 2
    parts.last
  end
  
  def contains_path_traversal?(filename)
    filename.include?('..') || 
    filename.include?('\\') ||
    filename.start_with?('/') ||
    filename.include?('%2e%2e') || # URL encoded ..
    filename.include?('%2f') ||    # URL encoded /
    filename.include?('%5c')       # URL encoded \
  end
  
  def has_multiple_extensions?(filename)
    dots = filename.count('.')
    return false if dots <= 1
    
    parts = filename.split('.')
    return false if parts.length < 3
    
    # Get the last two parts
    second_to_last = parts[-2]
    last = parts[-1]
    
    # If both look like extensions (2-4 chars, alphanumeric), it's suspicious
    second_to_last.match?(/\A[a-z0-9]{2,4}\z/) && last.match?(/\A[a-z0-9]{2,4}\z/)
  end
  
  def contains_suspicious_keywords?(filename)
    SUSPICIOUS_KEYWORDS.any? { |keyword| filename.include?(keyword) }
  end
  
  def has_mime_type_mismatch?(extension, content_type)
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
  end
end