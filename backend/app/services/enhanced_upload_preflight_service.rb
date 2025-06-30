# app/services/enhanced_upload_preflight_service.rb
class EnhancedUploadPreflightService < UploadPreflightService
  # Queue-specific configuration
  MAX_FILES_PER_QUEUE = 500
  MAX_QUEUE_SIZE = 10.gigabytes
  RECOMMENDED_BATCH_SIZE = 50
  OPTIMAL_CONCURRENT_UPLOADS = 3
  
  # File type categorization for optimization
  FILE_TYPE_CATEGORIES = {
    audio: %w[mp3 wav aiff flac m4a ogg wma aac],
    project: %w[logicx als flp ptx reason cwp reapeaks rpp cpr npr],
    document: %w[pdf txt doc docx rtf md],
    image: %w[jpg jpeg png gif bmp tiff svg],
    archive: %w[zip rar 7z],
    plugin: %w[dll vst vst3 component au aax],
    executable: %w[exe msi pkg dmg app]
  }.freeze
  
  class << self
    # Enhanced preflight for queue-aware batch uploads
    def preflight_queue_batch(user:, workspace:, container:, files_info:, queue_context:)
      result = initialize_queue_result(queue_context)
      
      # Step 1: Validate queue context
      validate_queue_context!(queue_context, result)
      return result unless result[:overall_valid]
      
      # Step 2: Validate queue constraints
      queue_validation = validate_queue_constraints(queue_context.merge(
        file_count: files_info.length,
        total_size: files_info.sum { |f| f[:size] }
      ), workspace: workspace)
      
      integrate_queue_validation!(queue_validation, result)
      return result unless result[:overall_valid]
      
      # Step 3: Enhanced conflict detection within queue
      detect_queue_conflicts!(files_info, result)
      return result unless result[:overall_valid]
      
      # Step 4: Process each file with queue context
      process_queue_files!(user, workspace, container, files_info, queue_context, result)
      
      # Step 5: Calculate queue-specific optimizations (even for empty queues)
      add_queue_optimizations!(result)
      
      # Step 6: Generate upload strategies
      add_upload_strategies!(result)
      
      Rails.logger.info "🚀 Queue preflight: #{files_info.length} files, #{format_bytes(result[:total_size])}"
      result
    end
    
    # Detect queue context from file patterns and structure
    def detect_queue_context(files_info)
      context = {
        inferred_draggable_type: infer_draggable_type(files_info),
        common_path: find_common_path(files_info),
        suggested_draggable_name: suggest_draggable_name(files_info),
        file_type_distribution: analyze_file_types(files_info),
        naming_confidence: 0.0
      }
      
      # Calculate naming confidence based on pattern consistency
      context[:naming_confidence] = calculate_naming_confidence(files_info, context[:suggested_draggable_name])
      
      context
    end
    
    # Optimize upload order based on different strategies
    def optimize_upload_order(files_with_estimates, strategy: :smallest_first)
      case strategy
      when :smallest_first
        files_with_estimates.sort_by { |f| f[:size] }
      when :interleaved
        optimize_interleaved_order(files_with_estimates)
      when :audio_priority
        optimize_audio_priority_order(files_with_estimates)
      else
        files_with_estimates
      end
    end
    
    # Calculate parallel upload efficiency
    def calculate_parallel_efficiency(files_info, max_concurrent_uploads:, bandwidth_limit:)
      total_chunks = files_info.sum { |f| f[:chunks_count] }
      total_size = files_info.sum { |f| f[:size] }
      
      # Calculate optimal concurrency based on bandwidth and file characteristics
      recommended_concurrency = [
        max_concurrent_uploads,
        (bandwidth_limit / 1000).to_i, # Assume 1MB/s minimum per stream
        files_info.length
      ].min
      
      bandwidth_per_stream = bandwidth_limit / recommended_concurrency
      
      # Estimate completion time with parallel processing
      estimated_completion_time = calculate_parallel_completion_time(
        files_info, recommended_concurrency, bandwidth_per_stream
      )
      
      # Calculate efficiency score (0-1, higher is better)
      efficiency_score = calculate_efficiency_score(
        files_info, recommended_concurrency, estimated_completion_time
      )
      
      {
        recommended_concurrency: recommended_concurrency,
        bandwidth_per_stream: bandwidth_per_stream,
        estimated_completion_time: estimated_completion_time,
        efficiency_score: efficiency_score,
        total_chunks: total_chunks,
        parallel_chunk_groups: group_chunks_for_parallel(files_info, recommended_concurrency)
      }
    end
    
    # Validate queue-specific constraints
    def validate_queue_constraints(queue_context, workspace:)
      validation = {
        valid: true,
        errors: [],
        warnings: [],
        recommendations: []
      }
      
      file_count = queue_context[:file_count] || 0
      total_size = queue_context[:total_size] || 0
      
      # Check maximum files per queue
      if file_count > MAX_FILES_PER_QUEUE
        validation[:valid] = false
        validation[:errors] << "Too many files in queue (max: #{MAX_FILES_PER_QUEUE})"
      end
      
      # Check maximum queue size
      if total_size > MAX_QUEUE_SIZE
        validation[:valid] = false
        validation[:errors] << "Queue size too large (max: #{format_bytes(MAX_QUEUE_SIZE)})"
      end
      
      # Add warnings for large batches
      if file_count > 100
        validation[:warnings] << "Large batch upload detected - consider splitting into smaller batches"
      end
      
      if total_size > 2.gigabytes
        validation[:warnings] << "Large queue size may take considerable time to upload"
      end
      
      # Provide splitting recommendations
      if file_count > RECOMMENDED_BATCH_SIZE || total_size > 1.gigabyte
        validation[:recommendations] << "Consider splitting into smaller batches for better user experience"
        validation[:suggested_batch_size] = calculate_optimal_batch_size(file_count, total_size)
      end
      
      validation
    end
    
    # Enhanced single file preflight (extends parent class)
    def preflight_upload(user:, workspace:, container:, file_info:)
      result = super(user: user, workspace: workspace, container: container, file_info: file_info)
      
      # Add queue enhancement flag
      result[:queue_optimized] = false
      
      result
    end
    
    # Enhanced batch preflight (extends parent class)
    def preflight_batch(user:, workspace:, container:, files_info:)
      result = super(user: user, workspace: workspace, container: container, files_info: files_info)
      
      # Add queue enhancements to existing batch preflight
      add_queue_suggestions!(result)
      add_optimized_upload_order!(result)
      
      result
    end
    
    private
    
    def initialize_queue_result(queue_context)
      {
        overall_valid: true,
        queue_optimized: true,
        files: [],
        total_size: 0,
        total_chunks: 0,
        estimated_duration: 0,
        errors: [],
        warnings: [],
        optimization_suggestions: [],
        queue_metadata: {
          batch_id: queue_context[:batch_id],
          draggable_name: queue_context[:draggable_name],
          draggable_type: queue_context[:draggable_type],
          total_files: 0
        },
        queue_estimates: {},
        conflict_resolution: {}
      }
    end
    
    def validate_queue_context!(queue_context, result)
      # Validate required fields
      required_fields = [:batch_id, :draggable_name, :draggable_type]
      missing_fields = required_fields.select { |field| queue_context[field].blank? }
      
      if missing_fields.any?
        result[:overall_valid] = false
        result[:errors] << "Missing required queue context: #{missing_fields.join(', ')}"
        return
      end
      
      # Validate draggable_type
      valid_types = %w[file folder mixed]
      unless valid_types.include?(queue_context[:draggable_type].to_s)
        result[:overall_valid] = false
        result[:errors] << "Invalid draggable_type: #{queue_context[:draggable_type]}"
      end
    end
    
    def integrate_queue_validation!(queue_validation, result)
      unless queue_validation[:valid]
        result[:overall_valid] = false
        result[:errors].concat(queue_validation[:errors])
      end
      
      result[:warnings].concat(queue_validation[:warnings])
      result[:optimization_suggestions].concat(queue_validation[:recommendations])
    end
    
    def detect_queue_conflicts!(files_info, result)
      # Check for duplicate filenames within the queue
      filenames = files_info.map { |f| f[:filename] }
      duplicates = filenames.select { |name| filenames.count(name) > 1 }.uniq
      
      if duplicates.any?
        result[:overall_valid] = false
        result[:errors] << "Duplicate filenames detected in queue: #{duplicates.join(', ')}"
        result[:conflict_resolution][:suggested_renames] = suggest_filename_renames(duplicates, files_info)
      end
    end
    
    def process_queue_files!(user, workspace, container, files_info, queue_context, result)
      files_info.each do |file_info|
        # Add queue context to file_info for enhanced processing
        enhanced_file_info = file_info.merge(
          queue_context: queue_context,
          queue_aware: true
        )
        
        file_result = preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: enhanced_file_info
        )
        
        # Mark as queue-optimized
        file_result[:queue_optimized] = true
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
      
      result[:queue_metadata][:total_files] = files_info.length
    end
    
    def add_queue_optimizations!(result)
      valid_files = result[:files].select { |f| f[:valid] }
      
      # Handle empty valid files case - always initialize queue_estimates
      if valid_files.empty?
        result[:queue_estimates] = {
          parallel_completion_time: 0,
          sequential_completion_time: 0,
          recommended_chunk_strategy: {
            total_chunks: 0,
            parallel_chunk_groups: [],
            estimated_bandwidth_usage: 0,
            optimal_concurrent_uploads: 0
          },
          priority_order: []
        }
        return
      end
      
      # Priority ordering for optimal user experience
      priority_order = optimize_upload_order(valid_files, strategy: :smallest_first)
      
      # Parallel efficiency calculation
      parallel_efficiency = calculate_parallel_efficiency(
        valid_files,
        max_concurrent_uploads: OPTIMAL_CONCURRENT_UPLOADS,
        bandwidth_limit: 5000 # 5 MB/s default
      )
      
      result[:queue_estimates] = {
        parallel_completion_time: parallel_efficiency[:estimated_completion_time],
        sequential_completion_time: valid_files.sum { |f| f[:estimated_duration] },
        recommended_chunk_strategy: {
          total_chunks: parallel_efficiency[:total_chunks],
          parallel_chunk_groups: parallel_efficiency[:parallel_chunk_groups],
          estimated_bandwidth_usage: parallel_efficiency[:bandwidth_per_stream] * parallel_efficiency[:recommended_concurrency],
          optimal_concurrent_uploads: parallel_efficiency[:recommended_concurrency]
        },
        priority_order: priority_order
      }
      
      # Add queue-specific optimization suggestions
      result[:optimization_suggestions] << "Files will be processed in parallel for faster completion"
      result[:optimization_suggestions] << "Queue priority optimized for smaller files first"
      
      # Add strategy-specific suggestions
      if result[:queue_estimates][:parallel_completion_time] < result[:queue_estimates][:sequential_completion_time] * 0.7
        result[:optimization_suggestions] << "Parallel processing will significantly reduce upload time"
      end
      
      if valid_files.length > 10
        result[:optimization_suggestions] << "Large queue detected - parallel processing will significantly reduce completion time"
      end
    end
    
    def add_upload_strategies!(result)
      # Different upload strategies based on queue characteristics
      file_sizes = result[:files].select { |f| f[:valid] }.map { |f| f[:size] }
      
      if file_sizes.any?
        avg_size = file_sizes.sum / file_sizes.length
        max_size = file_sizes.max
        min_size = file_sizes.min
        
        if max_size > 100.megabytes && min_size < 10.megabytes
          result[:optimization_suggestions] << "Mixed file sizes detected - using interleaved upload strategy"
        elsif file_sizes.all? { |size| size < 10.megabytes }
          result[:optimization_suggestions] << "Small files detected - optimizing for rapid completion"
        elsif file_sizes.all? { |size| size > 50.megabytes }
          result[:optimization_suggestions] << "Large files detected - optimizing for bandwidth efficiency"
        end
      end
    end
    
    def infer_draggable_type(files_info)
      return 'file' if files_info.empty?
      return 'file' if files_info.length == 1
      
      # Check if files share common directory structure
      paths = files_info.map { |f| f[:path] || f[:filename] }
      common_path = find_common_path(files_info)
      
      if common_path.present? && common_path != '/'
        'folder'
      else
        file_types = analyze_file_types(files_info)
        file_types.keys.length > 2 ? 'mixed' : 'file'
      end
    end
    
    def find_common_path(files_info)
      return '/' if files_info.empty?
      
      paths = files_info.map { |f| (f[:path] || f[:filename]).split('/') }
      return '/' if paths.length == 1
      
      common_parts = paths.first
      paths.each do |path|
        common_parts = common_parts.zip(path).take_while { |a, b| a == b }.map(&:first)
      end
      
      common_path = common_parts.join('/')
      common_path.empty? ? '/' : common_path
    end
    
    def suggest_draggable_name(files_info)
      return 'Upload' if files_info.empty?
      return File.basename(files_info.first[:filename], '.*') if files_info.length == 1
      
      # Look for common naming patterns
      filenames = files_info.map { |f| f[:filename] }
      
      # Check for project files that might indicate project name
      project_files = filenames.select { |name| name.match?(/\.(logicx|als|flp|ptx|reason|cwp|rpp|cpr|npr)$/i) }
      if project_files.any?
        return File.basename(project_files.first, '.*')
      end
      
      # Look for common prefixes
      if filenames.length > 1
        common_prefix = find_common_prefix(filenames)
        return common_prefix.strip if common_prefix.length > 3
      end
      
      # Use common path directory name
      common_path = find_common_path(files_info)
      if common_path.present? && common_path != '/'
        return File.basename(common_path)
      end
      
      'Mixed Files'
    end
    
    def analyze_file_types(files_info)
      distribution = Hash.new(0)
      
      files_info.each do |file_info|
        extension = File.extname(file_info[:filename]).delete('.').downcase
        category = categorize_file_extension(extension)
        distribution[category] += 1
      end
      
      distribution
    end
    
    def categorize_file_extension(extension)
      FILE_TYPE_CATEGORIES.each do |category, extensions|
        return category.to_s if extensions.include?(extension)
      end
      'other'
    end
    
    def calculate_naming_confidence(files_info, suggested_name)
      return 0.0 if files_info.empty? || suggested_name.blank?
      
      confidence = 0.0
      
      # High confidence for project files
      project_files = files_info.select { |f| f[:filename].include?(suggested_name) }
      confidence += 0.4 if project_files.any?
      
      # Medium confidence for common prefixes
      files_with_name = files_info.select { |f| f[:filename].downcase.include?(suggested_name.downcase) }
      confidence += (files_with_name.length.to_f / files_info.length) * 0.6
      
      [confidence, 1.0].min
    end
    
    def optimize_interleaved_order(files_with_estimates)
      # Sort files by size
      sorted_files = files_with_estimates.sort_by { |f| f[:size] }
      
      return sorted_files if sorted_files.length <= 2
      
      # Separate into small and large files
      mid_point = sorted_files.length / 2
      small_files = sorted_files[0...mid_point]
      large_files = sorted_files[mid_point..-1]
      
      # Interleave: start with smallest, then largest, then second smallest, etc.
      result = []
      max_length = [small_files.length, large_files.length].max
      
      max_length.times do |i|
        result << small_files[i] if i < small_files.length
        result << large_files[-(i+1)] if i < large_files.length  # Take from end (largest first)
      end
      
      result.compact
    end
    
    def optimize_audio_priority_order(files_with_estimates)
      audio_files = []
      other_files = []
      
      files_with_estimates.each do |file|
        extension = File.extname(file[:filename]).delete('.').downcase
        if FILE_TYPE_CATEGORIES[:audio].include?(extension)
          audio_files << file
        else
          other_files << file
        end
      end
      
      # Sort audio files by size (smaller first), then append other files
      audio_files.sort_by! { |f| f[:size] }
      other_files.sort_by! { |f| f[:size] }
      
      audio_files + other_files
    end
    
    def calculate_parallel_completion_time(files_info, concurrency, bandwidth_per_stream)
      return 0 if files_info.empty?
      
      # Convert bandwidth from KB/s to bytes/s and ensure it's reasonable
      bandwidth_bytes_per_second = [bandwidth_per_stream * 1024, 1024].max # Minimum 1KB/s
      
      # Simulate parallel processing by grouping files into concurrent streams
      files_by_stream = files_info.each_slice((files_info.length.to_f / concurrency).ceil).to_a
      
      # Calculate completion time for each stream
      stream_times = files_by_stream.map do |stream_files|
        stream_files.sum { |f| f[:size].to_f / bandwidth_bytes_per_second }
      end
      
      # Return the maximum stream time (bottleneck)
      stream_times.max || 0
    end
    
    def calculate_efficiency_score(files_info, concurrency, completion_time)
      return 0 if files_info.empty? || completion_time <= 0
      
      # Calculate theoretical minimum time (if bandwidth was unlimited)
      total_size = files_info.sum { |f| f[:size] }
      theoretical_min_time = total_size.to_f / (50_000 * concurrency) # Assume 50MB/s max per stream
      
      # Efficiency is ratio of theoretical minimum to actual time
      efficiency = theoretical_min_time / completion_time
      [efficiency, 1.0].min
    end
    
    def group_chunks_for_parallel(files_info, concurrency)
      total_chunks = files_info.sum { |f| f[:chunks_count] }
      chunks_per_group = (total_chunks.to_f / concurrency).ceil
      
      groups = []
      current_group = []
      current_group_chunks = 0
      
      files_info.each do |file|
        if current_group_chunks + file[:chunks_count] <= chunks_per_group || current_group.empty?
          current_group << file
          current_group_chunks += file[:chunks_count]
        else
          groups << current_group
          current_group = [file]
          current_group_chunks = file[:chunks_count]
        end
      end
      
      groups << current_group if current_group.any?
      groups
    end
    
    def suggest_filename_renames(duplicates, files_info)
      suggestions = {}
      
      duplicates.each do |duplicate_name|
        duplicate_files = files_info.select { |f| f[:filename] == duplicate_name }
        duplicate_files.each_with_index do |file, index|
          next if index == 0 # Keep first file with original name
          
          basename = File.basename(duplicate_name, '.*')
          extension = File.extname(duplicate_name)
          suggestions[file[:path] || duplicate_name] = "#{basename}_#{index + 1}#{extension}"
        end
      end
      
      suggestions
    end
    
    def calculate_optimal_batch_size(file_count, total_size)
      # Handle edge cases
      return file_count if total_size <= 0
      
      # Base optimal size on file count and total size
      size_based_limit = if total_size > 0
                          (1.gigabyte.to_f / total_size * file_count).to_i
                        else
                          file_count
                        end
      
      count_based_limit = RECOMMENDED_BATCH_SIZE
      
      # Return the most restrictive limit, but at least 1
      [size_based_limit, count_based_limit, file_count, 1].min
    end
    
    def find_common_prefix(strings)
      return '' if strings.empty?
      return strings.first if strings.length == 1
      
      min_length = strings.map(&:length).min
      common_length = 0
      
      (0...min_length).each do |i|
        if strings.all? { |s| s[i] == strings.first[i] }
          common_length = i + 1
        else
          break
        end
      end
      
      strings.first[0, common_length]
    end
    
    def add_queue_suggestions!(result)
      result[:queue_suggestions] = []
      
      if result[:files].length > 5
        result[:queue_suggestions] << "Consider using queue processing for better organization"
      end
      
      if result[:files].length >= 2  # Lower threshold to ensure suggestions are added
        result[:queue_suggestions] << "Multiple files detected - queue processing recommended"
      end
      
      large_files = result[:files].select { |f| f[:valid] && f[:size] > 50.megabytes }
      if large_files.any?
        result[:queue_suggestions] << "Large files detected - queue processing will optimize upload order"
      end
    end
    
    def add_optimized_upload_order!(result)
      valid_files = result[:files].select { |f| f[:valid] }
      result[:optimized_upload_order] = optimize_upload_order(valid_files, strategy: :smallest_first)
    end
    
    def format_bytes(bytes)
      units = %w[B KB MB GB TB]
      size = bytes.to_f
      unit_index = 0
      
      while size >= 1024 && unit_index < units.length - 1
        size /= 1024
        unit_index += 1
      end
      
      "#{size.round(1)}#{units[unit_index]}"
    end
  end
end