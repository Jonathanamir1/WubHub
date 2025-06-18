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
  
  # Safe MIME type patterns
  SAFE_MIME_PATTERNS = {
    audio: /\Aaudio\//,
    video: /\Avideo\//,
    image: /\Aimage\//,
    text: /\Atext\//,
    pdf: /\Aapplication\/pdf\z/,
    office: /\Aapplication\/vnd\.(openxml|ms-)/,
    archive: /\Aapplication\/(zip|x-rar|x-7z)/
  }.freeze
  
  def initialize
    Rails.logger.info "🛡️ MaliciousFileDetectionService initialized"
  end
  
  def scan_file(filename, content_type = nil)
    Rails.logger.debug "🔍 Scanning file: #{filename} (#{content_type})"
    
    result = ScanResult.new(filename, content_type)
    
    # Basic validation
    return result.add_threat('Invalid or missing filename', :high) if filename.blank? || filename.strip.empty?
    
    sanitized_filename = filename.strip.downcase
    extension = extract_extension(sanitized_filename)
    
    # Check filename length
    if filename.length > 255
      result.add_threat('Filename exceeds safe length limits', :high)
    end
    
    # Check for path traversal
    if contains_path_traversal?(filename)
      result.add_threat('Path traversal attempt detected', :high)
    end
    
    # Check for multiple extensions (potential masquerading)
    has_multiple_ext = has_multiple_extensions?(sanitized_filename)
    if has_multiple_ext
      result.add_threat('Multiple file extensions detected')
    end
    
    # Check against blocked extensions first
    if BLOCKED_EXTENSIONS.include?(extension)
      return result.block_file('File type is always blocked for security', :critical)
    end
    
    # Check for suspicious keywords
    has_suspicious_keywords = contains_suspicious_keywords?(sanitized_filename)
    if has_suspicious_keywords
      result.add_threat('Executable with suspicious naming pattern')
    end
    
    # Categorize file by extension
    base_risk_level = categorize_file_risk(extension)
    
    # Override risk level if we found high-risk patterns
    if has_multiple_ext || has_suspicious_keywords
      risk_level = :high
    else
      risk_level = base_risk_level
    end
    
    result.set_risk_level(risk_level)
    
    # Handle different risk categories
    case risk_level
    when :low
      result.mark_safe
    when :medium
      result.require_verification
      if PLUGIN_EXTENSIONS.include?(extension) || EXECUTABLE_EXTENSIONS.include?(extension)
        result.add_warning('Executable file detected')
      end
    when :high
      if SCRIPT_EXTENSIONS.include?(extension)
        result.add_threat('Script file with potential for malicious execution', :high)
      end
    end
    
    # MIME type validation
    if content_type.present?
      validate_mime_type(result, extension, content_type)
    end
    
    Rails.logger.debug "🔍 Scan complete: #{result.safe? ? 'SAFE' : 'THREAT'} (#{result.risk_level})"
    result
  end
  
  def scan_content(content, filename, content_type)
    Rails.logger.debug "🔍 Scanning content for: #{filename}"
    
    result = scan_file(filename, content_type)
    return result unless result.safe? || result.requires_verification?
    
    # Basic content analysis - handle binary content safely
    if content.present?
      begin
        # Create a copy and force encoding to handle binary content
        content_copy = content.dup
        content_copy = content_copy.force_encoding('BINARY') if content_copy.respond_to?(:force_encoding)
        analyze_content_patterns(result, content_copy, filename, content_type)
      rescue ArgumentError, Encoding::InvalidByteSequenceError => e
        Rails.logger.warn "🔍 Content scanning error: #{e.message}"
        # If we can't scan content safely, add a warning but don't fail
        result.add_warning('Unable to scan file content for security patterns')
      end
    end
    
    result
  end
  
  private
  
  def extract_extension(filename)
    # Get the final extension after the last dot
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
    # Count dots - if more than one, could be multiple extensions
    dots = filename.count('.')
    return false if dots <= 1
    
    # Check if it looks like file.ext1.ext2 pattern
    parts = filename.split('.')
    return false if parts.length < 3
    
    # Get the last two parts
    second_to_last = parts[-2]
    last = parts[-1]
    
    # If both look like extensions (3-4 chars, alphanumeric), it's suspicious
    second_to_last.match?(/\A[a-z0-9]{2,4}\z/) && last.match?(/\A[a-z0-9]{2,4}\z/)
  end
  
  def contains_suspicious_keywords?(filename)
    SUSPICIOUS_KEYWORDS.any? { |keyword| filename.include?(keyword) }
  end
  
  def categorize_file_risk(extension)
    return :low if AUDIO_EXTENSIONS.include?(extension)
    return :low if PROJECT_EXTENSIONS.include?(extension)
    return :low if DOCUMENT_EXTENSIONS.include?(extension)
    return :low if SPREADSHEET_EXTENSIONS.include?(extension)
    return :low if IMAGE_EXTENSIONS.include?(extension)
    return :low if VIDEO_EXTENSIONS.include?(extension)
    return :low if ARCHIVE_EXTENSIONS.include?(extension)
    
    return :medium if PLUGIN_EXTENSIONS.include?(extension)
    return :medium if EXECUTABLE_EXTENSIONS.include?(extension)
    
    return :high if SCRIPT_EXTENSIONS.include?(extension)
    
    # Unknown extension - medium risk
    :medium
  end
  
  def validate_mime_type(result, extension, content_type)
    # Check for obvious mismatches
    expected_type = expected_mime_type_for_extension(extension)
    
    if expected_type && !content_type.match?(expected_type)
      # Special case: allow octet-stream for binary files like plugins
      unless content_type == 'application/octet-stream' && 
             (PLUGIN_EXTENSIONS.include?(extension) || 
              PROJECT_EXTENSIONS.include?(extension) ||
              EXECUTABLE_EXTENSIONS.include?(extension))
        result.add_threat('MIME type mismatch detected', :high)
      end
    end
    
    # Flag if executable MIME type with non-executable extension
    if content_type.include?('executable') && !EXECUTABLE_EXTENSIONS.include?(extension)
      result.add_threat('MIME type mismatch detected', :high)
    end
  end
  
  def expected_mime_type_for_extension(extension)
    case extension
    when *AUDIO_EXTENSIONS
      SAFE_MIME_PATTERNS[:audio]
    when *IMAGE_EXTENSIONS
      SAFE_MIME_PATTERNS[:image]
    when *VIDEO_EXTENSIONS
      SAFE_MIME_PATTERNS[:video]
    when 'pdf'
      SAFE_MIME_PATTERNS[:pdf]
    when 'txt', 'md'
      SAFE_MIME_PATTERNS[:text]
    when 'doc', 'docx', 'xls', 'xlsx'
      SAFE_MIME_PATTERNS[:office]
    else
      nil # No specific expectation
    end
  end
  
  def analyze_content_patterns(result, content, filename, content_type)
    begin
      # Handle binary content safely - content should already be BINARY encoded
      safe_content = content.dup.force_encoding('BINARY')
      
      # Check for PE (Windows executable) headers in non-executable files
      if safe_content.start_with?("MZ") && !EXECUTABLE_EXTENSIONS.include?(extract_extension(filename.downcase))
        result.add_threat('Suspicious binary content in text file', :high)
      end
      
      # Check for script-like content in non-script files
      # Convert to UTF-8 for pattern matching, replacing invalid bytes
      begin
        text_content = safe_content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        if contains_script_patterns?(text_content) && !SCRIPT_EXTENSIONS.include?(extract_extension(filename.downcase))
          result.add_warning('File contains script-like patterns')
        end
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        # If encoding conversion fails, skip text pattern analysis
        Rails.logger.debug "🔍 Skipping text pattern analysis due to encoding issues"
      end
    rescue ArgumentError => e
      Rails.logger.warn "🔍 Content pattern analysis error: #{e.message}"
      # Don't fail on content analysis errors
    end
  end
  
  def contains_script_patterns?(content)
    # Look for common script patterns
    script_patterns = [
      /powershell/i,
      /cmd\.exe/i,
      /system\(/i,
      /exec\(/i,
      /@echo\s+off/i,
      /\$\(.*\)/,  # Shell command substitution
      /<%.*%>/     # VBScript/ASP patterns
    ]
    
    script_patterns.any? { |pattern| content.match?(pattern) }
  end
  
  # Inner class for scan results
  class ScanResult
    attr_reader :filename, :content_type, :risk_level, :threats, :warnings, :details
    
    def initialize(filename, content_type)
      @filename = filename
      @content_type = content_type
      @risk_level = :low
      @threats = []
      @warnings = []
      @details = {}
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
    
    def block_file(reason, level = :critical)
      @blocked = true
      @safe = false
      add_threat(reason, level)
      self
    end
    
    def add_threat(message, level = :medium)
      @threats << message
      @safe = false
      # Don't automatically escalate risk level - let the calling code decide
      self
    end
    
    def add_warning(message)
      @warnings << message
      self
    end
    
    def set_risk_level(level)
      @risk_level = level
    end
    
    def add_detail(key, value)
      @details[key] = value
    end
    
    private
    
    def risk_level_higher?(new_level, current_level)
      levels = { low: 0, medium: 1, high: 2, critical: 3 }
      levels[new_level] > levels[current_level]
    end
  end
end