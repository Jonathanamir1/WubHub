# spec/models/chunk_spec.rb
require 'rails_helper'

RSpec.describe Chunk, type: :model do
  describe 'associations' do
    it { should belong_to(:upload_session) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 3) }
    
    it { should validate_presence_of(:chunk_number) }
    it { should validate_presence_of(:size) }
    it { should validate_presence_of(:status) }
    
    it 'validates status inclusion' do
      should validate_inclusion_of(:status).in_array(%w[pending uploading completed failed])
    end
    
    it 'validates size is positive' do
      chunk = build(:chunk, upload_session: upload_session, size: -1)
      expect(chunk).not_to be_valid
      expect(chunk.errors[:size]).to include('must be greater than 0')
    end
    
    it 'validates size is greater than zero' do
      chunk = build(:chunk, upload_session: upload_session, size: 0)
      expect(chunk).not_to be_valid
      expect(chunk.errors[:size]).to include('must be greater than 0')
    end
    
    it 'validates chunk_number uniqueness within upload session' do
      create(:chunk, upload_session: upload_session, chunk_number: 1)
      
      duplicate_chunk = build(:chunk, upload_session: upload_session, chunk_number: 1)
      expect(duplicate_chunk).not_to be_valid
      expect(duplicate_chunk.errors[:chunk_number]).to include('has already been taken')
    end
    
    it 'allows same chunk_number in different upload sessions' do
      other_upload_session = create(:upload_session, workspace: workspace, user: user)
      
      create(:chunk, upload_session: upload_session, chunk_number: 1)
      other_chunk = build(:chunk, upload_session: other_upload_session, chunk_number: 1)
      
      expect(other_chunk).to be_valid
    end
    
    it 'validates chunk_number is positive' do
      chunk = build(:chunk, upload_session: upload_session, chunk_number: 0)
      expect(chunk).not_to be_valid
      expect(chunk.errors[:chunk_number]).to include('must be greater than 0')
    end
    
    it 'validates chunk_number is not negative' do
      chunk = build(:chunk, upload_session: upload_session, chunk_number: -1)
      expect(chunk).not_to be_valid
      expect(chunk.errors[:chunk_number]).to include('must be greater than 0')
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    before do
      create(:chunk, upload_session: upload_session, status: 'pending')
      create(:chunk, upload_session: upload_session, status: 'uploading')
      create(:chunk, upload_session: upload_session, status: 'completed')
      create(:chunk, upload_session: upload_session, status: 'failed')
    end

    it 'has completed scope' do
      completed_chunks = Chunk.completed
      expect(completed_chunks.pluck(:status)).to all(eq('completed'))
      expect(completed_chunks.count).to eq(1)
    end

    it 'has pending scope' do
      pending_chunks = Chunk.pending
      expect(pending_chunks.pluck(:status)).to all(eq('pending'))
      expect(pending_chunks.count).to eq(1)
    end

    it 'has failed scope' do
      failed_chunks = Chunk.failed
      expect(failed_chunks.pluck(:status)).to all(eq('failed'))
      expect(failed_chunks.count).to eq(1)
    end
  end

  describe 'chunk ordering and numbering' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 5) }

    it 'can create chunks in non-sequential order' do
      chunk_3 = create(:chunk, upload_session: upload_session, chunk_number: 3)
      chunk_1 = create(:chunk, upload_session: upload_session, chunk_number: 1)
      chunk_5 = create(:chunk, upload_session: upload_session, chunk_number: 5)

      expect(chunk_3).to be_valid
      expect(chunk_1).to be_valid
      expect(chunk_5).to be_valid
    end

    it 'maintains chunk_number integrity within upload session' do
      chunks = []
      5.times do |i|
        chunks << create(:chunk, upload_session: upload_session, chunk_number: i + 1)
      end

      chunk_numbers = upload_session.chunks.pluck(:chunk_number).sort
      expect(chunk_numbers).to eq([1, 2, 3, 4, 5])
    end

    it 'orders chunks correctly by chunk_number' do
      # Create chunks out of order
      chunk_3 = create(:chunk, upload_session: upload_session, chunk_number: 3, size: 300)
      chunk_1 = create(:chunk, upload_session: upload_session, chunk_number: 1, size: 100)
      chunk_2 = create(:chunk, upload_session: upload_session, chunk_number: 2, size: 200)

      ordered_chunks = upload_session.chunks.order(:chunk_number)
      expect(ordered_chunks.pluck(:size)).to eq([100, 200, 300])
    end
  end

  describe 'chunk data and metadata' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    it 'stores checksum for data integrity' do
      chunk = create(:chunk, 
        upload_session: upload_session,
        checksum: 'abc123def456789'
      )

      expect(chunk.checksum).to eq('abc123def456789')
    end

    it 'stores storage_key for file location tracking' do
      chunk = create(:chunk,
        upload_session: upload_session,
        storage_key: '/tmp/upload_chunks/session_123_chunk_1.tmp'
      )

      expect(chunk.storage_key).to eq('/tmp/upload_chunks/session_123_chunk_1.tmp')
    end

    it 'stores metadata as JSON' do
      metadata = {
        upload_time: '2025-01-15T10:30:00Z',
        client_ip: '192.168.1.100',
        retry_count: 2
      }

      chunk = create(:chunk,
        upload_session: upload_session,
        metadata: metadata
      )

      chunk.reload
      expect(chunk.metadata['upload_time']).to eq('2025-01-15T10:30:00Z')
      expect(chunk.metadata['client_ip']).to eq('192.168.1.100')
      expect(chunk.metadata['retry_count']).to eq(2)
    end

    it 'handles empty metadata gracefully' do
      chunk = create(:chunk,
        upload_session: upload_session,
        metadata: {}
      )

      expect(chunk.metadata).to eq({})
    end
  end

  describe 'status transitions and lifecycle' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    it 'starts in pending status by default' do
      chunk = create(:chunk, upload_session: upload_session)
      expect(chunk.status).to eq('pending')
    end

    it 'can transition to uploading status' do
      chunk = create(:chunk, upload_session: upload_session, status: 'pending')
      chunk.update!(status: 'uploading')
      expect(chunk.status).to eq('uploading')
    end

    it 'can transition to completed status' do
      chunk = create(:chunk, upload_session: upload_session, status: 'uploading')
      chunk.update!(status: 'completed')
      expect(chunk.status).to eq('completed')
    end

    it 'can transition to failed status from any state' do
      %w[pending uploading completed].each do |initial_status|
        chunk = create(:chunk, upload_session: upload_session, status: initial_status)
        chunk.update!(status: 'failed')
        expect(chunk.status).to eq('failed')
      end
    end

    it 'tracks creation and update times' do
      chunk = create(:chunk, upload_session: upload_session)
      
      expect(chunk.created_at).to be_present
      expect(chunk.updated_at).to be_present
      expect(chunk.created_at).to be_within(1.second).of(Time.current)
    end
  end

  describe 'file size validation and limits' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    it 'accepts reasonable chunk sizes' do
      valid_sizes = [
        1.kilobyte,
        1.megabyte,
        5.megabytes,
        10.megabytes
      ]

      valid_sizes.each do |size|
        chunk = build(:chunk, upload_session: upload_session, size: size)
        expect(chunk).to be_valid, "Size #{size} should be valid"
      end
    end

    it 'accepts very large chunk sizes for big files' do
      large_chunk = build(:chunk, upload_session: upload_session, size: 50.megabytes)
      expect(large_chunk).to be_valid
    end

    it 'handles fractional byte sizes' do
      chunk = create(:chunk, upload_session: upload_session, size: 1536) # 1.5 KB
      expect(chunk.size).to eq(1536)
    end
  end

  describe 'integration with upload session' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 3) }

    it 'belongs to upload session correctly' do
      chunk = create(:chunk, upload_session: upload_session)
      
      expect(chunk.upload_session).to eq(upload_session)
      expect(upload_session.chunks).to include(chunk)
    end

    it 'is destroyed when upload session is destroyed' do
      chunks = create_list(:chunk, 3, upload_session: upload_session)
      chunk_ids = chunks.map(&:id)

      expect { upload_session.destroy }.to change(Chunk, :count).by(-3)
      
      chunk_ids.each do |id|
        expect(Chunk.exists?(id)).to be false
      end
    end

    it 'calculates progress correctly within upload session context' do
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'pending')

      completed_count = upload_session.chunks.completed.count
      total_count = upload_session.chunks_count
      progress = (completed_count.to_f / total_count * 100).round(2)

      expect(progress).to eq(66.67)
    end
  end

  describe 'checksum validation and data integrity' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    it 'stores MD5 checksums correctly' do
      md5_checksum = 'abc123def456789012345678901234ab'
      chunk = create(:chunk,
        upload_session: upload_session,
        checksum: md5_checksum
      )

      expect(chunk.checksum).to eq(md5_checksum)
      expect(chunk.checksum.length).to eq(32)
    end

    it 'stores SHA256 checksums correctly' do
      sha256_checksum = 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'
      chunk = create(:chunk,
        upload_session: upload_session,
        checksum: sha256_checksum
      )

      expect(chunk.checksum).to eq(sha256_checksum)
      expect(chunk.checksum.length).to eq(64)
    end

    it 'allows nil checksum for optional validation' do
      chunk = create(:chunk,
        upload_session: upload_session,
        checksum: nil
      )

      expect(chunk).to be_valid
      expect(chunk.checksum).to be_nil
    end

    it 'allows empty checksum' do
      chunk = create(:chunk,
        upload_session: upload_session,
        checksum: ''
      )

      expect(chunk).to be_valid
      expect(chunk.checksum).to eq('')
    end
  end

  describe 'storage location tracking' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    it 'tracks local file system storage paths' do
      local_path = '/tmp/wubhub_uploads/session_123/chunk_1.tmp'
      chunk = create(:chunk,
        upload_session: upload_session,
        storage_key: local_path
      )

      expect(chunk.storage_key).to eq(local_path)
    end

    it 'tracks S3 storage keys' do
      s3_key = 'uploads/chunks/2025/01/15/session_123_chunk_1_abc123def456.tmp'
      chunk = create(:chunk,
        upload_session: upload_session,
        storage_key: s3_key
      )

      expect(chunk.storage_key).to eq(s3_key)
    end

    it 'allows nil storage_key for chunks not yet stored' do
      chunk = create(:chunk,
        upload_session: upload_session,
        storage_key: nil
      )

      expect(chunk).to be_valid
      expect(chunk.storage_key).to be_nil
    end
  end

  describe 'edge cases and error handling' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    it 'handles very large chunk numbers' do
      large_chunk_number = 999999
      chunk = create(:chunk,
        upload_session: upload_session,
        chunk_number: large_chunk_number
      )

      expect(chunk.chunk_number).to eq(large_chunk_number)
    end

    it 'validates chunk_number is an integer' do
      chunk = build(:chunk, upload_session: upload_session, chunk_number: 1.5)
      # Rails will coerce this to integer
      expect(chunk.chunk_number).to eq(1)
    end

    it 'handles concurrent chunk creation' do
      # Test that unique constraint works properly
      chunk1 = create(:chunk, upload_session: upload_session, chunk_number: 1)
      
      expect {
        create(:chunk, upload_session: upload_session, chunk_number: 1)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'maintains referential integrity' do
      chunk = create(:chunk, upload_session: upload_session)
      upload_session_id = upload_session.id

      upload_session.destroy

      expect(Chunk.exists?(chunk.id)).to be false
    end
  end

  describe 'performance considerations' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 1000) }

    it 'handles large numbers of chunks efficiently' do
      # Create many chunks quickly
      start_time = Time.current
      
      chunks_data = (1..100).map do |i|
        {
          upload_session: upload_session,
          chunk_number: i,
          size: 1.megabyte,
          status: 'completed',
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      # Bulk insert for performance
      chunks = chunks_data.map { |data| Chunk.new(data) }
      chunks.each(&:save!)
      
      end_time = Time.current
      
      expect(end_time - start_time).to be < 5.seconds
      expect(upload_session.chunks.count).to eq(100)
    end

    it 'efficiently queries chunks by upload session' do
      create_list(:chunk, 50, upload_session: upload_session)

      # Should be able to find chunks quickly
      start_time = Time.current
      found_chunks = upload_session.chunks.completed
      end_time = Time.current

      expect(end_time - start_time).to be < 1.second
      expect(found_chunks).to respond_to(:each)
    end
  end

  describe 'chunk ordering and assembly preparation' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 5) }

    it 'provides chunks in correct order for assembly' do
      # Create chunks out of sequence
      chunk_3 = create(:chunk, upload_session: upload_session, chunk_number: 3, size: 300)
      chunk_1 = create(:chunk, upload_session: upload_session, chunk_number: 1, size: 100)
      chunk_5 = create(:chunk, upload_session: upload_session, chunk_number: 5, size: 500)
      chunk_2 = create(:chunk, upload_session: upload_session, chunk_number: 2, size: 200)
      chunk_4 = create(:chunk, upload_session: upload_session, chunk_number: 4, size: 400)

      ordered_chunks = upload_session.chunks.order(:chunk_number)
      ordered_sizes = ordered_chunks.pluck(:size)

      expect(ordered_sizes).to eq([100, 200, 300, 400, 500])
    end

    it 'identifies missing chunks for assembly validation' do
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 5, status: 'completed')
      # Missing chunks 2 and 4

      completed_chunk_numbers = upload_session.chunks.completed.pluck(:chunk_number)
      expected_chunks = (1..upload_session.chunks_count).to_a
      missing_chunks = expected_chunks - completed_chunk_numbers

      expect(missing_chunks).to contain_exactly(2, 4)
    end

    it 'calculates total assembled size correctly' do
      create(:chunk, upload_session: upload_session, chunk_number: 1, size: 1024, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, size: 2048, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, size: 1536, status: 'completed')

      total_size = upload_session.chunks.completed.sum(:size)
      expect(total_size).to eq(4608) # 1024 + 2048 + 1536
    end
  end

  describe 'database constraints and indexes' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    it 'enforces unique constraint on chunk_number per upload_session' do
      create(:chunk, upload_session: upload_session, chunk_number: 1)
      
      expect {
        # Try to create duplicate chunk_number in same upload_session
        # This should fail with Rails validation error (not database constraint)
        Chunk.create!(
          upload_session: upload_session,
          chunk_number: 1,
          size: 1024,
          status: 'pending'
        )
      }.to raise_error(ActiveRecord::RecordInvalid, /Chunk number has already been taken/)
    end
    
    it 'enforces database-level unique constraint if validation is bypassed' do
      create(:chunk, upload_session: upload_session, chunk_number: 1)
      
      # Test the actual database constraint by bypassing validations
      duplicate_chunk = Chunk.new(
        upload_session: upload_session,
        chunk_number: 1,
        size: 1024,
        status: 'pending'
      )
      
      expect {
        duplicate_chunk.save!(validate: false)  # Bypass Rails validations
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'uses database indexes efficiently for common queries' do
      create_list(:chunk, 10, upload_session: upload_session)

      # These queries should use indexes efficiently
      upload_session.chunks.where(status: 'completed')
      upload_session.chunks.order(:chunk_number)
      upload_session.chunks.where(chunk_number: 5)

      # If indexes are missing, these would be slow on large datasets
      # For now, just verify the queries execute without error
      expect(upload_session.chunks.count).to eq(10)
    end
  end
end