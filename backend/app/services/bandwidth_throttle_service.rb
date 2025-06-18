class BandwidthThrottleService
  attr_reader :bandwidth_limit_kbps
  
  # Minimum bandwidth limit to prevent extremely slow uploads
  MINIMUM_BANDWIDTH_KBPS = 50
  
  # Default bandwidth limit (1 MB/s)
  DEFAULT_BANDWIDTH_KBPS = 1000
  
  def initialize(bandwidth_limit_kbps: nil, bandwidth_limit_mbps: nil)
    if bandwidth_limit_mbps
      @bandwidth_limit_kbps = (bandwidth_limit_mbps * 1000).to_i
    elsif bandwidth_limit_kbps
      @bandwidth_limit_kbps = bandwidth_limit_kbps.to_i
    else
      @bandwidth_limit_kbps = DEFAULT_BANDWIDTH_KBPS
    end
    
    validate_bandwidth_limit!
    
    # Statistics tracking
    @upload_history = []
    @statistics_mutex = Mutex.new
  end
  
  def unlimited?
    @bandwidth_limit_kbps == 0
  end
  
  # Calculate delay needed for given data size to respect bandwidth limit
  def calculate_delay(data_size_kb)
    return 0 if unlimited?
    return 0 if data_size_kb <= 0
    
    # Calculate time needed: size (KB) / speed (KB/s) = time (seconds)
    data_size_kb.to_f / @bandwidth_limit_kbps
  end
  
  # Throttle a single upload operation
  def throttle_upload(chunk_data, &upload_block)
    data_size_kb = (chunk_data[:size] || 0) / 1024.0
    delay_seconds = calculate_delay(data_size_kb)
    
    start_time = Time.current
    
    # Apply throttling delay before upload
    if delay_seconds > 0
      Rails.logger.debug "🕐 Throttling upload: #{data_size_kb.round(2)} KB, delay: #{delay_seconds.round(3)}s"
      sleep(delay_seconds)
    end
    
    # Execute the upload
    result = upload_block.call(chunk_data)
    
    end_time = Time.current
    actual_duration = end_time - start_time
    
    # Record upload statistics
    record_upload(chunk_data[:size] || 0, actual_duration)
    
    result
  rescue => e
    # Still record the attempt even if it failed
    end_time = Time.current
    actual_duration = end_time - start_time
    record_upload(chunk_data[:size] || 0, actual_duration, success: false)
    
    raise e
  end
  
  # Throttle multiple uploads in parallel with bandwidth distribution
  def throttle_parallel_uploads(chunk_data_list, max_concurrent: 3, &upload_block)
    return [] if chunk_data_list.empty?
    
    # Calculate per-upload bandwidth allocation
    per_upload_bandwidth = calculate_per_upload_bandwidth(max_concurrent)
    
    # Create a throttle service for each upload with allocated bandwidth
    individual_throttle_service = BandwidthThrottleService.new(bandwidth_limit_kbps: per_upload_bandwidth)
    
    results = []
    results_mutex = Mutex.new
    
    # Process chunks in batches based on concurrency limit
    chunk_data_list.each_slice(max_concurrent) do |chunk_batch|
      threads = []
      
      chunk_batch.each do |chunk_data|
        threads << Thread.new do
          begin
            # Apply throttling to individual upload
            result = individual_throttle_service.throttle_upload(chunk_data, &upload_block)
            
            results_mutex.synchronize do
              results << result
            end
          rescue => e
            results_mutex.synchronize do
              results << {
                success: false,
                chunk_number: chunk_data[:chunk_number],
                error: "Throttled upload failed: #{e.message}"
              }
            end
          end
        end
      end
      
      # Wait for all threads in this batch to complete
      threads.each(&:join)
    end
    
    results
  end
  
  # Calculate bandwidth allocation per upload for parallel uploads
  def calculate_per_upload_bandwidth(concurrent_uploads)
    return 0 if unlimited?
    return @bandwidth_limit_kbps if concurrent_uploads <= 1
    
    # Divide total bandwidth among concurrent uploads
    (@bandwidth_limit_kbps.to_f / concurrent_uploads).to_i
  end
  
  # Measure actual upload speed from completed upload
  def measure_upload_speed(data_size_kb, duration_seconds)
    return 0 if duration_seconds <= 0
    
    data_size_kb.to_f / duration_seconds
  end
  
  # Adapt bandwidth limit based on measured network performance
  def adapt_bandwidth_limit(measured_speed_kbps)
    return if unlimited?
    
    current_limit = @bandwidth_limit_kbps
    
    if measured_speed_kbps > current_limit
      # Network can handle more - increase limit conservatively (80% of measured)
      new_limit = (measured_speed_kbps * 0.8).to_i
      @bandwidth_limit_kbps = new_limit
      Rails.logger.info "📈 Bandwidth limit increased: #{current_limit} -> #{new_limit} KB/s"
      
    elsif measured_speed_kbps < current_limit
      # Network is slower than expected - decrease limit
      new_limit = [measured_speed_kbps.to_i, MINIMUM_BANDWIDTH_KBPS].max
      @bandwidth_limit_kbps = new_limit
      Rails.logger.info "📉 Bandwidth limit decreased: #{current_limit} -> #{new_limit} KB/s"
    end
  end
  
  # Record upload statistics for analysis
  def record_upload(bytes_uploaded, duration_seconds, success: true, timestamp: nil)
    @statistics_mutex.synchronize do
      @upload_history << {
        bytes: bytes_uploaded,
        duration: duration_seconds,
        success: success,
        timestamp: timestamp || Time.current,
        speed_kbps: duration_seconds > 0 ? (bytes_uploaded / 1024.0) / duration_seconds : 0
      }
      
      # Keep only recent history (last 1000 uploads or 24 hours)
      cutoff_time = 24.hours.ago
      @upload_history = @upload_history.last(1000).select { |upload| upload[:timestamp] > cutoff_time }
    end
  end
  
  # Get bandwidth usage statistics
  def bandwidth_statistics(window: nil)
    @statistics_mutex.synchronize do
      # Filter by time window if specified
      history = if window
        cutoff_time = window.seconds.ago
        @upload_history.select { |upload| upload[:timestamp] > cutoff_time }
      else
        @upload_history
      end
      
      return empty_statistics if history.empty?
      
      total_bytes = history.sum { |upload| upload[:bytes] }
      total_time = history.sum { |upload| upload[:duration] }
      successful_uploads = history.count { |upload| upload[:success] }
      
      average_speed = total_time > 0 ? (total_bytes / 1024.0) / total_time : 0
      theoretical_max_speed = @bandwidth_limit_kbps
      efficiency = if theoretical_max_speed > 0 && !unlimited?
        [(average_speed / theoretical_max_speed * 100).round(2), 100.0].min
      else
        100.0
      end
      
      {
        total_bytes_uploaded: total_bytes,
        total_upload_time: total_time.round(3),
        average_speed_kbps: average_speed.round(2),
        theoretical_speed_kbps: theoretical_max_speed,
        efficiency_percentage: efficiency,
        successful_uploads: successful_uploads,
        total_uploads: history.length,
        success_rate: history.length > 0 ? (successful_uploads.to_f / history.length * 100).round(2) : 0,
        window_description: window ? "Last #{window / 60} minutes" : "All time"
      }
    end
  end
  
  # Auto-adapt bandwidth based on recent performance
  def auto_adapt_bandwidth(sample_size: 10)
    return if unlimited?
    
    @statistics_mutex.synchronize do
      recent_uploads = @upload_history.last(sample_size).select { |upload| upload[:success] }
      return if recent_uploads.empty?
      
      # Calculate average measured speed from recent successful uploads
      average_measured_speed = recent_uploads.sum { |upload| upload[:speed_kbps] } / recent_uploads.length
      
      # Only adapt if we have enough samples and the difference is significant
      if recent_uploads.length >= 5 && (average_measured_speed - @bandwidth_limit_kbps).abs > (@bandwidth_limit_kbps * 0.2)
        adapt_bandwidth_limit(average_measured_speed)
      end
    end
  end
  
  # Get current bandwidth utilization
  def current_utilization
    stats = bandwidth_statistics(window: 5.minutes)
    return 0 if stats[:total_uploads] == 0
    
    stats[:efficiency_percentage]
  end
  
  # Check if bandwidth limit should be adjusted based on utilization
  def bandwidth_health_check
    utilization = current_utilization
    
    case utilization
    when 0..20
      { status: :underutilized, message: "Bandwidth underutilized (#{utilization}%). Consider increasing limit." }
    when 21..85
      { status: :optimal, message: "Bandwidth utilization optimal (#{utilization}%)." }
    when 86..100
      { status: :overutilized, message: "Bandwidth overutilized (#{utilization}%). Consider decreasing limit." }
    else
      { status: :unknown, message: "Unable to determine bandwidth utilization." }
    end
  end
  
  private
  
  def validate_bandwidth_limit!
    if @bandwidth_limit_kbps < 0
      raise ArgumentError, 'Bandwidth limit must be positive (use 0 for unlimited)'
    end
  end
  
  def empty_statistics
    {
      total_bytes_uploaded: 0,
      total_upload_time: 0,
      average_speed_kbps: 0,
      theoretical_speed_kbps: @bandwidth_limit_kbps,
      efficiency_percentage: 0,
      successful_uploads: 0,
      total_uploads: 0,
      success_rate: 0,
      window_description: "No data"
    }
  end
end