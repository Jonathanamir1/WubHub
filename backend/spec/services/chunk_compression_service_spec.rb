# spec/services/chunk_compression_service_spec.rb
require 'rails_helper'

RSpec.describe ChunkCompressionService, type: :service do
  let(:service) { ChunkCompressionService.new }

  describe '#initialize' do
    it 'sets default compression algorithm' do
      expect(service.compression_algorithm).to eq(:gzip)
    end

    it 'allows custom compression algorithm' do
      lz4_service = ChunkCompressionService.new(algorithm: :lz4)
      expect(lz4_service.compression_algorithm).to eq(:lz4)
    end

    it 'sets default compression level' do
      expect(service.compression_level).to eq(6) # Balanced compression
    end

    it 'allows custom compression level' do
      high_compression_service = ChunkCompressionService.new(level: 9)
      expect(high_compression_service.compression_level).to eq(9)
    end

    it 'validates compression algorithm' do
      expect {
        ChunkCompressionService.new(algorithm: :invalid_algorithm)
      }.to raise_error(ArgumentError, /Unsupported compression algorithm/)
    end

    it 'validates compression level' do
      expect {
        ChunkCompressionService.new(level: 15)
      }.to raise_error(ArgumentError, /Compression level must be between/)
    end
  end

  describe '#compress_chunk' do
    let(:test_data) { 'This is test data that should compress well. ' * 100 } # Repeating text compresses well
    let(:chunk_info) do
      {
        chunk_number: 1,
        data: test_data,
        size: test_data.bytesize,
        checksum: 'original_checksum'
      }
    end

    it 'compresses chunk data successfully' do
      result = service.compress_chunk(chunk_info)
      
      expect(result).to have_key(:compressed_data)
      expect(result).to have_key(:compressed_size)
      expect(result).to have_key(:original_size)
      expect(result).to have_key(:compression_ratio)
      expect(result).to have_key(:algorithm_used)
      
      expect(result[:compressed_size]).to be < result[:original_size]
      expect(result[:compression_ratio]).to be > 0
      expect(result[:algorithm_used]).to eq(:gzip)
    end

    it 'maintains chunk metadata in compressed result' do
      result = service.compress_chunk(chunk_info)
      
      expect(result[:chunk_number]).to eq(1)
      expect(result[:original_checksum]).to eq('original_checksum')
      expect(result[:original_size]).to eq(test_data.bytesize)
    end

    it 'calculates compression ratio correctly' do
      result = service.compress_chunk(chunk_info)
      
      expected_ratio = (result[:original_size] - result[:compressed_size]).to_f / result[:original_size]
      expect(result[:compression_ratio]).to be_within(0.01).of(expected_ratio)
    end

    it 'handles already compressed data gracefully' do
      # Use random data that won't compress well
      random_data = SecureRandom.random_bytes(1024)
      random_chunk = {
        chunk_number: 1,
        data: random_data,
        size: random_data.bytesize,
        checksum: 'random_checksum'
      }
      
      result = service.compress_chunk(random_chunk)
      
      expect(result[:compressed_size]).to be >= (result[:original_size] * 0.8) # Should not expand much
      expect(result[:compression_ratio]).to be >= 0 # Should not be negative (now enforced)
      expect(result[:compression_ratio]).to be <= 0.2 # Should have poor compression ratio for random data
    end

    it 'includes compression metadata' do
      result = service.compress_chunk(chunk_info)
      
      expect(result[:compression_metadata]).to be_a(Hash)
      expect(result[:compression_metadata][:compressed_at]).to be_present
      expect(result[:compression_metadata][:algorithm]).to eq(:gzip)
      expect(result[:compression_metadata][:level]).to eq(6)
    end
  end

  describe '#decompress_chunk' do
    let(:test_data) { 'This is test data for decompression testing. ' * 50 }
    let(:compressed_result) do
      chunk_info = {
        chunk_number: 1,
        data: test_data,
        size: test_data.bytesize,
        checksum: 'test_checksum'
      }
      service.compress_chunk(chunk_info)
    end

    it 'decompresses chunk data back to original' do
      decompressed = service.decompress_chunk(compressed_result)
      
      expect(decompressed[:data]).to eq(test_data)
      expect(decompressed[:size]).to eq(test_data.bytesize)
      expect(decompressed[:chunk_number]).to eq(1)
      expect(decompressed[:checksum]).to eq('test_checksum')
    end

    it 'validates compressed data integrity' do
      # Corrupt the compressed data
      corrupted_result = compressed_result.dup
      corrupted_result[:compressed_data] = corrupted_result[:compressed_data][0..-10] # Remove end bytes
      
      expect {
        service.decompress_chunk(corrupted_result)
      }.to raise_error(ChunkCompressionService::DecompressionError)
    end

    it 'handles different compression algorithms' do
      lz4_service = ChunkCompressionService.new(algorithm: :lz4)
      
      chunk_info = {
        chunk_number: 1,
        data: test_data,
        size: test_data.bytesize,
        checksum: 'test_checksum'
      }
      
      compressed = lz4_service.compress_chunk(chunk_info)
      decompressed = lz4_service.decompress_chunk(compressed)
      
      expect(decompressed[:data]).to eq(test_data)
    end

    it 'includes decompression metadata' do
      decompressed = service.decompress_chunk(compressed_result)
      
      expect(decompressed[:decompression_metadata]).to be_a(Hash)
      expect(decompressed[:decompression_metadata][:decompressed_at]).to be_present
      expect(decompressed[:decompression_metadata][:algorithm_used]).to eq(:gzip)
    end
  end

  describe '#should_compress?' do
    it 'recommends compression for text-like data' do
      text_data = 'This is text data that repeats. ' * 100
      chunk_info = { data: text_data, size: text_data.bytesize }
      
      expect(service.should_compress?(chunk_info)).to be true
    end

    it 'skips compression for already compressed data' do
      # Simulate already compressed data (high entropy)
      compressed_data = SecureRandom.random_bytes(1024)
      chunk_info = { data: compressed_data, size: compressed_data.bytesize }
      
      expect(service.should_compress?(chunk_info)).to be false
    end

    it 'skips compression for very small chunks' do
      small_data = 'small'
      chunk_info = { data: small_data, size: small_data.bytesize }
      
      expect(service.should_compress?(chunk_info)).to be false
    end

    it 'considers file type hints when available' do
      # Simulate audio file chunk (already compressed format)
      audio_chunk = {
        data: SecureRandom.random_bytes(10000),
        size: 10000,
        file_type: 'audio/mp3'
      }
      
      expect(service.should_compress?(audio_chunk)).to be false
    end

    it 'recommends compression for project files' do
      # Simulate project file chunk (text-based, compressible)
      project_chunk = {
        data: '{"tracks": [{"name": "Track 1"}]}' * 100,
        size: 3400,
        file_type: 'application/json'
      }
      
      expect(service.should_compress?(project_chunk)).to be true
    end
  end

  describe '#compress_chunk_list' do
    let(:chunk_list) do
      [
        {
          chunk_number: 1,
          data: 'Compressible text data. ' * 100,
          size: 2400,
          checksum: 'checksum1'
        },
        {
          chunk_number: 2,
          data: SecureRandom.random_bytes(1000), # Won't compress well
          size: 1000,
          checksum: 'checksum2'
        },
        {
          chunk_number: 3,
          data: 'More compressible text. ' * 80,
          size: 1920,
          checksum: 'checksum3'
        }
      ]
    end

    it 'compresses suitable chunks and skips others' do
      result = service.compress_chunk_list(chunk_list)
      
      expect(result).to have_key(:compressed_chunks)
      expect(result).to have_key(:uncompressed_chunks)
      expect(result).to have_key(:compression_stats)
      
      # Should compress chunks 1 and 3 (text), skip chunk 2 (random)
      expect(result[:compressed_chunks].length).to be >= 2
      expect(result[:uncompressed_chunks].length).to be >= 1
    end

    it 'provides comprehensive compression statistics' do
      result = service.compress_chunk_list(chunk_list)
      stats = result[:compression_stats]
      
      expect(stats).to have_key(:total_chunks)
      expect(stats).to have_key(:compressed_chunks)
      expect(stats).to have_key(:compression_ratio)
      expect(stats).to have_key(:bytes_saved)
      expect(stats).to have_key(:processing_time)
      
      expect(stats[:total_chunks]).to eq(3)
      expect(stats[:bytes_saved]).to be > 0
    end

    it 'handles empty chunk list gracefully' do
      result = service.compress_chunk_list([])
      
      expect(result[:compressed_chunks]).to be_empty
      expect(result[:uncompressed_chunks]).to be_empty
      expect(result[:compression_stats][:total_chunks]).to eq(0)
    end

    it 'preserves chunk order and metadata' do
      result = service.compress_chunk_list(chunk_list)
      
      all_chunks = result[:compressed_chunks] + result[:uncompressed_chunks]
      chunk_numbers = all_chunks.map { |chunk| chunk[:chunk_number] }.sort
      
      expect(chunk_numbers).to eq([1, 2, 3])
    end
  end

  describe '#adaptive_compression' do
    it 'adapts compression level based on performance' do
      # Start with default compression
      service = ChunkCompressionService.new
      expect(service.compression_level).to eq(6)
      
      # Simulate slow compression performance that should trigger level reduction
      slow_performance = {
        compression_time: 2.5, # > 2.0 seconds (very slow)
        compression_ratio: 0.3,
        chunk_size: 1000
      }
      
      service.adapt_compression_settings(slow_performance)
      
      # Should reduce compression level for speed
      expect(service.compression_level).to be < 6
    end

    it 'increases compression for good performance and low ratios' do
      service = ChunkCompressionService.new
      expect(service.compression_level).to eq(6)
      
      # Simulate fast compression with poor ratio
      fast_performance = {
        compression_time: 0.05, # < 0.1 seconds (very fast)
        compression_ratio: 0.05, # < 0.3 (very low compression ratio)
        chunk_size: 1000
      }
      
      service.adapt_compression_settings(fast_performance)
      
      # Should increase compression level for better ratio
      expect(service.compression_level).to be > 6
    end

    it 'switches algorithms for better performance' do
      service = ChunkCompressionService.new(algorithm: :gzip)
      
      # Simulate poor gzip performance
      poor_gzip_performance = {
        compression_time: 3.0,
        compression_ratio: 0.1,
        chunk_size: 1000
      }
      
      service.adapt_compression_settings(poor_gzip_performance)
      
      # Might switch to faster algorithm
      expect([:gzip, :lz4]).to include(service.compression_algorithm)
    end
  end

  describe 'integration with upload services' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }
    
    it 'integrates with ParallelUploadService' do
      parallel_service = ParallelUploadService.new(upload_session)
      compression_service = ChunkCompressionService.new
      
      original_chunk_data = [
        {
          chunk_number: 1,
          data: 'Compressible data for integration testing. ' * 50,
          size: 2150,
          checksum: 'integration_checksum'
        }
      ]
      
      # Mock the upload to use compression
      allow(parallel_service).to receive(:upload_single_chunk) do |chunk_info|
        # Compress before upload
        if compression_service.should_compress?(chunk_info)
          compressed = compression_service.compress_chunk(chunk_info)
          { success: true, chunk_number: compressed[:chunk_number], compressed: true }
        else
          { success: true, chunk_number: chunk_info[:chunk_number], compressed: false }
        end
      end
      
      results = parallel_service.upload_chunks_parallel(original_chunk_data)
      
      expect(results.first[:success]).to be true
      expect(results.first[:compressed]).to be true
    end

    it 'provides compression middleware for upload pipeline' do
      chunk_data = {
        chunk_number: 1,
        data: 'Pipeline test data. ' * 100,
        size: 2000,
        checksum: 'pipeline_checksum'
      }
      
      # Simulate upload pipeline with compression
      processed_chunk = if service.should_compress?(chunk_data)
        service.compress_chunk(chunk_data)
      else
        chunk_data
      end
      
      expect(processed_chunk[:compressed_size]).to be < processed_chunk[:original_size]
      expect(processed_chunk[:algorithm_used]).to be_present
    end
  end

  describe 'performance and memory efficiency' do
    it 'handles large chunks efficiently' do
      large_data = 'Large chunk data for performance testing. ' * 10000 # ~400KB
      large_chunk = {
        chunk_number: 1,
        data: large_data,
        size: large_data.bytesize,
        checksum: 'large_checksum'
      }
      
      start_time = Time.current
      result = service.compress_chunk(large_chunk)
      end_time = Time.current
      
      compression_time = end_time - start_time
      
      expect(compression_time).to be < 1.0 # Should complete within 1 second
      expect(result[:compressed_size]).to be < result[:original_size]
    end

    it 'manages memory efficiently for multiple chunks' do
      chunks = (1..10).map do |i|
        {
          chunk_number: i,
          data: "Chunk #{i} data. " * 100,
          size: 1400,
          checksum: "checksum_#{i}"
        }
      end
      
      # Monitor memory usage during compression
      start_memory = GC.stat[:heap_allocated_pages]
      
      result = service.compress_chunk_list(chunks)
      
      # Force garbage collection
      GC.start
      end_memory = GC.stat[:heap_allocated_pages]
      
      expect(result[:compression_stats][:total_chunks]).to eq(10)
      # Memory growth should be reasonable
      expect(end_memory - start_memory).to be < 100 # pages
    end
  end

  describe 'error handling and edge cases' do
    it 'handles nil data gracefully' do
      nil_chunk = { chunk_number: 1, data: nil, size: 0, checksum: 'nil_checksum' }
      
      expect {
        service.compress_chunk(nil_chunk)
      }.to raise_error(ChunkCompressionService::CompressionError, /Invalid chunk data/)
    end

    it 'handles empty data gracefully' do
      empty_chunk = { chunk_number: 1, data: '', size: 0, checksum: 'empty_checksum' }
      
      result = service.compress_chunk(empty_chunk)
      
      expect(result[:compressed_size]).to eq(0)
      expect(result[:compression_ratio]).to eq(0)
    end

    it 'handles compression failures gracefully' do
      # Mock zlib to raise an error
      allow(Zlib::Deflate).to receive(:deflate).and_raise(Zlib::Error, 'Compression failed')
      
      chunk = {
        chunk_number: 1,
        data: 'test data',
        size: 9,
        checksum: 'test_checksum'
      }
      
      expect {
        service.compress_chunk(chunk)
      }.to raise_error(ChunkCompressionService::CompressionError)
    end
  end
end