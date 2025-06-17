# spec/services/upload_assembler_spec.rb
require 'rails_helper'

RSpec.describe UploadAssembler, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace, name: "Beats") }
  
  describe '#assemble!' do
    context 'when all chunks are present and valid' do
      let(:chunk_data_0) { "chunk_0_data" + "x" * 1016 }  # 1028 bytes
      let(:chunk_data_1) { "chunk_1_data" + "x" * 1016 }  # 1028 bytes  
      let(:chunk_data_2) { "chunk_2_data" + "x" * 1016 }  # 1028 bytes
      let(:total_size) { chunk_data_0.bytesize + chunk_data_1.bytesize + chunk_data_2.bytesize }  # 3084 bytes
      
      let(:upload_session) do
        create(:upload_session,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'track.wav',
          total_size: total_size,  # Use calculated total
          chunks_count: 3,
          status: 'assembling'
        )
      end

      before do
        @temp_files = []
        
        # Create chunk 0
        temp_file_0 = Tempfile.new(["chunk_0", '.tmp'])
        temp_file_0.write(chunk_data_0)
        temp_file_0.rewind
        @temp_files << temp_file_0
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 1,
          size: chunk_data_0.bytesize,
          status: 'completed',
          storage_key: temp_file_0.path
        )
        
        # Create chunk 1
        temp_file_1 = Tempfile.new(["chunk_1", '.tmp'])
        temp_file_1.write(chunk_data_1)
        temp_file_1.rewind
        @temp_files << temp_file_1
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 2,
          size: chunk_data_1.bytesize,
          status: 'completed',
          storage_key: temp_file_1.path
        )
        
        # Create chunk 2
        temp_file_2 = Tempfile.new(["chunk_2", '.tmp'])
        temp_file_2.write(chunk_data_2)
        temp_file_2.rewind
        @temp_files << temp_file_2
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 3,
          size: chunk_data_2.bytesize,
          status: 'completed',
          storage_key: temp_file_2.path
        )
      end

      after do
        @temp_files&.each(&:close)
        @temp_files&.each(&:unlink)
      end

      it 'creates an Asset from the assembled chunks' do
        assembler = UploadAssembler.new(upload_session)
        
        expect { assembler.assemble! }.to change(Asset, :count).by(1)
        
        asset = Asset.last
        expect(asset.filename).to eq('track.wav')
        expect(asset.workspace).to eq(workspace)
        expect(asset.container).to eq(container)
        expect(asset.user).to eq(user)
        expect(asset.file_size).to eq(total_size)
      end

      it 'attaches the assembled file to the Asset' do
        assembler = UploadAssembler.new(upload_session)
        assembler.assemble!
        
        asset = Asset.last
        expect(asset.file_blob).to be_attached
        expect(asset.file_blob.filename.to_s).to eq('track.wav')
        expect(asset.file_blob.byte_size).to eq(total_size)
      end

      it 'marks upload session as completed' do
        assembler = UploadAssembler.new(upload_session)
        assembler.assemble!
        
        upload_session.reload
        expect(upload_session.status).to eq('completed')
      end

      it 'cleans up chunk files after assembly' do
        chunk_paths = upload_session.chunks.pluck(:storage_key)
        
        assembler = UploadAssembler.new(upload_session)
        assembler.assemble!
        
        # Temporary files should be cleaned up
        chunk_paths.each do |path|
          expect(File.exist?(path)).to be false
        end
      end

      it 'preserves chunk order during assembly' do
        assembler = UploadAssembler.new(upload_session)
        assembler.assemble!
        
        asset = Asset.last
        
        # Read the assembled file content
        assembled_content = asset.file_blob.download
        
        # Should contain chunks in correct order
        expect(assembled_content).to start_with('chunk_0_data')
        expect(assembled_content).to include('chunk_1_data')
        expect(assembled_content).to end_with('chunk_2_data' + 'x' * 1016)
      end

      it 'extracts correct file metadata' do
        assembler = UploadAssembler.new(upload_session)
        assembler.assemble!
        
        asset = Asset.last
        expect(asset.content_type).to eq('audio/wav')
        expect(asset.file_size).to eq(total_size)
        expect(asset.path).to eq('/Beats/track.wav')
      end
    end

    context 'when upload session is in workspace root' do
      let(:chunk_data_0) { "chunk_0_data" + "x" * 1014 }  # 1024 bytes
      let(:chunk_data_1) { "chunk_1_data" + "x" * 1014 }  # 1024 bytes
      let(:total_size) { chunk_data_0.bytesize + chunk_data_1.bytesize }  # 2048 bytes
      
      let(:root_upload_session) do
        create(:upload_session,
          workspace: workspace,
          container: nil,  # Root level
          user: user,
          filename: 'master.mp3',
          total_size: total_size,
          chunks_count: 2,
          status: 'assembling'
        )
      end

      before do
        @temp_files = []
        
        # Create chunk 0
        temp_file_0 = Tempfile.new(["chunk_0", '.tmp'])
        temp_file_0.write(chunk_data_0)
        temp_file_0.rewind
        @temp_files << temp_file_0
        
        create(:chunk,
          upload_session: root_upload_session,
          chunk_number: 1,
          size: chunk_data_0.bytesize,
          status: 'completed',
          storage_key: temp_file_0.path
        )
        
        # Create chunk 1
        temp_file_1 = Tempfile.new(["chunk_1", '.tmp'])
        temp_file_1.write(chunk_data_1)
        temp_file_1.rewind
        @temp_files << temp_file_1
        
        create(:chunk,
          upload_session: root_upload_session,
          chunk_number: 2,
          size: chunk_data_1.bytesize,
          status: 'completed',
          storage_key: temp_file_1.path
        )
      end

      after do
        @temp_files&.each(&:close)
        @temp_files&.each(&:unlink)
      end

      it 'creates asset in workspace root' do
        assembler = UploadAssembler.new(root_upload_session)
        assembler.assemble!
        
        asset = Asset.last
        expect(asset.container).to be_nil
        expect(asset.path).to eq('/master.mp3')
      end
    end

    context 'when chunks are missing' do
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
        # Chunk 2 is missing
      end

      it 'raises an error and marks session as failed' do
        assembler = UploadAssembler.new(incomplete_session)
        
        expect { assembler.assemble! }.to raise_error(UploadAssembler::AssemblyError, /Missing chunks/)
        
        incomplete_session.reload
        expect(incomplete_session.status).to eq('failed')
      end
    end

    context 'when chunk files are corrupted or missing' do
      let(:corrupted_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          filename: 'corrupted.wav',
          chunks_count: 2,
          status: 'assembling'
        )
      end

      before do
        create(:chunk,
          upload_session: corrupted_session,
          chunk_number: 1,
          status: 'completed',
          storage_key: '/non/existent/path/chunk1.tmp'
        )
        create(:chunk,
          upload_session: corrupted_session,
          chunk_number: 2,
          status: 'completed',
          storage_key: '/non/existent/path/chunk2.tmp'
        )
      end

      it 'raises an error and marks session as failed' do
        assembler = UploadAssembler.new(corrupted_session)
        
        expect { assembler.assemble! }.to raise_error(UploadAssembler::AssemblyError, /Chunk file not found/)
        
        corrupted_session.reload
        expect(corrupted_session.status).to eq('failed')
      end
    end

    context 'when duplicate filename would be created' do
      let(:chunk_data) { 'test_data' }
      let(:duplicate_session) do
        create(:upload_session,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'existing.wav',
          chunks_count: 1,
          total_size: chunk_data.bytesize,
          status: 'assembling'
        )
      end

      before do
        # Create existing asset with same name
        create(:asset,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'existing.wav'
        )

        # Create chunk for new upload
        temp_file = Tempfile.new(['chunk', '.tmp'])
        temp_file.write(chunk_data)
        temp_file.rewind
        @temp_file = temp_file
        
        create(:chunk,
          upload_session: duplicate_session,
          chunk_number: 1,
          size: chunk_data.bytesize,
          status: 'completed',
          storage_key: temp_file.path
        )
      end

      after do
        @temp_file&.close
        @temp_file&.unlink
      end

      it 'raises an error and marks session as failed' do
        assembler = UploadAssembler.new(duplicate_session)
        
        expect { assembler.assemble! }.to raise_error(UploadAssembler::AssemblyError, /Filename already exists/)
        
        duplicate_session.reload
        expect(duplicate_session.status).to eq('failed')
      end
    end

    context 'when upload session is not in assembling state' do
      let(:wrong_state_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'uploading'  # Wrong state
        )
      end

      it 'raises an error' do
        assembler = UploadAssembler.new(wrong_state_session)
        
        expect { assembler.assemble! }.to raise_error(UploadAssembler::AssemblyError, /not ready for assembly/)
      end
    end

    context 'when file size validation fails' do
      let(:size_mismatch_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          filename: 'size_test.wav',
          total_size: 5000,  # Expects 5000 bytes
          chunks_count: 2,
          status: 'assembling'
        )
      end

      before do
        @temp_files = []
        
        # Create chunks that total 2048 bytes, not 5000
        chunk_data_0 = "chunk_0" + "x" * 1020  # 1024 bytes
        chunk_data_1 = "chunk_1" + "x" * 1020  # 1024 bytes
        
        temp_file_0 = Tempfile.new(["chunk_0", '.tmp'])
        temp_file_0.write(chunk_data_0)
        temp_file_0.rewind
        @temp_files << temp_file_0
        
        temp_file_1 = Tempfile.new(["chunk_1", '.tmp'])
        temp_file_1.write(chunk_data_1)
        temp_file_1.rewind
        @temp_files << temp_file_1
        
        create(:chunk,
          upload_session: size_mismatch_session,
          chunk_number: 1,
          size: chunk_data_0.bytesize,
          status: 'completed',
          storage_key: temp_file_0.path
        )
        
        create(:chunk,
          upload_session: size_mismatch_session,
          chunk_number: 2,
          size: chunk_data_1.bytesize,
          status: 'completed',
          storage_key: temp_file_1.path
        )
      end

      after do
        @temp_files&.each(&:close)
        @temp_files&.each(&:unlink)
      end

      it 'raises an error and marks session as failed' do
        assembler = UploadAssembler.new(size_mismatch_session)
        
        expect { assembler.assemble! }.to raise_error(UploadAssembler::AssemblyError, /File size mismatch/)
        
        size_mismatch_session.reload
        expect(size_mismatch_session.status).to eq('failed')
      end
    end
  end

  describe '#can_assemble?' do
    let(:upload_session) { create(:upload_session, chunks_count: 3, status: 'assembling') }

    it 'returns true when all chunks are completed' do
      # Create chunks with explicit chunk numbers
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')
      
      assembler = UploadAssembler.new(upload_session)
      expect(assembler.can_assemble?).to be true
    end

    it 'returns false when chunks are missing' do
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')
      # Missing chunk 2
      
      assembler = UploadAssembler.new(upload_session)
      expect(assembler.can_assemble?).to be false
    end

    it 'returns false when session is not in assembling state' do
      upload_session.update!(status: 'uploading')
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')
      
      assembler = UploadAssembler.new(upload_session)
      expect(assembler.can_assemble?).to be false
    end
  end

  describe '#assembly_status' do
    let(:upload_session) { create(:upload_session, chunks_count: 3, status: 'assembling') }

    it 'returns detailed status information' do
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'pending')
      
      assembler = UploadAssembler.new(upload_session)
      status = assembler.assembly_status
      
      expect(status[:ready]).to be false
      expect(status[:missing_chunks]).to eq([3])
      expect(status[:completed_chunks]).to eq(2)
      expect(status[:total_chunks]).to eq(3)
      expect(status[:session_status]).to eq('assembling')
    end
  end

  describe 'performance considerations' do
    it 'handles large files efficiently' do
      large_session = create(:upload_session,
        workspace: workspace,
        user: user,
        filename: 'large_file.wav',
        total_size: 100.megabytes,
        chunks_count: 100,
        status: 'assembling'
      )

      # Create 100 small chunk files
      @temp_files = []
      100.times do |i|
        temp_file = Tempfile.new(["large_chunk_#{i}", '.tmp'])
        temp_file.write("x" * 1.megabyte)
        temp_file.rewind
        @temp_files << temp_file
        
        create(:chunk,
          upload_session: large_session,
          chunk_number: i + 1,
          size: 1.megabyte,
          status: 'completed',
          storage_key: temp_file.path
        )
      end

      assembler = UploadAssembler.new(large_session)
      
      # Assembly should complete within reasonable time
      start_time = Time.current
      assembler.assemble!
      end_time = Time.current
      
      expect(end_time - start_time).to be < 30.seconds
      
      # Cleanup
      @temp_files.each(&:close)
      @temp_files.each(&:unlink)
    end
  end

  describe 'integration with existing Asset validation' do
    let(:chunk_data) { 'test audio data' }
    
    before do
      @upload_session = UploadSession.create!(
        workspace: workspace,
        container: container,
        user: user,
        filename: 'valid_track.wav',
        chunks_count: 1,
        status: 'assembling',
        total_size: chunk_data.bytesize  # 15 bytes
      )
      
      temp_file = Tempfile.new(['chunk', '.tmp'])
      temp_file.write(chunk_data)
      temp_file.rewind
      @temp_file = temp_file
      
      create(:chunk,
        upload_session: @upload_session,
        chunk_number: 1,
        size: chunk_data.bytesize,
        status: 'completed',
        storage_key: temp_file.path
      )
    end

    after do
      @temp_file&.close
      @temp_file&.unlink
    end

    it 'respects existing Asset validations' do
      assembler = UploadAssembler.new(@upload_session)
      assembler.assemble!
      
      asset = Asset.last
      
      # Should follow existing Asset validation rules
      expect(asset).to be_valid
      expect(asset.filename).to eq('valid_track.wav')
      expect(asset.full_path).to eq('/Beats/valid_track.wav')
    end
  end
end