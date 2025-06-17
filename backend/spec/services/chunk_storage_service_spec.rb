# spec/services/chunk_storage_service_spec.rb
require 'rails_helper'

RSpec.describe ChunkStorageService, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }
  let(:storage_service) { ChunkStorageService.new }
  
  # Create test chunk file
  let(:chunk_file) do
    temp_file = Tempfile.new(['test_chunk', '.bin'])
    temp_file.write('Test chunk data for storage testing')
    temp_file.rewind
    
    # Convert to uploaded file format that Rails expects
    Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')
  end
  
  private
  
  def cleanup_test_chunks
    # Clean up any test chunk files that might be left behind
    test_patterns = [
      Rails.root.join('tmp', 'wubhub_chunks', '**', '*.tmp'),
      Rails.root.join('tmp', 'custom_chunks', '**', '*.tmp'),
      Rails.root.join('tmp', 'test_chunks_isolated', '**', '*.tmp')
    ]
    
    test_patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        File.delete(file) if File.exist?(file)
      rescue => e
        # Ignore cleanup errors
      end
    end
    
    # Try to remove empty directories
    [
      Rails.root.join('tmp', 'wubhub_chunks'),
      Rails.root.join('tmp', 'custom_chunks'),
      Rails.root.join('tmp', 'test_chunks_isolated')
    ].each do |dir|
      begin
        FileUtils.remove_dir(dir) if Dir.exist?(dir) && Dir.empty?(dir)
      rescue => e
        # Ignore cleanup errors
      end
    end
  end

  after(:each) do
    # Clean up test files
    chunk_file&.close
    chunk_file&.unlink if chunk_file&.respond_to?(:unlink)
    
    # Clean up any chunk files created during tests
    cleanup_test_chunks
  end

  describe '#store_chunk' do
    it 'stores chunk file and returns storage key' do
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      
      expect(storage_key).to be_present
      expect(storage_key).to be_a(String)
      expect(storage_key).to include(upload_session.id.to_s)
      expect(storage_key).to include('chunk_1')
      expect(File.exist?(storage_key)).to be true
    end

    it 'stores correct file content' do
      original_content = chunk_file.read
      chunk_file.rewind
      
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      stored_content = File.read(storage_key)
      
      expect(stored_content).to eq(original_content)
    end

    it 'creates unique storage paths for different upload sessions' do
      other_session = create(:upload_session, workspace: workspace, user: user)
      
      storage_key_1 = storage_service.store_chunk(upload_session, 1, chunk_file)
      storage_key_2 = storage_service.store_chunk(other_session, 1, chunk_file)
      
      expect(storage_key_1).not_to eq(storage_key_2)
      expect(File.exist?(storage_key_1)).to be true
      expect(File.exist?(storage_key_2)).to be true
    end

    it 'creates unique storage paths for different chunk numbers' do
      storage_key_1 = storage_service.store_chunk(upload_session, 1, chunk_file)
      storage_key_2 = storage_service.store_chunk(upload_session, 2, chunk_file)
      
      expect(storage_key_1).not_to eq(storage_key_2)
      expect(storage_key_1).to include('chunk_1')
      expect(storage_key_2).to include('chunk_2')
    end

    it 'creates directory structure automatically' do
      # Ensure clean state
      base_dir = storage_service.base_path
      session_dir = File.join(base_dir, "session_#{upload_session.id}")
      FileUtils.rm_rf(session_dir) if Dir.exist?(session_dir)
      
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      
      expect(File.exist?(storage_key)).to be true
      expect(Dir.exist?(File.dirname(storage_key))).to be true
    end

    it 'overwrites existing chunk file if re-uploaded' do
      # First upload
      storage_key_1 = storage_service.store_chunk(upload_session, 1, chunk_file)
      original_content = File.read(storage_key_1)
      
      # Create new chunk file with different content
      new_chunk_file = Tempfile.new(['new_chunk', '.bin'])
      new_chunk_file.write('Different chunk data for overwrite testing')
      new_chunk_file.rewind
      new_uploaded_file = Rack::Test::UploadedFile.new(new_chunk_file.path, 'application/octet-stream')
      
      # Second upload (same chunk number)
      storage_key_2 = storage_service.store_chunk(upload_session, 1, new_uploaded_file)
      new_content = File.read(storage_key_2)
      
      expect(storage_key_1).to eq(storage_key_2) # Same path
      expect(new_content).not_to eq(original_content)
      expect(new_content).to eq('Different chunk data for overwrite testing')
      
      # Cleanup
      new_chunk_file.close
      new_chunk_file.unlink
    end

    it 'handles permission errors gracefully' do
      # Mock File.open to raise permission error only when writing (not reading temp files)
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(anything, 'wb').and_raise(Errno::EACCES, 'Permission denied')
      
      expect {
        storage_service.store_chunk(upload_session, 1, chunk_file)
      }.to raise_error(ChunkStorageService::StorageError, /Permission denied/)
    end

    it 'validates upload session is present' do
      expect {
        storage_service.store_chunk(nil, 1, chunk_file)
      }.to raise_error(ArgumentError, /Upload session cannot be nil/)
    end

    it 'validates chunk number is positive' do
      expect {
        storage_service.store_chunk(upload_session, 0, chunk_file)
      }.to raise_error(ArgumentError, /Chunk number must be positive/)
    end

    it 'validates chunk file is present' do
      expect {
        storage_service.store_chunk(upload_session, 1, nil)
      }.to raise_error(ArgumentError, /Chunk file cannot be nil/)
    end
  end

  describe '#chunk_exists?' do
    it 'returns true if chunk file exists' do
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      
      expect(storage_service.chunk_exists?(storage_key)).to be true
    end

    it 'returns false if chunk file does not exist' do
      fake_storage_key = '/tmp/non_existent_chunk.tmp'
      
      expect(storage_service.chunk_exists?(fake_storage_key)).to be false
    end

    it 'returns false for nil storage key' do
      expect(storage_service.chunk_exists?(nil)).to be false
    end
  end

  describe '#read_chunk' do
    it 'returns chunk content as IO object' do
      original_content = chunk_file.read
      chunk_file.rewind
      
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      
      chunk_io = storage_service.read_chunk(storage_key)
      retrieved_content = chunk_io.read
      
      expect(retrieved_content).to eq(original_content)
      
      chunk_io.close
    end

    it 'raises error for non-existent chunk' do
      fake_storage_key = '/tmp/non_existent_chunk.tmp'
      
      expect {
        storage_service.read_chunk(fake_storage_key)
      }.to raise_error(ChunkStorageService::ChunkNotFoundError)
    end
  end

  describe '#delete_chunk' do
    it 'deletes existing chunk file' do
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      expect(File.exist?(storage_key)).to be true
      
      result = storage_service.delete_chunk(storage_key)
      
      expect(result).to be true
      expect(File.exist?(storage_key)).to be false
    end

    it 'returns false when trying to delete non-existent file' do
      fake_storage_key = '/tmp/non_existent_chunk.tmp'
      
      result = storage_service.delete_chunk(fake_storage_key)
      expect(result).to be false
    end

    it 'returns false for nil storage key' do
      result = storage_service.delete_chunk(nil)
      expect(result).to be false
    end
  end

  describe '#cleanup_session_chunks' do
    it 'deletes all chunks for an upload session' do
      storage_keys = []
      3.times do |i|
        storage_keys << storage_service.store_chunk(upload_session, i + 1, chunk_file)
      end
      
      # Create chunk records with storage keys
      storage_keys.each_with_index do |key, index|
        create(:chunk, 
          upload_session: upload_session, 
          chunk_number: index + 1, 
          storage_key: key,
          status: 'completed'
        )
      end
      
      # Verify all files exist
      storage_keys.each do |key|
        expect(File.exist?(key)).to be true
      end
      
      deleted_count = storage_service.cleanup_session_chunks(upload_session)
      
      expect(deleted_count).to eq(3)
      
      # Verify all files are deleted
      storage_keys.each do |key|
        expect(File.exist?(key)).to be false
      end
    end

    it 'removes session directory if empty after cleanup' do
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      create(:chunk, 
        upload_session: upload_session, 
        chunk_number: 1, 
        storage_key: storage_key,
        status: 'completed'
      )
      
      session_dir = File.dirname(storage_key)
      expect(Dir.exist?(session_dir)).to be true
      
      storage_service.cleanup_session_chunks(upload_session)
      
      expect(Dir.exist?(session_dir)).to be false
    end

    it 'handles case where session has no chunks' do
      expect {
        deleted_count = storage_service.cleanup_session_chunks(upload_session)
        expect(deleted_count).to eq(0)
      }.not_to raise_error
    end
  end

  describe '#storage_stats' do
    it 'provides storage statistics' do
      stats = storage_service.storage_stats
      
      expect(stats).to have_key(:backend_type)
      expect(stats).to have_key(:base_path)
      expect(stats).to have_key(:total_chunks)
      expect(stats).to have_key(:total_size)
      expect(stats[:backend_type]).to eq('local_filesystem')
      expect(stats[:total_chunks]).to be >= 0
      expect(stats[:total_size]).to be >= 0
    end

    it 'counts stored chunks correctly' do
      # Use isolated storage to avoid interference from other tests
      isolated_service = ChunkStorageService.new(base_path: Rails.root.join('tmp', 'test_chunks_isolated'))
      
      initial_stats = isolated_service.storage_stats
      
      isolated_service.store_chunk(upload_session, 1, chunk_file)
      isolated_service.store_chunk(upload_session, 2, chunk_file)
      
      updated_stats = isolated_service.storage_stats
      
      expect(updated_stats[:total_chunks]).to eq(initial_stats[:total_chunks] + 2)
      expect(updated_stats[:total_size]).to be > initial_stats[:total_size]
      
      # Clean up isolated test directory
      FileUtils.rm_rf(Rails.root.join('tmp', 'test_chunks_isolated'))
    end
  end

  describe 'configuration' do
    it 'uses configurable base storage path' do
      custom_service = ChunkStorageService.new(base_path: '/tmp/custom_chunks')
      
      storage_key = custom_service.store_chunk(upload_session, 1, chunk_file)
      
      expect(storage_key).to include('/tmp/custom_chunks')
      expect(File.exist?(storage_key)).to be true
    end

    it 'uses default base path when none specified' do
      default_service = ChunkStorageService.new
      
      storage_key = default_service.store_chunk(upload_session, 1, chunk_file)
      
      expect(storage_key).to include('tmp/wubhub_chunks')
    end
  end

  describe 'file path generation' do
    it 'generates safe file paths' do
      storage_key = storage_service.store_chunk(upload_session, 1, chunk_file)
      
      # Should not contain unsafe characters
      expect(storage_key).not_to include('..')
      expect(storage_key).not_to include('//')
      
      # Should be within expected directory structure
      expect(storage_key).to include('tmp/wubhub_chunks')
      expect(storage_key).to include("session_#{upload_session.id}")
      expect(storage_key).to include('chunk_1.tmp')
    end
  end
end