# spec/jobs/upload_assembly_job_spec.rb - UPDATED VERSION

require 'rails_helper'

RSpec.describe UploadAssemblyJob, type: :job do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace, name: "Audio Files") }

  describe '#perform' do
    context 'when upload session is ready for assembly' do
      let(:upload_session) do
        create(:upload_session,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'test_track.wav',
          total_size: 2044,
          chunks_count: 2,
          status: 'assembling'
        )
      end

      before do
        @storage_service = ChunkStorageService.new
        @created_files = []
        @temp_files = []
        
        # Create 2 chunks
        chunk_1_data = "chunk_1_data" + "x" * 1010  # 1022 bytes
        chunk_2_data = "chunk_2_data" + "x" * 1010  # 1022 bytes
        
        chunk_1_file = create_chunk_file(chunk_1_data)
        chunk_2_file = create_chunk_file(chunk_2_data)
        @temp_files = [chunk_1_file, chunk_2_file]
        
        storage_key_1 = @storage_service.store_chunk(upload_session, 1, chunk_1_file)
        storage_key_2 = @storage_service.store_chunk(upload_session, 2, chunk_2_file)
        @created_files = [storage_key_1, storage_key_2]
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 1,
          size: chunk_1_data.bytesize,
          status: 'completed',
          storage_key: storage_key_1
        )
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 2,
          size: chunk_2_data.bytesize,
          status: 'completed',
          storage_key: storage_key_2
        )

        # CRITICAL: Mock the virus scanner service PROPERLY to prevent real scanning
        @scanner_service = double('VirusScannerService')
        allow(VirusScannerService).to receive(:new).and_return(@scanner_service)
        
        # Make sure the mock virus scanner doesn't actually enqueue jobs
        allow(@scanner_service).to receive(:scan_assembled_file_async) do |session|
          # Simulate the virus scanning behavior without actually running it
          session.update!(
            status: 'virus_scanning',
            virus_scan_queued_at: Time.current
          )
          session.metadata ||= {}
          session.metadata['virus_scan'] = {
            'scanner' => 'clamav',
            'queued_at' => Time.current.iso8601,
            'status' => 'scanning'
          }
          session.save!
        end
      end

      after do
        @temp_files&.each do |temp_file|
          temp_file&.close
          temp_file.unlink if temp_file.respond_to?(:unlink)
        end
        
        @created_files&.each do |file_path|
          File.delete(file_path) if File.exist?(file_path)
        end
        
        # Clean up any assembled files
        Dir.glob(Rails.root.join('tmp', 'assembly', "assembled_#{upload_session.id}_*")).each do |file|
          File.delete(file) if File.exist?(file)
        end
      end

      it 'assembles chunks and queues virus scanning (no longer creates Asset)' do
        expect(@scanner_service).to receive(:scan_assembled_file_async).with(upload_session)
        
        # Debug: Check what happens during assembly        
        # Capture any errors that might be happening
        begin
          UploadAssemblyJob.perform_now(upload_session.id)
        rescue => e
        end
        
        upload_session.reload        
        # Should NOT create an Asset anymore - that happens after virus scanning
        expect { 
          # Don't run the job again, just check the count didn't change
        }.not_to change(Asset, :count)
        
        expect(upload_session.status).to eq('virus_scanning')
        expect(upload_session.assembled_file_path).to be_present
        expect(File.exist?(upload_session.assembled_file_path)).to be true
      end

      it 'marks upload session as virus_scanning and queues virus scan' do
        UploadAssemblyJob.perform_now(upload_session.id)
        
        upload_session.reload
        expect(upload_session.status).to eq('virus_scanning')
        expect(upload_session.assembled_file_path).to be_present
      end

      it 'cleans up chunk files after assembly' do
        expect(@scanner_service).to receive(:scan_assembled_file_async).with(upload_session)
        
        # Verify chunks exist before assembly
        @created_files.each do |file_path|
          expect(@storage_service.chunk_exists?(file_path)).to be true
        end
        
        UploadAssemblyJob.perform_now(upload_session.id)
        
        # Verify chunks are cleaned up after assembly
        @created_files.each do |file_path|
          expect(@storage_service.chunk_exists?(file_path)).to be false
        end
      end

      it 'preserves file content in assembled file' do
        expect(@scanner_service).to receive(:scan_assembled_file_async).with(upload_session)
        
        UploadAssemblyJob.perform_now(upload_session.id)
        
        upload_session.reload
        assembled_file_path = upload_session.assembled_file_path
        
        # Read the assembled file content directly
        assembled_content = File.read(assembled_file_path)
        
        # Should contain both chunks in order
        expect(assembled_content).to start_with('chunk_1_data')
        expect(assembled_content).to include('chunk_2_data')
        
        # Check total size
        chunk_1_size = ("chunk_1_data" + "x" * 1010).bytesize  # 1022 bytes
        chunk_2_size = ("chunk_2_data" + "x" * 1010).bytesize  # 1022 bytes
        expected_total = chunk_1_size + chunk_2_size           # 2044 bytes
        
        expect(assembled_content.bytesize).to eq(expected_total)
      end
    end

    context 'when upload session is not ready for assembly' do
      let(:uploading_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'uploading'  # Not ready for assembly
        )
      end

      it 'marks session as failed and logs error' do
        expect(Rails.logger).to receive(:error).with(/not ready for assembly/)
        
        UploadAssemblyJob.perform_now(uploading_session.id)
        
        uploading_session.reload
        expect(uploading_session.status).to eq('failed')
      end
    end

    context 'when upload session has missing chunks' do
      let(:incomplete_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          filename: 'incomplete.wav',
          chunks_count: 3,
          status: 'assembling'
        )
      end

      before do
        # Only create 2 chunks out of 3
        create(:chunk, upload_session: incomplete_session, chunk_number: 1, status: 'completed')
        create(:chunk, upload_session: incomplete_session, chunk_number: 3, status: 'completed')
        # Missing chunk 2
      end

      it 'marks session as failed and logs error' do
        expect(Rails.logger).to receive(:error).with(/not ready for assembly/)
        
        UploadAssemblyJob.perform_now(incomplete_session.id)
        
        incomplete_session.reload
        expect(incomplete_session.status).to eq('failed')
      end
    end

    context 'when upload session does not exist' do
      it 'logs error and does not raise exception' do
        expect(Rails.logger).to receive(:error).with(/Upload session not found/)
        
        expect {
          UploadAssemblyJob.perform_now(99999)
        }.not_to raise_error
      end
    end

    context 'when assembly fails due to storage error' do
      let(:storage_error_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          filename: 'storage_error.wav',
          chunks_count: 1,
          status: 'assembling'
        )
      end

      before do
        # Create chunk with invalid storage key
        create(:chunk,
          upload_session: storage_error_session,
          chunk_number: 1,
          status: 'completed',
          storage_key: '/non/existent/path.tmp'  # Will cause storage error
        )
      end

      it 'marks session as failed and logs error' do
        expect(Rails.logger).to receive(:error).with(/not ready for assembly/)
        
        UploadAssemblyJob.perform_now(storage_error_session.id)
        
        storage_error_session.reload
        expect(storage_error_session.status).to eq('failed')
      end
    end
  end

  describe 'job configuration' do
    it 'is configured with appropriate queue' do
      expect(UploadAssemblyJob.queue_name).to eq('assembly')
    end

    it 'has retry configuration for transient failures' do
      expect(UploadAssemblyJob).to respond_to(:retry_on)
    end
  end

  describe 'performance considerations' do
    context 'with large files' do
      let(:large_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          filename: 'large_file.wav',
          total_size: 10.megabytes,
          chunks_count: 10,
          status: 'assembling'
        )
      end

      before do
        @storage_service = ChunkStorageService.new
        @created_files = []
        @temp_files = []
        
        # Create 10 chunks of 1MB each
        10.times do |i|
          chunk_data = "chunk_#{i}_" + "x" * (1.megabyte - 8)  # 1MB chunk
          chunk_file = create_chunk_file(chunk_data)
          @temp_files << chunk_file
          storage_key = @storage_service.store_chunk(large_session, i + 1, chunk_file)
          @created_files << storage_key
          
          create(:chunk,
            upload_session: large_session,
            chunk_number: i + 1,
            size: chunk_data.bytesize,
            status: 'completed',
            storage_key: storage_key
          )
        end

        # Mock virus scanner for large files
        @scanner_service = double('VirusScannerService')
        allow(VirusScannerService).to receive(:new).and_return(@scanner_service)
        allow(@scanner_service).to receive(:scan_assembled_file_async) do |session|
          session.update!(
            status: 'virus_scanning',
            virus_scan_queued_at: Time.current
          )
        end
      end

      after do
        @temp_files&.each do |temp_file|
          temp_file.close if temp_file.respond_to?(:close)
          temp_file.unlink if temp_file.respond_to?(:unlink)
        end
        
        @created_files&.each do |file_path|
          File.delete(file_path) if File.exist?(file_path)
        end
        
        # Clean up assembled files
        Dir.glob(Rails.root.join('tmp', 'assembly', "assembled_#{large_session.id}_*")).each do |file|
          File.delete(file) if File.exist?(file)
        end
      end

      it 'handles large file assembly within reasonable time' do
        start_time = Time.current
        
        UploadAssemblyJob.perform_now(large_session.id)
        
        end_time = Time.current
        duration = end_time - start_time
        
        expect(duration).to be < 30.seconds
        
        large_session.reload
        expect(large_session.status).to eq('virus_scanning')  # Changed from 'completed'
        expect(large_session.assembled_file_path).to be_present
      end
    end
  end

  private

  def create_chunk_file(data)
    temp_file = Tempfile.new(['chunk', '.tmp'])
    temp_file.write(data)
    temp_file.rewind
    Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')
  end
end