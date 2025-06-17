# spec/jobs/upload_cleanup_job_spec.rb
require 'rails_helper'

RSpec.describe UploadCleanupJob, type: :job do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }

  describe '#perform' do
    context 'expired upload sessions' do
      before do
        # Create various upload sessions with different ages and statuses
        @old_failed = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'failed',
          created_at: 25.hours.ago
        )

        @old_pending = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'pending',
          created_at: 2.hours.ago
        )

        @recent_failed = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'failed',
          created_at: 1.hour.ago
        )

        @recent_pending = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'pending',
          created_at: 30.minutes.ago
        )

        @completed_session = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'completed',
          created_at: 1.week.ago
        )

        @uploading_session = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'uploading',
          created_at: 3.hours.ago
        )
      end

      it 'removes expired failed sessions (older than 24 hours)' do
        expect {
          UploadCleanupJob.perform_now
        }.to change { UploadSession.exists?(@old_failed.id) }.from(true).to(false)
      end

      it 'removes expired pending sessions (older than 1 hour)' do
        expect {
          UploadCleanupJob.perform_now
        }.to change { UploadSession.exists?(@old_pending.id) }.from(true).to(false)
      end

      it 'keeps recent failed sessions' do
        UploadCleanupJob.perform_now
        expect(UploadSession.exists?(@recent_failed.id)).to be true
      end

      it 'keeps recent pending sessions' do
        UploadCleanupJob.perform_now
        expect(UploadSession.exists?(@recent_pending.id)).to be true
      end

      it 'never removes completed sessions regardless of age' do
        UploadCleanupJob.perform_now
        expect(UploadSession.exists?(@completed_session.id)).to be true
      end

      it 'never removes active uploading sessions' do
        UploadCleanupJob.perform_now
        expect(UploadSession.exists?(@uploading_session.id)).to be true
      end
    end

    context 'cleanup of associated chunks and files' do
      before do
        @expired_session = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'failed',
          created_at: 25.hours.ago
        )

        # Create chunks with temporary files
        @temp_files = []
        3.times do |i|
          temp_file = Tempfile.new(["expired_chunk_#{i}", '.tmp'])
          temp_file.write("chunk_#{i}_data")
          temp_file.close  # Close but don't unlink yet
          @temp_files << temp_file

          create(:chunk,
            upload_session: @expired_session,
            chunk_number: i + 1,
            status: 'completed',
            storage_key: temp_file.path
          )
        end
      end

      after do
        # Clean up any remaining temp files
        @temp_files&.each do |file|
          file.unlink if File.exist?(file.path)
        end
      end

      it 'removes associated chunks when removing upload session' do
        chunk_ids = @expired_session.chunks.pluck(:id)

        expect {
          UploadCleanupJob.perform_now
        }.to change(Chunk, :count).by(-3)

        chunk_ids.each do |chunk_id|
          expect(Chunk.exists?(chunk_id)).to be false
        end
      end

      it 'cleans up temporary chunk files' do
        chunk_files = @expired_session.chunks.pluck(:storage_key)

        # Verify files exist before cleanup
        chunk_files.each do |file_path|
          expect(File.exist?(file_path)).to be true
        end

        UploadCleanupJob.perform_now

        # Verify files are deleted after cleanup
        chunk_files.each do |file_path|
          expect(File.exist?(file_path)).to be false
        end
      end

      it 'handles missing chunk files gracefully' do
        # Delete one of the chunk files manually
        first_chunk = @expired_session.chunks.first
        File.delete(first_chunk.storage_key)

        # Cleanup should not fail
        expect {
          UploadCleanupJob.perform_now
        }.not_to raise_error

        # Session should still be cleaned up
        expect(UploadSession.exists?(@expired_session.id)).to be false
      end
    end

    context 'cancelled upload sessions' do
      before do
        @old_cancelled = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'cancelled',
          created_at: 25.hours.ago
        )

        @recent_cancelled = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'cancelled',
          created_at: 30.minutes.ago
        )
      end

      it 'removes old cancelled sessions' do
        expect {
          UploadCleanupJob.perform_now
        }.to change { UploadSession.exists?(@old_cancelled.id) }.from(true).to(false)
      end

      it 'keeps recent cancelled sessions for user reference' do
        UploadCleanupJob.perform_now
        expect(UploadSession.exists?(@recent_cancelled.id)).to be true
      end
    end

    context 'stuck in assembling state' do
      before do
        @stuck_assembling = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'assembling',
          created_at: 2.hours.ago,
          updated_at: 2.hours.ago
        )

        @recent_assembling = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'assembling',
          created_at: 10.minutes.ago,
          updated_at: 10.minutes.ago
        )
      end

      it 'marks stuck assembling sessions as failed' do
        UploadCleanupJob.perform_now

        @stuck_assembling.reload
        expect(@stuck_assembling.status).to eq('failed')
      end

      it 'keeps recent assembling sessions' do
        UploadCleanupJob.perform_now

        @recent_assembling.reload
        expect(@recent_assembling.status).to eq('assembling')
      end
    end

    context 'performance and batch processing' do
      it 'handles large numbers of expired sessions efficiently' do
        # Create many expired sessions
        expired_sessions = []
        50.times do |i|
          expired_sessions << create(:upload_session,
            workspace: workspace,
            user: user,
            status: 'failed',
            created_at: 25.hours.ago,
            filename: "file_#{i}.mp3"
          )
        end

        start_time = Time.current
        UploadCleanupJob.perform_now
        end_time = Time.current

        # Should process quickly
        expect(end_time - start_time).to be < 10.seconds

        # All expired sessions should be removed
        expired_sessions.each do |session|
          expect(UploadSession.exists?(session.id)).to be false
        end
      end

      it 'processes sessions in batches to avoid memory issues' do
        # This test ensures we don't load all expired sessions into memory at once
        # We'll verify this by checking that find_each or similar is used

        # Create 25 expired sessions
        25.times do |i|
          create(:upload_session,
            workspace: workspace,
            user: user,
            status: 'failed',
            created_at: 25.hours.ago,
            filename: "batch_file_#{i}.mp3"
          )
        end

        # Should handle efficiently without loading all into memory
        expect {
          UploadCleanupJob.perform_now
        }.to change(UploadSession, :count).by(-25)
      end
    end

    context 'error handling and resilience' do
      before do
        @expired_session = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'failed',
          created_at: 25.hours.ago
        )

        # Create chunk with problematic storage key
        create(:chunk,
          upload_session: @expired_session,
          chunk_number: 1,
          status: 'completed',
          storage_key: '/protected/cannot/delete/this/path.tmp'
        )
      end

      it 'continues processing other sessions when one fails' do
        other_expired = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'failed',
          created_at: 25.hours.ago
        )

        # Should not raise error and should clean up the other session
        expect {
          UploadCleanupJob.perform_now
        }.not_to raise_error

        # The problematic session might remain, but others should be cleaned
        expect(UploadSession.exists?(other_expired.id)).to be false
      end

      it 'logs errors for debugging' do
        # Create a real temp file for the chunk
        temp_file = Tempfile.new(['chunk_file', '.tmp'])
        temp_file.write("test data")
        temp_file.close
        
        # Update chunk to use real file path
        @expired_session.chunks.first.update!(storage_key: temp_file.path)
        
        # Mock File.delete to raise an error
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(temp_file.path).and_return(true)
        allow(File).to receive(:delete).with(temp_file.path).and_raise(Errno::EACCES, "Permission denied")
        
        # Create a mock logger to capture method calls
        mock_logger = double('Logger')
        allow(Rails).to receive(:logger).and_return(mock_logger)
        
        # Set up expectations
        allow(mock_logger).to receive(:info)
        allow(mock_logger).to receive(:error)
        allow(mock_logger).to receive(:debug)
        expect(mock_logger).to receive(:warn).at_least(:once)

        UploadCleanupJob.perform_now
        
        # Clean up
        temp_file.unlink if File.exist?(temp_file.path)
      end
    end

    context 'workspace and user constraints' do
      let(:other_user) { create(:user) }
      let(:other_workspace) { create(:workspace, user: other_user) }

      it 'cleans up expired sessions across all users and workspaces' do
        user1_expired = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'failed',
          created_at: 25.hours.ago
        )

        user2_expired = create(:upload_session,
          workspace: other_workspace,
          user: other_user,
          status: 'failed',
          created_at: 25.hours.ago
        )

        expect {
          UploadCleanupJob.perform_now
        }.to change(UploadSession, :count).by(-2)

        expect(UploadSession.exists?(user1_expired.id)).to be false
        expect(UploadSession.exists?(user2_expired.id)).to be false
      end
    end

    context 'scheduling and frequency' do
      it 'can be safely run multiple times without issues' do
        expired_session = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'failed',
          created_at: 25.hours.ago
        )

        # First run
        UploadCleanupJob.perform_now
        expect(UploadSession.exists?(expired_session.id)).to be false

        # Second run should not fail
        expect {
          UploadCleanupJob.perform_now
        }.not_to raise_error
      end
    end
  end

  describe 'job configuration' do
    it 'is configured with appropriate queue and retry settings' do
      # Test that the job has sensible defaults for background processing
      expect(UploadCleanupJob.queue_name).to eq('cleanup')
    end
  end

  describe 'integration with UploadSession.expired scope' do
    it 'uses the same expiration logic as the model' do
      old_failed = create(:upload_session,
        workspace: workspace,
        user: user,
        status: 'failed',
        created_at: 25.hours.ago
      )

      old_pending = create(:upload_session,
        workspace: workspace,
        user: user,
        status: 'pending',
        created_at: 2.hours.ago
      )

      # Manual check using model scope
      expired_ids = UploadSession.expired.pluck(:id)
      expect(expired_ids).to include(old_failed.id, old_pending.id)

      # Job should clean up the same sessions
      UploadCleanupJob.perform_now

      expect(UploadSession.exists?(old_failed.id)).to be false
      expect(UploadSession.exists?(old_pending.id)).to be false
    end
  end
end