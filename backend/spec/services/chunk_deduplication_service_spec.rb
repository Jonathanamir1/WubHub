# spec/services/chunk_deduplication_service_spec.rb
require 'rails_helper'

RSpec.describe ChunkDeduplicationService, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 5, status: 'pending') }
  let(:service) { ChunkDeduplicationService.new }

  describe '#initialize' do
    it 'initializes with default settings' do
      expect(service.enabled?).to be true
    end

    it 'can be disabled for testing' do
      disabled_service = ChunkDeduplicationService.new(enabled: false)
      expect(disabled_service.enabled?).to be false
    end
  end

  describe '#find_duplicate_chunks' do
    let(:checksum1) { 'abc123def456' }
    let(:checksum2) { 'def456ghi789' }
    let(:checksum3) { 'ghi789jkl012' }

    before do
      # Create chunks with known checksums across different sessions
      other_upload_session = create(:upload_session, workspace: workspace, user: user, chunks_count: 3)
      
      create(:chunk, upload_session: other_upload_session, chunk_number: 1, 
             checksum: checksum1, status: 'completed', storage_key: '/tmp/chunk_1.tmp')
      create(:chunk, upload_session: other_upload_session, chunk_number: 2, 
             checksum: checksum2, status: 'completed', storage_key: '/tmp/chunk_2.tmp')
    end

    it 'finds existing chunks by checksum' do
      chunk_checksums = [checksum1, checksum2, checksum3] # checksum3 is new
      
      duplicates = service.find_duplicate_chunks(chunk_checksums, workspace)
      
      expect(duplicates).to be_a(Hash)
      expect(duplicates[checksum1]).to be_present
      expect(duplicates[checksum2]).to be_present
      expect(duplicates[checksum3]).to be_nil
      
      # Verify the duplicate chunk data
      expect(duplicates[checksum1][:storage_key]).to eq('/tmp/chunk_1.tmp')
      expect(duplicates[checksum2][:storage_key]).to eq('/tmp/chunk_2.tmp')
    end

    it 'only finds chunks from the same workspace' do
      other_workspace = create(:workspace, user: user)
      other_session = create(:upload_session, workspace: other_workspace, user: user)
      
      # Create chunk in different workspace with same checksum
      create(:chunk, upload_session: other_session, chunk_number: 1, 
             checksum: checksum1, status: 'completed', storage_key: '/tmp/other_chunk.tmp')
      
      duplicates = service.find_duplicate_chunks([checksum1], workspace)
      
      # Should find the chunk from our workspace, not the other one
      expect(duplicates[checksum1][:storage_key]).to eq('/tmp/chunk_1.tmp')
    end

    it 'only finds completed chunks' do
      # Create a pending chunk with same checksum
      pending_session = create(:upload_session, workspace: workspace, user: user)
      create(:chunk, upload_session: pending_session, chunk_number: 1, 
             checksum: checksum1, status: 'pending', storage_key: '/tmp/pending_chunk.tmp')
      
      duplicates = service.find_duplicate_chunks([checksum1], workspace)
      
      # Should find the completed chunk, not the pending one
      expect(duplicates[checksum1][:storage_key]).to eq('/tmp/chunk_1.tmp')
    end

    it 'handles empty checksum list' do
      duplicates = service.find_duplicate_chunks([], workspace)
      expect(duplicates).to eq({})
    end

    it 'handles nil workspace gracefully' do
      expect {
        service.find_duplicate_chunks([checksum1], nil)
      }.to raise_error(ArgumentError, 'Workspace cannot be nil')
    end
  end

  describe '#deduplicate_chunk_list' do
    let(:chunk_data) do
      [
        { chunk_number: 1, checksum: 'abc123', data: 'data1', size: 1024 },
        { chunk_number: 2, checksum: 'def456', data: 'data2', size: 2048 },
        { chunk_number: 3, checksum: 'ghi789', data: 'data3', size: 1536 },
        { chunk_number: 4, checksum: 'abc123', data: 'data4', size: 1024 }, # Duplicate of chunk 1
        { chunk_number: 5, checksum: 'jkl012', data: 'data5', size: 512 }
      ]
    end

    before do
      # Create existing chunk that matches chunk 2's checksum
      other_session = create(:upload_session, workspace: workspace, user: user)
      create(:chunk, upload_session: other_session, chunk_number: 1, 
             checksum: 'def456', status: 'completed', 
             storage_key: '/tmp/existing_chunk.tmp', size: 2048)
    end

    it 'returns chunks needed for upload and deduplication info' do
      result = service.deduplicate_chunk_list(chunk_data, upload_session)
      
      expect(result).to have_key(:chunks_to_upload)
      expect(result).to have_key(:deduplicated_chunks)
      expect(result).to have_key(:deduplication_stats)
      
      # Chunk 2 should be deduplicated (exists in workspace)
      # Chunk 4 should be deduplicated (duplicate of chunk 1 in same list)
      chunks_to_upload = result[:chunks_to_upload]
      expect(chunks_to_upload.length).to eq(3) # chunks 1, 3, 5
      
      chunk_numbers_to_upload = chunks_to_upload.map { |c| c[:chunk_number] }
      expect(chunk_numbers_to_upload).to contain_exactly(1, 3, 5)
    end

    it 'provides deduplication statistics' do
      result = service.deduplicate_chunk_list(chunk_data, upload_session)
      stats = result[:deduplication_stats]
      
      expect(stats[:total_chunks]).to eq(5)
      expect(stats[:chunks_to_upload]).to eq(3)
      expect(stats[:deduplicated_chunks]).to eq(2)
      expect(stats[:bytes_saved]).to be > 0
      expect(stats[:deduplication_ratio]).to be_between(0, 1)
    end

    it 'links deduplicated chunks to upload session' do
      result = service.deduplicate_chunk_list(chunk_data, upload_session)
      
      # Should create chunk records for deduplicated chunks
      expect(upload_session.chunks.count).to eq(2) # chunks 2 and 4 deduplicated
      
      chunk_2 = upload_session.chunks.find_by(chunk_number: 2)
      expect(chunk_2.status).to eq('completed')
      expect(chunk_2.storage_key).to eq('/tmp/existing_chunk.tmp')
      expect(chunk_2.checksum).to eq('def456')
      
      chunk_4 = upload_session.chunks.find_by(chunk_number: 4)
      expect(chunk_4.status).to eq('completed')
      expect(chunk_4.checksum).to eq('abc123')
    end

    it 'handles within-list deduplication correctly' do
      # Test chunks with same checksum in the same upload
      duplicate_data = [
        { chunk_number: 1, checksum: 'same123', data: 'data1', size: 1024 },
        { chunk_number: 2, checksum: 'same123', data: 'data2', size: 1024 },
        { chunk_number: 3, checksum: 'same123', data: 'data3', size: 1024 }
      ]
      
      result = service.deduplicate_chunk_list(duplicate_data, upload_session)
      
      # Only first chunk should need uploading
      expect(result[:chunks_to_upload].length).to eq(1)
      expect(result[:chunks_to_upload].first[:chunk_number]).to eq(1)
      
      # Other chunks should be deduplicated
      expect(result[:deduplicated_chunks].length).to eq(2)
    end

    it 'respects service enabled/disabled state' do
      disabled_service = ChunkDeduplicationService.new(enabled: false)
      
      result = disabled_service.deduplicate_chunk_list(chunk_data, upload_session)
      
      # When disabled, should return all chunks for upload
      expect(result[:chunks_to_upload].length).to eq(5)
      expect(result[:deduplicated_chunks]).to be_empty
      expect(result[:deduplication_stats][:deduplicated_chunks]).to eq(0)
    end
  end

  describe '#copy_chunk_for_session' do
    let(:source_chunk) do
      other_session = create(:upload_session, workspace: workspace, user: user)
      create(:chunk, upload_session: other_session, chunk_number: 1,
             checksum: 'abc123def', status: 'completed',
             storage_key: '/tmp/source_chunk.tmp', size: 2048)
    end

    it 'creates a new chunk record for the target session' do
      new_chunk = service.copy_chunk_for_session(source_chunk, upload_session, 3)
      
      expect(new_chunk.upload_session).to eq(upload_session)
      expect(new_chunk.chunk_number).to eq(3)
      expect(new_chunk.checksum).to eq('abc123def')
      expect(new_chunk.status).to eq('completed')
      expect(new_chunk.storage_key).to eq('/tmp/source_chunk.tmp')
      expect(new_chunk.size).to eq(2048)
      expect(new_chunk).to be_persisted
    end

    it 'does not duplicate the actual file' do
      # Mock the storage service to verify it's not called for copy
      storage_service = instance_double(ChunkStorageService)
      expect(ChunkStorageService).not_to receive(:new)
      
      service.copy_chunk_for_session(source_chunk, upload_session, 3)
    end

    it 'handles chunk copy failures gracefully' do
      # Mock validation failure on create!
      fake_chunk = build(:chunk)
      fake_error = ActiveRecord::RecordInvalid.new(fake_chunk)
      
      allow(upload_session.chunks).to receive(:create!).and_raise(fake_error)
      
      expect {
        service.copy_chunk_for_session(source_chunk, upload_session, 3)
      }.to raise_error(ChunkDeduplicationService::DeduplicationError)
    end
  end

  describe '#verify_chunk_integrity' do
    let(:chunk) do
      create(:chunk, upload_session: upload_session, chunk_number: 1,
             checksum: 'abc123def', status: 'completed',
             storage_key: '/tmp/test_chunk.tmp', size: 1024)
    end

    before do
      # Create a test file
      File.write('/tmp/test_chunk.tmp', 'test chunk data')
    end

    after do
      # Clean up test file
      File.delete('/tmp/test_chunk.tmp') if File.exist?('/tmp/test_chunk.tmp')
    end

    it 'verifies chunk file exists and matches size' do
      # Update chunk size to match actual file
      chunk.update!(size: File.size('/tmp/test_chunk.tmp'))
      
      expect(service.verify_chunk_integrity(chunk)).to be true
    end

    it 'returns false if file does not exist' do
      chunk.update!(storage_key: '/tmp/nonexistent_chunk.tmp')
      
      expect(service.verify_chunk_integrity(chunk)).to be false
    end

    it 'returns false if file size does not match' do
      chunk.update!(size: 999999) # Wrong size
      
      expect(service.verify_chunk_integrity(chunk)).to be false
    end

    it 'handles storage key being nil' do
      chunk.update!(storage_key: nil)
      
      expect(service.verify_chunk_integrity(chunk)).to be false
    end
  end

  describe 'performance and caching' do
    it 'efficiently queries large numbers of chunks' do
      # Create many chunks with different checksums
      checksums = (1..1000).map { |i| "checksum_#{i.to_s.rjust(4, '0')}" }
      
      start_time = Time.current
      duplicates = service.find_duplicate_chunks(checksums, workspace)
      end_time = Time.current
      
      expect(end_time - start_time).to be < 1.second
      expect(duplicates).to be_a(Hash)
    end

    it 'handles deduplication of large chunk lists efficiently' do
      large_chunk_data = (1..500).map do |i|
        { chunk_number: i, checksum: "checksum_#{i}", data: "data_#{i}", size: 1024 }
      end
      
      start_time = Time.current
      result = service.deduplicate_chunk_list(large_chunk_data, upload_session)
      end_time = Time.current
      
      expect(end_time - start_time).to be < 2.seconds
      expect(result[:chunks_to_upload].length).to eq(500) # No duplicates in this test
    end
  end
end