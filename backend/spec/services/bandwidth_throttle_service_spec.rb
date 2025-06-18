# spec/services/bandwidth_throttle_service_spec.rb
require 'rails_helper'

RSpec.describe BandwidthThrottleService, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 5, status: 'pending') }

  describe '#initialize' do
    it 'sets default bandwidth limit' do
      service = BandwidthThrottleService.new
      expect(service.bandwidth_limit_kbps).to eq(1000) # 1 MB/s default
    end

    it 'allows custom bandwidth limit' do
      service = BandwidthThrottleService.new(bandwidth_limit_kbps: 500)
      expect(service.bandwidth_limit_kbps).to eq(500)
    end

    it 'accepts bandwidth limit in different units' do
      service = BandwidthThrottleService.new(bandwidth_limit_mbps: 2)
      expect(service.bandwidth_limit_kbps).to eq(2000)
    end

    it 'validates bandwidth limits are positive' do
      expect {
        BandwidthThrottleService.new(bandwidth_limit_kbps: -100)
      }.to raise_error(ArgumentError, /Bandwidth limit must be positive/)
    end

    it 'supports unlimited bandwidth mode' do
      service = BandwidthThrottleService.new(bandwidth_limit_kbps: 0)
      expect(service.unlimited?).to be true
    end
  end

  describe '#calculate_delay' do
    let(:service) { BandwidthThrottleService.new(bandwidth_limit_kbps: 1000) } # 1 MB/s

    it 'calculates correct delay for given data size' do
      data_size_kb = 500 # 500 KB
      expected_delay = 0.5 # Should take 0.5 seconds at 1000 KB/s
      
      delay = service.calculate_delay(data_size_kb)
      expect(delay).to be_within(0.01).of(expected_delay)
    end

    it 'returns zero delay for unlimited bandwidth' do
      unlimited_service = BandwidthThrottleService.new(bandwidth_limit_kbps: 0)
      
      delay = unlimited_service.calculate_delay(1000)
      expect(delay).to eq(0)
    end

    it 'handles very small data sizes' do
      delay = service.calculate_delay(1) # 1 KB
      expect(delay).to be > 0
      expect(delay).to be < 0.1
    end

    it 'handles very large data sizes' do
      data_size_kb = 10_000 # 10 MB
      delay = service.calculate_delay(data_size_kb)
      expect(delay).to eq(10.0) # Should take 10 seconds
    end
  end

  describe '#throttle_upload' do
    let(:service) { BandwidthThrottleService.new(bandwidth_limit_kbps: 1000) }

    it 'applies delay before upload based on data size' do
      chunk_data = { chunk_number: 1, data: 'x' * (500 * 1024), size: 500 * 1024 } # 500 KB
      
      start_time = Time.current
      
      # Mock the upload operation to complete instantly
      result = service.throttle_upload(chunk_data) do |data|
        { success: true, uploaded_at: Time.current }
      end
      
      end_time = Time.current
      duration = end_time - start_time
      
      expect(result[:success]).to be true
      expect(duration).to be >= 0.4 # Should have waited ~0.5 seconds
      expect(duration).to be <= 0.7 # Allow some tolerance
    end

    it 'does not delay when bandwidth is unlimited' do
      unlimited_service = BandwidthThrottleService.new(bandwidth_limit_kbps: 0)
      chunk_data = { chunk_number: 1, data: 'x' * (1024 * 1024), size: 1024 * 1024 } # 1 MB
      
      start_time = Time.current
      
      result = unlimited_service.throttle_upload(chunk_data) do |data|
        { success: true }
      end
      
      end_time = Time.current
      duration = end_time - start_time
      
      expect(result[:success]).to be true
      expect(duration).to be < 0.1 # Should complete almost instantly
    end

    it 'still executes upload even with throttling' do
      chunk_data = { chunk_number: 1, data: 'test', size: 4 }
      
      upload_executed = false
      result = service.throttle_upload(chunk_data) do |data|
        upload_executed = true
        { success: true, chunk_number: data[:chunk_number] }
      end
      
      expect(upload_executed).to be true
      expect(result[:success]).to be true
      expect(result[:chunk_number]).to eq(1)
    end

    it 'propagates upload errors while still applying throttling' do
      chunk_data = { chunk_number: 1, data: 'test', size: 4 }
      
      result = service.throttle_upload(chunk_data) do |data|
        { success: false, error: 'Upload failed' }
      end
      
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Upload failed')
    end

    it 'handles exceptions during upload' do
      chunk_data = { chunk_number: 1, data: 'test', size: 4 }
      
      expect {
        service.throttle_upload(chunk_data) do |data|
          raise StandardError, 'Network error'
        end
      }.to raise_error(StandardError, 'Network error')
    end
  end

  describe '#throttle_parallel_uploads' do
    let(:service) { BandwidthThrottleService.new(bandwidth_limit_kbps: 2000) } # 2 MB/s
    let(:chunk_data_list) do
      (1..4).map do |i|
        { chunk_number: i, data: 'x' * (250 * 1024), size: 250 * 1024 } # 250 KB each
      end
    end

    it 'distributes bandwidth among parallel uploads' do
      results = []
      start_time = Time.current
      
      # Mock parallel uploads
      result = service.throttle_parallel_uploads(chunk_data_list, max_concurrent: 2) do |chunk_data|
        upload_start = Time.current
        results << {
          chunk_number: chunk_data[:chunk_number],
          started_at: upload_start,
          success: true
        }
        { success: true, chunk_number: chunk_data[:chunk_number] }
      end
      
      end_time = Time.current
      total_duration = end_time - start_time
      
      expect(result.length).to eq(4)
      expect(result.all? { |r| r[:success] }).to be true
      
      # With 2 MB/s and 4 chunks of 250KB each, should take ~0.5 seconds total
      # (2 concurrent uploads of 250KB each = 500KB/s per upload = 0.5s per upload)
      expect(total_duration).to be >= 0.4
      expect(total_duration).to be <= 0.7
    end

    it 'adjusts individual upload speeds based on concurrency' do
      service = BandwidthThrottleService.new(bandwidth_limit_kbps: 1000) # 1 MB/s total
      
      # Test with 2 concurrent uploads - each should get 500 KB/s
      per_upload_bandwidth = service.calculate_per_upload_bandwidth(2)
      expect(per_upload_bandwidth).to eq(500)
      
      # Test with 4 concurrent uploads - each should get 250 KB/s
      per_upload_bandwidth = service.calculate_per_upload_bandwidth(4)
      expect(per_upload_bandwidth).to eq(250)
    end

    it 'handles unlimited bandwidth in parallel mode' do
      unlimited_service = BandwidthThrottleService.new(bandwidth_limit_kbps: 0)
      
      start_time = Time.current
      
      result = unlimited_service.throttle_parallel_uploads(chunk_data_list, max_concurrent: 4) do |chunk_data|
        { success: true, chunk_number: chunk_data[:chunk_number] }
      end
      
      end_time = Time.current
      duration = end_time - start_time
      
      expect(result.length).to eq(4)
      expect(duration).to be < 0.1 # Should complete almost instantly
    end
  end

  describe '#adaptive_bandwidth_detection' do
    let(:service) { BandwidthThrottleService.new }

    it 'can measure actual upload speed' do
      # Simulate uploading 1MB of data in 2 seconds
      test_data_size_kb = 1024 # 1 MB
      simulated_duration = 2.0 # 2 seconds
      
      measured_speed = service.measure_upload_speed(test_data_size_kb, simulated_duration)
      expect(measured_speed).to eq(512) # 1024 KB / 2 seconds = 512 KB/s
    end

    it 'can adjust bandwidth limit based on measured performance' do
      # Start with conservative limit
      service = BandwidthThrottleService.new(bandwidth_limit_kbps: 500)
      
      # Simulate successful upload at higher speed
      measured_speed_kbps = 800 # User can actually do 800 KB/s
      
      service.adapt_bandwidth_limit(measured_speed_kbps)
      
      # Should increase limit but stay conservative (80% of measured)
      expected_new_limit = (measured_speed_kbps * 0.8).to_i
      expect(service.bandwidth_limit_kbps).to eq(expected_new_limit)
    end

    it 'can decrease bandwidth limit if performance is poor' do
      service = BandwidthThrottleService.new(bandwidth_limit_kbps: 1000)
      
      # Simulate poor performance
      measured_speed_kbps = 300 # Much slower than expected
      
      service.adapt_bandwidth_limit(measured_speed_kbps)
      
      # Should decrease to measured speed
      expect(service.bandwidth_limit_kbps).to eq(300)
    end

    it 'maintains minimum bandwidth limit' do
      service = BandwidthThrottleService.new(bandwidth_limit_kbps: 1000)
      
      # Simulate very poor performance
      measured_speed_kbps = 10 # Extremely slow
      
      service.adapt_bandwidth_limit(measured_speed_kbps)
      
      # Should not go below minimum (e.g., 50 KB/s)
      expect(service.bandwidth_limit_kbps).to be >= 50
    end
  end

  describe '#bandwidth_statistics' do
    let(:service) { BandwidthThrottleService.new(bandwidth_limit_kbps: 1000) }

    it 'tracks bandwidth usage over time' do
      # Simulate some uploads
      service.record_upload(500 * 1024, 0.5) # 500 KB in 0.5 seconds
      service.record_upload(300 * 1024, 0.3) # 300 KB in 0.3 seconds
      
      stats = service.bandwidth_statistics
      
      expect(stats[:total_bytes_uploaded]).to eq(800 * 1024)
      expect(stats[:total_upload_time]).to eq(0.8)
      expect(stats[:average_speed_kbps]).to be_within(10).of(1000) # ~1000 KB/s average
    end

    it 'calculates efficiency metrics' do
      service.record_upload(1000 * 1024, 1.0) # Perfect efficiency: 1000 KB/s
      service.record_upload(500 * 1024, 1.0)  # Poor efficiency: 500 KB/s
      
      stats = service.bandwidth_statistics
      
      expect(stats[:efficiency_percentage]).to be_within(5).of(75) # 75% efficiency
    end

    it 'provides time-windowed statistics' do
      # Record old upload
      service.record_upload(100 * 1024, 0.1, timestamp: 1.hour.ago)
      
      # Record recent upload
      service.record_upload(500 * 1024, 0.5, timestamp: Time.current)
      
      recent_stats = service.bandwidth_statistics(window: 30.minutes)
      
      expect(recent_stats[:total_bytes_uploaded]).to eq(500 * 1024) # Only recent upload
    end
  end

  describe 'integration with existing upload services' do
    let(:throttle_service) { BandwidthThrottleService.new(bandwidth_limit_kbps: 500) }
    
    it 'integrates with ParallelUploadService' do
      parallel_service = ParallelUploadService.new(upload_session)
      
      # Mock the upload to use throttling
      allow(parallel_service).to receive(:upload_single_chunk) do |chunk_info|
        throttle_service.throttle_upload(chunk_info) do |data|
          { success: true, chunk_number: data[:chunk_number] }
        end
      end
      
      chunk_data = [
        { 
          chunk_number: 1, 
          data: 'x' * (100 * 1024), 
          size: 100 * 1024,
          checksum: 'abc123def456' # Add required checksum field
        }
      ]
      
      start_time = Time.current
      results = parallel_service.upload_chunks_parallel(chunk_data)
      end_time = Time.current
      
      duration = end_time - start_time
      
      expect(results.first[:success]).to be true
      expect(duration).to be >= 0.15 # Should have some throttling delay
    end
  end

  describe 'error handling and edge cases' do
    let(:service) { BandwidthThrottleService.new(bandwidth_limit_kbps: 1000) }

    it 'handles zero-size uploads gracefully' do
      chunk_data = { chunk_number: 1, data: '', size: 0 }
      
      result = service.throttle_upload(chunk_data) do |data|
        { success: true }
      end
      
      expect(result[:success]).to be true
    end

    it 'handles system clock changes during throttling' do
      # This is a edge case where system time might change during upload
      chunk_data = { chunk_number: 1, data: 'test', size: 1000 }
      
      # Mock Time.current to simulate clock change
      allow(Time).to receive(:current).and_return(Time.now, Time.now - 1.hour, Time.now)
      
      expect {
        service.throttle_upload(chunk_data) { |data| { success: true } }
      }.not_to raise_error
    end

    it 'provides reasonable defaults for invalid configurations' do
      # Test with extremely high bandwidth
      high_service = BandwidthThrottleService.new(bandwidth_limit_kbps: 1_000_000)
      expect(high_service.bandwidth_limit_kbps).to eq(1_000_000)
      
      # Test calculation doesn't break
      delay = high_service.calculate_delay(1000)
      expect(delay).to be >= 0
    end
  end
end