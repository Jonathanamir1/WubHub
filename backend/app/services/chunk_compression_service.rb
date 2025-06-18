# app/services/chunk_compression_service.rb
require 'zlib'
require 'stringio'

class ChunkCompressionService
  # Custom exceptions
  class CompressionError < StandardError; end
  class DecompressionError < StandardError; end
  
  # Supported compression algorithms
  SUPPORTED_ALGORITHMS = [:gzip, :lz4].freeze
  
  # File types that are already compressed and shouldn't be compressed again
  SKIP_COMPRESSION_TYPES = [
    'audio/mp3', 'audio/mpeg', 'audio/aac', 'audio/ogg', 'audio/m4a',
    'image/jpeg', 'image/png', 'image/webp',
    'video/mp4', 'video/webm', 'video/avi',
    'application/zip', 'application/gzip', 'application/x-rar'
  ].freeze
  
  # Minimum chunk size to consider for compression (bytes)
  MIN_COMPRESSION_SIZE = 512
  
  # Entropy threshold - data above this entropy probably won't compress well
  ENTROPY_THRESHOLD = 7.5 # out of 8.0 max entropy
  
  attr_accessor :compression_algorithm, :compression_level
  
  def initialize(algorithm: :gzip, level: 6)
    validate_algorithm!(algorithm)
    validate_level!(level)
    
    @compression_algorithm = algorithm
    @compression_level = level
    @performance_history = []
    @settings_mutex = Mutex.new
  end
  
  # Compress a single chunk
  def compress_chunk(chunk_info)
    validate_chunk_data!(chunk_info)
    
    original_data = chunk_info[:data]
    original_size = chunk_info[:size] || original_data.bytesize
    
    # Handle empty data
    if original_data.nil? || original_data.empty?
      return build_empty_compression_result(chunk_info)
    end
    
    start_time = Time.current
    
    begin
      compressed_data = case @compression_algorithm
                       when :gzip
                         compress_with_gzip(original_data)
                       when :lz4
                         compress_with_lz4(original_data)
                       else
                         raise CompressionError, "Unsupported algorithm: #{@compression_algorithm}"
                       end
      
      end_time = Time.current
      compression_time = end_time - start_time
      
      compressed_size = compressed_data.bytesize
      compression_ratio = calculate_compression_ratio(original_size, compressed_size)
      
      # Record performance for adaptive optimization
      record_performance(compression_time, compression_ratio, original_size)
      
      Rails.logger.debug "🗜️ Compressed chunk #{chunk_info[:chunk_number]}: #{original_size} -> #{compressed_size} bytes (#{(compression_ratio * 100).round(1)}% saved)"
      
      {
        chunk_number: chunk_info[:chunk_number],
        compressed_data: compressed_data,
        compressed_size: compressed_size,
        original_size: original_size,
        original_checksum: chunk_info[:checksum],
        compression_ratio: compression_ratio,
        algorithm_used: @compression_algorithm,
        compression_metadata: {
          compressed_at: Time.current.iso8601,
          algorithm: @compression_algorithm,
          level: @compression_level,
          compression_time: compression_time.round(4)
        }
      }
      
    rescue => e
      Rails.logger.error "❌ Compression failed for chunk #{chunk_info[:chunk_number]}: #{e.message}"
      raise CompressionError, "Failed to compress chunk: #{e.message}"
    end
  end
  
  # Decompress a chunk back to original data
  def decompress_chunk(compressed_info)
    algorithm = compressed_info[:algorithm_used] || compressed_info.dig(:compression_metadata, :algorithm)
    compressed_data = compressed_info[:compressed_data]
    
    raise DecompressionError, "Missing compression algorithm" unless algorithm
    raise DecompressionError, "Missing compressed data" unless compressed_data
    
    start_time = Time.current
    
    begin
      original_data = case algorithm.to_sym
                     when :gzip
                       decompress_with_gzip(compressed_data)
                     when :lz4
                       decompress_with_lz4(compressed_data)
                     else
                       raise DecompressionError, "Unsupported decompression algorithm: #{algorithm}"
                     end
      
      end_time = Time.current
      decompression_time = end_time - start_time
      
      Rails.logger.debug "📂 Decompressed chunk #{compressed_info[:chunk_number]}: #{compressed_data.bytesize} -> #{original_data.bytesize} bytes"
      
      {
        chunk_number: compressed_info[:chunk_number],
        data: original_data,
        size: original_data.bytesize,
        checksum: compressed_info[:original_checksum],
        decompression_metadata: {
          decompressed_at: Time.current.iso8601,
          algorithm_used: algorithm,
          decompression_time: decompression_time.round(4)
        }
      }
      
    rescue => e
      Rails.logger.error "❌ Decompression failed for chunk #{compressed_info[:chunk_number]}: #{e.message}"
      raise DecompressionError, "Failed to decompress chunk: #{e.message}"
    end
  end
  
  # Determine if a chunk should be compressed
  def should_compress?(chunk_info)
    data = chunk_info[:data]
    size = chunk_info[:size] || data&.bytesize || 0
    file_type = chunk_info[:file_type]
    
    # Skip if data is too small
    return false if size < MIN_COMPRESSION_SIZE
    
    # Skip if file type is already compressed
    return false if file_type && SKIP_COMPRESSION_TYPES.include?(file_type.downcase)
    
    # Skip if data appears to be already compressed (high entropy)
    return false if data && calculate_entropy(data) > ENTROPY_THRESHOLD
    
    # Skip if data is nil or empty
    return false if data.nil? || data.empty?
    
    true
  end
  
  # Compress a list of chunks, applying compression selectively
  def compress_chunk_list(chunk_list)
    return empty_compression_result if chunk_list.empty?
    
    start_time = Time.current
    compressed_chunks = []
    uncompressed_chunks = []
    total_original_size = 0
    total_compressed_size = 0
    
    chunk_list.each do |chunk_info|
      total_original_size += (chunk_info[:size] || 0)
      
      if should_compress?(chunk_info)
        begin
          compressed = compress_chunk(chunk_info)
          compressed_chunks << compressed
          total_compressed_size += compressed[:compressed_size]
        rescue CompressionError => e
          Rails.logger.warn "⚠️ Compression failed for chunk #{chunk_info[:chunk_number]}, using uncompressed: #{e.message}"
          uncompressed_chunks << chunk_info
          total_compressed_size += (chunk_info[:size] || 0)
        end
      else
        uncompressed_chunks << chunk_info
        total_compressed_size += (chunk_info[:size] || 0)
      end
    end
    
    end_time = Time.current
    processing_time = end_time - start_time
    
    overall_compression_ratio = if total_original_size > 0
      (total_original_size - total_compressed_size).to_f / total_original_size
    else
      0.0
    end
    
    Rails.logger.info "📊 Batch compression complete: #{compressed_chunks.length}/#{chunk_list.length} chunks compressed, #{(overall_compression_ratio * 100).round(1)}% overall savings"
    
    {
      compressed_chunks: compressed_chunks,
      uncompressed_chunks: uncompressed_chunks,
      compression_stats: {
        total_chunks: chunk_list.length,
        compressed_chunks: compressed_chunks.length,
        uncompressed_chunks: uncompressed_chunks.length,
        compression_ratio: overall_compression_ratio,
        bytes_saved: total_original_size - total_compressed_size,
        original_size: total_original_size,
        final_size: total_compressed_size,
        processing_time: processing_time.round(3)
      }
    }
  end
  
  # Adapt compression settings based on performance feedback
  def adapt_compression_settings(performance_info)
    @settings_mutex.synchronize do
      compression_time = performance_info[:compression_time]
      compression_ratio = performance_info[:compression_ratio]
      chunk_size = performance_info[:chunk_size]
      
      # Calculate compression speed (KB/s)
      compression_speed = chunk_size > 0 ? (chunk_size / 1024.0) / compression_time : 0
      
      case
      when compression_time > 1.0 && compression_ratio < 0.2
        # Slow compression with poor ratio - reduce level or switch algorithm
        if @compression_level > 1
          @compression_level -= 1
          Rails.logger.info "🔧 Reduced compression level to #{@compression_level} (slow with poor ratio)"
        elsif @compression_algorithm == :gzip
          @compression_algorithm = :lz4
          @compression_level = 1
          Rails.logger.info "🔧 Switched to LZ4 compression (GZIP too slow)"
        end
        
      when compression_time < 0.1 && compression_ratio < 0.3
        # Fast compression but poor ratio - increase level for better compression
        if @compression_level < 9
          @compression_level += 1
          Rails.logger.info "🔧 Increased compression level to #{@compression_level} (fast but poor ratio)"
        end
        
      when compression_time > 2.0
        # Very slow compression - switch to faster algorithm
        if @compression_algorithm == :gzip
          @compression_algorithm = :lz4
          @compression_level = 1
          Rails.logger.info "🔧 Switched to LZ4 compression (GZIP too slow)"
        end
      end
      
      # Ensure we stay within valid ranges
      @compression_level = [@compression_level, 1].max
      @compression_level = [@compression_level, 9].min
    end
  end
  
  private
  
  def validate_algorithm!(algorithm)
    unless SUPPORTED_ALGORITHMS.include?(algorithm)
      raise ArgumentError, "Unsupported compression algorithm: #{algorithm}. Supported: #{SUPPORTED_ALGORITHMS.join(', ')}"
    end
  end
  
  def validate_level!(level)
    unless (1..9).include?(level)
      raise ArgumentError, "Compression level must be between 1-9, got: #{level}"
    end
  end
  
  def validate_chunk_data!(chunk_info)
    raise CompressionError, "Invalid chunk data: chunk_info cannot be nil" if chunk_info.nil?
    raise CompressionError, "Invalid chunk data: missing chunk_number" unless chunk_info.key?(:chunk_number)
    raise CompressionError, "Invalid chunk data: missing data field" unless chunk_info.key?(:data)
    raise CompressionError, "Invalid chunk data: data cannot be nil" if chunk_info[:data].nil?
  end
  
  def compress_with_gzip(data)
    Zlib::Deflate.deflate(data, @compression_level)
  end
  
  def decompress_with_gzip(compressed_data)
    Zlib::Inflate.inflate(compressed_data)
  end
  
  def compress_with_lz4(data)
    # LZ4 implementation - for now, fallback to gzip
    # In production, you would use the lz4-ruby gem
    Rails.logger.debug "🔄 LZ4 not implemented, falling back to GZIP"
    compress_with_gzip(data)
  end
  
  def decompress_with_lz4(compressed_data)
    # LZ4 implementation - for now, fallback to gzip
    Rails.logger.debug "🔄 LZ4 not implemented, falling back to GZIP"
    decompress_with_gzip(compressed_data)
  end
  
  def calculate_compression_ratio(original_size, compressed_size)
    return 0.0 if original_size <= 0
    
    savings = original_size - compressed_size
    ratio = savings.to_f / original_size
    
    # Ensure ratio is never negative (compressed data can be larger than original)
    [ratio, 0.0].max
  end
  
  def calculate_entropy(data)
    return 0.0 if data.empty?
    
    # Calculate Shannon entropy to detect already compressed data
    frequency = Hash.new(0)
    data.each_byte { |byte| frequency[byte] += 1 }
    
    entropy = 0.0
    data_length = data.bytesize.to_f
    
    frequency.each_value do |count|
      probability = count / data_length
      entropy -= probability * Math.log2(probability) if probability > 0
    end
    
    entropy
  end
  
  def record_performance(compression_time, compression_ratio, chunk_size)
    @performance_history << {
      timestamp: Time.current,
      compression_time: compression_time,
      compression_ratio: compression_ratio,
      chunk_size: chunk_size,
      algorithm: @compression_algorithm,
      level: @compression_level
    }
    
    # Keep only recent history
    @performance_history = @performance_history.last(100)
  end
  
  def build_empty_compression_result(chunk_info)
    {
      chunk_number: chunk_info[:chunk_number],
      compressed_data: '',
      compressed_size: 0,
      original_size: 0,
      original_checksum: chunk_info[:checksum],
      compression_ratio: 0.0,
      algorithm_used: @compression_algorithm,
      compression_metadata: {
        compressed_at: Time.current.iso8601,
        algorithm: @compression_algorithm,
        level: @compression_level,
        compression_time: 0.0
      }
    }
  end
  
  def empty_compression_result
    {
      compressed_chunks: [],
      uncompressed_chunks: [],
      compression_stats: {
        total_chunks: 0,
        compressed_chunks: 0,
        uncompressed_chunks: 0,
        compression_ratio: 0.0,
        bytes_saved: 0,
        original_size: 0,
        final_size: 0,
        processing_time: 0.0
      }
    }
  end
end