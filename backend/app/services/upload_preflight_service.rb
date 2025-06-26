# app/services/upload_preflight_service.rb
class UploadPreflightService
  # File size limits
  MAX_FILE_SIZE = 5.gigabytes
  CHUNK_SIZE = 5.megabytes
  
  # Connection speed estimates (KB/s)
  CONNECTION_SPEEDS = {
    slow: 100,      # 100 KB/s (dial-up/poor mobile)
    medium: 1000,   # 1 MB/s (average broadband)
    fast: 5000,     # 5 MB/s (good broadband)
    ultra: 25000    # 25 MB/s (fiber)
  }.freeze
  
  # Storage warning thresholds
  STORAGE_WARNING_THRESHOLD = 0.85  # Warn at 85% usage
  STORAGE_CRITICAL_THRESHOLD = 0.95 # Critical at 95% usage
  
  class << self
    # Main preflight check for a single file
    def preflight_upload(user:, workspace:, container:, file_info:)
      result = {
        valid: true,
        errors: [],
        warnings: [],
        filename: file_info[:filename],
        size: file_info[:size],
        content_type: file_info[:content_type]
      }
      
      # Step 1: Basic file validation
      validate_file_basics!(file_info, result)
      return result unless result[:valid]
      
      # Step 2: Permission validation
      validate_permissions!(user, workspace, container, result)
      return result unless result[:valid]
      
      # Step 3: Storage validation
      validate_storage_constraints!(workspace, file_info[:size], result)
      return result unless result[:valid]
      
      # Step 4: Duplicate file check
      validate_no_duplicates!(workspace, container, file_info[:filename], result)
      return result unless result[:valid]
      
      # Step 5: Security preflight check
      security_result = perform_security_preflight(file_info)
      integrate_security_results!(security_result, result)
      return result unless result[:valid]
      
      # Step 6: Calculate upload estimates
      add_upload_estimates!(file_info, result)
      
      # Step 7: Generate final storage path
      result[:final_storage_path] = generate_storage_path(workspace, container, file_info[:filename])
      
      Rails.logger.info "✅ Preflight passed for #{file_info[:filename]} (#{format_bytes(file_info[:size])})"
      result
    end
    
    # Batch preflight for multiple files
    def preflight_batch(user:, workspace:, container:, files_info:)
      result = {
        overall_valid: true,
        files: [],
        total_size: 0,
        total_chunks: 0,
        estimated_duration: 0,
        errors: [],
        warnings: [],
        optimization_suggestions: []
      }
      
      # Check each file individually
      files_info.each do |file_info|
        file_result = preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: file_info
        )
        
        result[:files] << file_result
        
        if file_result[:valid]
          result[:total_size] += file_result[:size]
          result[:total_chunks] += file_result[:chunks_count]
          result[:estimated_duration] += file_result[:estimated_duration]
        else
          result[:overall_valid] = false
          result[:errors].concat(file_result[:errors].map { |e| "#{file_info[:filename]}: #{e}" })
        end
        
        result[:warnings].concat(file_result[:warnings].map { |w| "#{file_info[:filename]}: #{w}" })
      end
      
      # Batch-level validations
      validate_batch_constraints!(result, workspace)
      
      # Generate optimization suggestions
      add_optimization_suggestions!(result)
      
      Rails.logger.info "📦 Batch preflight: #{result[:files].length} files, #{format_bytes(result[:total_size])}"
      result
    end
    
    # Estimate upload time for a file
    def estimate_upload_time(file_size, connection_speed: :medium, include_processing: false)
      speed_kbps = CONNECTION_SPEEDS[connection_speed] || CONNECTION_SPEEDS[:medium]
      
      # Base upload time
      upload_time = file_size.to_f / (speed_kbps * 1024)  # Convert to seconds
      
      # Add chunk overhead (assume 200ms per chunk)
      chunks_count = calculate_chunks_count(file_size)
      chunk_overhead = chunks_count * 0.2
      
      total_time = upload_time + chunk_overhead
      
      # Add processing time if requested (assembly, virus scan, etc.)
      if include_processing
        processing_time = file_size > 100.megabytes ? 30 : 10  # seconds
        total_time += processing_time
      end
      
      total_time.round(1)
    end
    
    # Check storage availability for workspace
    def check_storage_availability(workspace, required_size)
      quota_total = workspace.respond_to?(:storage_quota) ? workspace.storage_quota : Float::INFINITY
      quota_used = workspace.respond_to?(:storage_used) ? workspace.storage_used : 0
      quota_remaining = quota_total - quota_used
      
      sufficient_space = required_size <= quota_remaining
      usage_ratio = quota_total.finite? ? quota_used.to_f / quota_total : 0
      
      status = {
        available: quota_total.finite?,
        quota_total: quota_total,
        quota_used: quota_used,
        quota_remaining: quota_remaining,
        sufficient_space: sufficient_space,
        usage_ratio: usage_ratio,
        warnings: []
      }
      
      # Add warnings based on usage
      if quota_total.finite?
        if usage_ratio >= STORAGE_CRITICAL_THRESHOLD
          status[:warnings] << 'Storage critically full (>95%)'
        elsif usage_ratio >= STORAGE_WARNING_THRESHOLD
          status[:warnings] << 'Approaching storage limit (>85%)'
        elsif quota_remaining < required_size * 2
          status[:warnings] << 'Limited storage space remaining'
        end
      end
      
      status
    end
    
    private
    
    def validate_file_basics!(file_info, result)
      # File size validation
      if file_info[:size] <= 0
        result[:errors] << 'File size must be greater than 0'
        result[:valid] = false
      elsif file_info[:size] > MAX_FILE_SIZE
        result[:errors] << "File size too large (max: #{format_bytes(MAX_FILE_SIZE)})"
        result[:valid] = false
      end
      
      # Filename validation
      if file_info[:filename].blank?
        result[:errors] << 'Filename cannot be empty'
        result[:valid] = false
      elsif file_info[:filename].length > 255
        result[:errors] << 'Filename too long (max: 255 characters)'
        result[:valid] = false
      end
      
      # Basic file type validation
      extension = extract_extension(file_info[:filename])
      unless allowed_file_extension?(extension)
        result[:errors] << 'File type not allowed'
        result[:valid] = false
      end
    end
    
    def validate_permissions!(user, workspace, container, result)
      # Check workspace access
      unless user_can_upload_to_workspace?(user, workspace)
        result[:errors] << 'Permission denied: cannot upload to this workspace'
        result[:valid] = false
        return
      end
      
      # Check container access if specified
      if container && !user_can_upload_to_container?(user, container)
        result[:errors] << 'Permission denied: cannot upload to this container'
        result[:valid] = false
      end
    end
    
    def validate_storage_constraints!(workspace, file_size, result)
      storage_status = check_storage_availability(workspace, file_size)
      
      unless storage_status[:sufficient_space]
        result[:errors] << 'Storage quota exceeded'
        result[:valid] = false
        return
      end
      
      # Add storage warnings
      result[:warnings].concat(storage_status[:warnings])
      result[:storage_required] = file_size
    end
    
    def validate_no_duplicates!(workspace, container, filename, result)
      # Check for existing files with same name in same location
      existing = UploadSession.where(
        workspace: workspace,
        container: container,
        filename: filename,
        status: ['completed', 'finalizing', 'virus_scanning']
      ).exists?
      
      if existing
        result[:errors] << 'File already exists in this location'
        result[:valid] = false
      end
    end
    
    def perform_security_preflight(file_info)
      return { safe: true, risk_level: 'low', threats: [], warnings: [] } unless defined?(MaliciousFileDetectionService)
      
      begin
        detector = MaliciousFileDetectionService.new
        scan_result = detector.scan_file(file_info[:filename], file_info[:content_type])
        
        {
          safe: scan_result.safe?,
          blocked: scan_result.blocked?,
          risk_level: scan_result.risk_level.to_s,
          threats: scan_result.threats,
          warnings: scan_result.warnings
        }
      rescue => e
        Rails.logger.error "Security preflight failed: #{e.message}"
        { safe: true, risk_level: 'unknown', threats: [], warnings: ['Security check failed'] }
      end
    end
    
    def integrate_security_results!(security_result, result)
      result[:security_risk] = security_result[:risk_level] || 'low'
      
      if security_result[:blocked]
        result[:errors] << 'File blocked due to security risk'
        result[:valid] = false
      elsif !security_result[:safe]
        case security_result[:risk_level]
        when 'high', 'critical'
          result[:errors] << 'File blocked due to high security risk'
          result[:valid] = false
        when 'medium'
          result[:warnings] << 'Security warning: file requires verification'
        end
      end
      
      result[:security_threats] = security_result[:threats] if security_result[:threats].any?
    end
    
    def add_upload_estimates!(file_info, result)
      result[:chunks_count] = calculate_chunks_count(file_info[:size])
      result[:estimated_duration] = estimate_upload_time(
        file_info[:size],
        connection_speed: :medium,
        include_processing: true
      )
    end
    
    def validate_batch_constraints!(result, workspace)
      # Check if batch would exceed storage
      storage_status = check_storage_availability(workspace, result[:total_size])
      
      unless storage_status[:sufficient_space]
        result[:overall_valid] = false
        result[:errors] << 'Batch upload would exceed storage quota'
      end
      
      # Warn about very large batches
      if result[:total_size] > 1.gigabyte
        result[:warnings] << 'Large batch upload detected - consider uploading in smaller groups'
      end
      
      if result[:files].length > 50
        result[:warnings] << 'Many files detected - upload may take considerable time'
      end
    end
    
    def add_optimization_suggestions!(result)
      suggestions = []
      
      # Suggest compression for large uncompressed audio
      large_uncompressed = result[:files].select do |f|
        f[:valid] && f[:size] > 50.megabytes && 
        extract_extension(f[:filename]) == 'wav'
      end
      
      if large_uncompressed.any?
        suggestions << 'Consider compressing large WAV files to reduce upload time'
      end
      
      # Suggest chunked parallel upload for many files
      if result[:files].length > 10
        suggestions << 'Files will be uploaded in parallel for faster completion'
      end
      
      # Suggest off-peak uploads for very large batches
      if result[:total_size] > 2.gigabytes
        suggestions << 'Consider uploading during off-peak hours for better performance'
      end
      
      result[:optimization_suggestions] = suggestions
    end
    
    def generate_storage_path(workspace, container, filename)
      if container
        "#{workspace.name}/#{container.name}/#{filename}"
      else
        "#{workspace.name}/#{filename}"
      end
    end
    
    def calculate_chunks_count(file_size)
      (file_size.to_f / CHUNK_SIZE).ceil
    end
    
    def extract_extension(filename)
      File.extname(filename).delete('.').downcase
    end
    
    def allowed_file_extension?(extension)
      # Define allowed extensions for musicians
      allowed_extensions = %w[
        mp3 wav aiff flac m4a ogg wma aac
        logicx als flp ptx reason cwp reapeaks rpp cpr npr
        pdf txt doc docx rtf md
        jpg jpeg png gif bmp tiff svg
        zip rar 7z
        dll vst vst3 component au aax
        exe msi pkg dmg app
      ]
      
      allowed_extensions.include?(extension)
    end
    
    def user_can_upload_to_workspace?(user, workspace)
      # Owner can always upload
      return true if workspace.user_id == user.id
      
      # Check for collaborator role (handle polymorphic association carefully)
      user.roles.where(roleable_type: 'Workspace', roleable_id: workspace.id, name: 'collaborator').exists?
    end
    
    def user_can_upload_to_container?(user, container)
      # If user can upload to workspace, they can upload to containers within it
      user_can_upload_to_workspace?(user, container.workspace)
    end
    
    def format_bytes(bytes)
      if bytes >= 1.gigabyte
        "#{(bytes.to_f / 1.gigabyte).round(1)} GB"
      elsif bytes >= 1.megabyte
        "#{(bytes.to_f / 1.megabyte).round(1)} MB"
      else
        "#{(bytes.to_f / 1.kilobyte).round(1)} KB"
      end
    end
  end
end