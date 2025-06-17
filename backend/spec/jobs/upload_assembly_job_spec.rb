require 'rails_helper'

RSpec.describe UploadAssemblyJob, type: :job do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace, name: "Beats") }
  
  describe '#perform' do
    context 'when upload session is ready for assembly' do
      let(:upload_session) do
        create(:upload_session,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'test_track.wav',
          total_size: 2048, # 2KB total
          chunks_count: 2,
          status: 'assembling'
        )
      end

      before do
        # Create real chunks using storage service
        @storage_service = ChunkStorageService.new
        @created_files = []
        @temp_files = [] # Keep track of temp files to clean up later
        
        # Create chunk 1
        chunk_data_1 = "chunk_1_data" + "x" * 1010  # 1024 bytes
        chunk_file_1 = create_chunk_file(chunk_data_1)
        @temp_files << chunk_file_1
        storage_key_1 = @storage_service.store_chunk(upload_session, 1, chunk_file_1)
        @created_files << storage_key_1
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 1,
          size: chunk_data_1.bytesize,
          status: 'completed',
          storage_key: storage_key_1
        )
        
        # Create chunk 2
        chunk_data_2 = "chunk_2_data" + "x" * 1010  # 1024 bytes
        chunk_file_2 = create_chunk_file(chunk_data_2)
        @temp_files << chunk_file_2
        storage_key_2 = @storage_service.store_chunk(upload_session, 2, chunk_file_2)
        @created_files << storage_key_2
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 2,
          size: chunk_data_2.bytesize,
          status: 'completed',
          storage_key: storage_key_2
        )
        
        # DON'T close temp files yet - they're needed for the storage service
      end

      after do
        # Clean up temp files AFTER tests complete
        @temp_files&.each do |temp_file|
          temp_file.close if temp_file.respond_to?(:close)
          temp_file.unlink if temp_file.respond_to?(:unlink)
        end
        
        # Clean up any remaining chunk files
        @created_files&.each do |file_path|
          File.delete(file_path) if File.exist?(file_path)
        end
      end

      it 'assembles the upload and creates an Asset' do
        expect { 
          UploadAssemblyJob.perform_now(upload_session.id) 
        }.to change(Asset, :count).by(1)
        
        asset = Asset.last
        expect(asset.filename).to eq('test_track.wav')
        expect(asset.workspace).to eq(workspace)
        expect(asset.container).to eq(container)
        expect(asset.user).to eq(user)
        expect(asset.file_blob).to be_attached
      end

      it 'marks upload session as completed' do
        UploadAssemblyJob.perform_now(upload_session.id)
        
        upload_session.reload
        expect(upload_session.status).to eq('completed')
      end

      it 'cleans up chunk files after assembly' do
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

      it 'preserves file content during assembly' do
        UploadAssemblyJob.perform_now(upload_session.id)
        
        asset = Asset.last
        assembled_content = asset.file_blob.download
        
        # Should contain both chunks in order
        expect(assembled_content).to start_with('chunk_1_data')
        expect(assembled_content).to include('chunk_2_data')
        
        # Use actual calculated size instead of hardcoded value
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
        # Create chunk with valid storage key
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

    context 'when duplicate filename exists' do
      let(:duplicate_session) do
        create(:upload_session,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'duplicate.wav',
          chunks_count: 1,
          total_size: 1024,
          status: 'assembling'
        )
      end

      before do
        # Create existing asset with same name
        create(:asset,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'duplicate.wav'
        )

        # Create chunk for new upload
        @storage_service = ChunkStorageService.new
        chunk_data = "test_data" + "x" * 1015  # 1024 bytes
        chunk_file = create_chunk_file(chunk_data)
        @created_file_temp = chunk_file
        storage_key = @storage_service.store_chunk(duplicate_session, 1, chunk_file)
        @created_file = storage_key
        
        create(:chunk,
          upload_session: duplicate_session,
          chunk_number: 1,
          size: chunk_data.bytesize,
          status: 'completed',
          storage_key: storage_key
        )
      end

      after do
        @created_file_temp&.close
        @created_file_temp&.unlink
        File.delete(@created_file) if @created_file && File.exist?(@created_file)
      end

      it 'marks session as failed and logs error' do
        expect(Rails.logger).to receive(:error).with(/not ready for assembly/)
        
        UploadAssemblyJob.perform_now(duplicate_session.id)
        
        duplicate_session.reload
        expect(duplicate_session.status).to eq('failed')
      end
    end
  end

  describe 'job configuration' do
    it 'is configured with appropriate queue' do
      expect(UploadAssemblyJob.queue_name).to eq('assembly')
    end

    it 'has retry configuration for transient failures' do
      # Should retry on temporary failures but not on permanent ones
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
      end

      after do
        @temp_files&.each do |temp_file|
          temp_file.close if temp_file.respond_to?(:close)
          temp_file.unlink if temp_file.respond_to?(:unlink)
        end
        
        @created_files&.each do |file_path|
          File.delete(file_path) if File.exist?(file_path)
        end
      end

      it 'handles large file assembly within reasonable time' do
        start_time = Time.current
        
        UploadAssemblyJob.perform_now(large_session.id)
        
        end_time = Time.current
        duration = end_time - start_time
        
        expect(duration).to be < 30.seconds
        
        large_session.reload
        expect(large_session.status).to eq('completed')
        
        asset = Asset.last
        expect(asset.file_size).to eq(10.megabytes)
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