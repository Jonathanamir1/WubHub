# spec/services/parallel_upload_service_spec.rb
require 'rails_helper'

RSpec.describe ParallelUploadService, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 5, status: 'pending') }
  let(:service) { ParallelUploadService.new(upload_session) }

  describe '#initialize' do
    it 'sets default concurrency limit' do
      expect(service.max_concurrent_uploads).to eq(3)
    end

    it 'allows custom concurrency limit' do
      custom_service = ParallelUploadService.new(upload_session, max_concurrent: 5)
      expect(custom_service.max_concurrent_uploads).to eq(5)
    end

    it 'raises error for invalid upload session' do
      expect {
        ParallelUploadService.new(nil)
      }.to raise_error(ArgumentError, 'Upload session cannot be nil')
    end
  end

  describe '#upload_chunks_parallel' do
    let(:chunk_data) do
      (1..5).map do |i|
        {
          chunk_number: i,
          data: "chunk_data_#{i}",
          size: 1024,
          checksum: "checksum_#{i}"
        }
      end
    end

    before do
      # Mock the individual chunk upload to avoid actual file operations
      allow(service).to receive(:upload_single_chunk).and_return(
        { success: true, chunk_number: 1, response: { status: 'completed' } }
      )
    end

    it 'uploads chunks with limited concurrency' do
      # Track how many chunks are uploading simultaneously
      concurrent_uploads = []
      max_concurrent = 0

      allow(service).to receive(:upload_single_chunk) do |chunk_info|
        concurrent_uploads << chunk_info[:chunk_number]
        max_concurrent = [max_concurrent, concurrent_uploads.length].max
        
        # Simulate upload time
        sleep(0.1)
        
        concurrent_uploads.delete(chunk_info[:chunk_number])
        { success: true, chunk_number: chunk_info[:chunk_number], response: { status: 'completed' } }
      end

      service.upload_chunks_parallel(chunk_data)
      
      expect(max_concurrent).to be <= service.max_concurrent_uploads
    end

    it 'returns results for all chunks' do
      results = service.upload_chunks_parallel(chunk_data)
      
      expect(results).to be_an(Array)
      expect(results.length).to eq(5)
      expect(results.all? { |r| r[:success] }).to be true
    end

    it 'handles failed chunks gracefully' do
      # Mock one chunk to fail
      allow(service).to receive(:upload_single_chunk) do |chunk_info|
        if chunk_info[:chunk_number] == 3
          { success: false, chunk_number: 3, error: 'Network timeout' }
        else
          { success: true, chunk_number: chunk_info[:chunk_number], response: { status: 'completed' } }
        end
      end

      results = service.upload_chunks_parallel(chunk_data)
      
      failed_chunk = results.find { |r| r[:chunk_number] == 3 }
      expect(failed_chunk[:success]).to be false
      expect(failed_chunk[:error]).to eq('Network timeout')
      
      # Other chunks should succeed
      successful_chunks = results.reject { |r| r[:chunk_number] == 3 }
      expect(successful_chunks.all? { |r| r[:success] }).to be true
    end

    it 'respects upload session state' do
      # Follow proper state transition to get to a terminal state
      upload_session.start_upload!
      upload_session.start_assembly!
      upload_session.start_virus_scan!
      upload_session.start_finalization!
      upload_session.complete!
      
      expect {
        service.upload_chunks_parallel(chunk_data)
      }.to raise_error(ParallelUploadService::InvalidSessionState, /not accepting chunks/)
    end

    it 'validates chunk data format' do
      invalid_chunk_data = [{ chunk_number: 1 }] # Missing required fields
      
      expect {
        service.upload_chunks_parallel(invalid_chunk_data)
      }.to raise_error(ArgumentError, /Invalid chunk data/)
    end
  end

  describe '#upload_status' do
    before do
      # Create some chunks in different states
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'pending')
    end

    it 'returns current upload progress' do
      status = service.upload_status
      
      expect(status[:total_chunks]).to eq(5)
      expect(status[:completed_chunks]).to eq(2)
      expect(status[:pending_chunks]).to eq(1)
      expect(status[:progress_percentage]).to eq(40.0)
      expect(status[:upload_session_status]).to eq('pending')
    end

    it 'identifies chunks ready for upload' do
      status = service.upload_status
      
      ready_chunks = status[:chunks_ready_for_upload]
      expect(ready_chunks).to include(3, 4, 5) # chunks not yet uploaded
      expect(ready_chunks).not_to include(1, 2) # already completed
    end
  end

  describe '#retry_failed_chunks' do
    before do
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'failed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'failed')
    end

    it 'retries only failed chunks' do
      failed_chunk_data = [
        { chunk_number: 2, data: 'chunk_data_2', size: 1024, checksum: 'checksum_2' },
        { chunk_number: 3, data: 'chunk_data_3', size: 1024, checksum: 'checksum_3' }
      ]

      expect(service).to receive(:upload_chunks_parallel).with(failed_chunk_data)
      
      service.retry_failed_chunks(failed_chunk_data)
    end

    it 'does not retry completed chunks' do
      all_chunk_data = (1..3).map { |i| { chunk_number: i, data: "data_#{i}", size: 1024, checksum: "checksum_#{i}" } }

      # Should only retry chunks 2 and 3, not chunk 1
      expect(service).to receive(:upload_chunks_parallel) do |chunks|
        expect(chunks.length).to eq(2)
        expect(chunks.map { |c| c[:chunk_number] }).to contain_exactly(2, 3)
      end

      service.retry_failed_chunks(all_chunk_data)
    end
  end

  describe 'error handling' do
    it 'handles service unavailable errors' do
      allow(service).to receive(:upload_single_chunk).and_raise(StandardError, 'Service unavailable')
      
      chunk_data = [{ chunk_number: 1, data: 'test', size: 1024, checksum: 'abc123' }]
      results = service.upload_chunks_parallel(chunk_data)
      
      expect(results.first[:success]).to be false
      expect(results.first[:error]).to include('Service unavailable')
    end

    it 'handles network timeout errors' do
      allow(service).to receive(:upload_single_chunk).and_raise(Timeout::Error, 'Request timeout')
      
      chunk_data = [{ chunk_number: 1, data: 'test', size: 1024, checksum: 'abc123' }]
      results = service.upload_chunks_parallel(chunk_data)
      
      expect(results.first[:success]).to be false
      expect(results.first[:error]).to include('Request timeout')
    end
  end

  describe 'performance considerations' do
    it 'processes chunks efficiently with large datasets' do
      # Create upload session with 100 chunks for performance testing
      large_upload_session = create(:upload_session, workspace: workspace, user: user, chunks_count: 100, status: 'pending')
      large_service = ParallelUploadService.new(large_upload_session, max_concurrent: 5)
      
      large_chunk_data = (1..100).map do |i|
        { chunk_number: i, data: "chunk_#{i}", size: 1024, checksum: "checksum_#{i}" }
      end

      # Mock fast uploads
      allow(large_service).to receive(:upload_single_chunk) do |chunk_info|
        { success: true, chunk_number: chunk_info[:chunk_number], response: { status: 'completed' } }
      end

      start_time = Time.current
      results = large_service.upload_chunks_parallel(large_chunk_data)
      end_time = Time.current

      expect(results.length).to eq(100)
      expect(end_time - start_time).to be < 10.seconds # Should complete within reasonable time
    end
  end
end