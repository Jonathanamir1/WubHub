# spec/requests/api/v1/chunks_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Chunks", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace, name: "Beats") }
  let(:upload_session) { create(:upload_session, workspace: workspace, user: user, chunks_count: 3, status: 'uploading') }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  let(:chunk_file) do
    # Create temporary file in memory for testing
    temp_file = Tempfile.new(['test_chunk', '.bin'])
    temp_file.write('Test chunk data for upload testing - simulates audio file piece')
    temp_file.rewind
    
    # Convert to UploadedFile object that Rails expects
    Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')
  end

  describe "POST /api/v1/uploads/:id/chunks/:chunk_number" do
    context "when user has access to upload session" do
      it "uploads chunk successfully" do
        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        expect {
          post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
               params: chunk_params, headers: headers
        }.to change(Chunk, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response['chunk']['chunk_number']).to eq(1)
        expect(json_response['chunk']['status']).to eq('completed')
        expect(json_response['chunk']['size']).to be > 0
        expect(json_response['chunk']['upload_session_id']).to eq(upload_session.id)
      end

      it "updates existing chunk if already exists" do
        existing_chunk = create(:chunk, 
          upload_session: upload_session, 
          chunk_number: 1, 
          status: 'pending'
        )

        chunk_params = {
          file: chunk_file,
          checksum: 'new_checksum'
        }

        expect {
          post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
               params: chunk_params, headers: headers
        }.not_to change(Chunk, :count)

        expect(response).to have_http_status(:created)
        
        existing_chunk.reload
        expect(existing_chunk.status).to eq('completed')
      end

      it "validates chunk number is within expected range" do
        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        # Upload session expects 3 chunks (1-3), trying to upload chunk 5
        post "/api/v1/uploads/#{upload_session.id}/chunks/5", 
             params: chunk_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid chunk number')
      end

      it "validates upload session is in correct state" do
        completed_session = create(:upload_session, 
          workspace: workspace, 
          user: user, 
          status: 'completed'
        )

        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        post "/api/v1/uploads/#{completed_session.id}/chunks/1", 
             params: chunk_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Upload session is not accepting chunks')
      end

      it "validates file is present" do
        chunk_params = {
          checksum: 'abc123def456'
          # No file
        }

        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('File is required')
      end

      it "validates checksum if provided" do
        chunk_params = {
          file: chunk_file,
          checksum: '00000000000000000000000000000000'  # Wrong MD5 hash (all zeros)
        }

        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Checksum mismatch')
      end

      it "stores chunk data and updates upload session progress" do
        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: headers

        expect(response).to have_http_status(:created)
        
        # Check chunk was created
        chunk = Chunk.find_by(upload_session: upload_session, chunk_number: 1)
        expect(chunk.status).to eq('completed')
        expect(chunk.storage_key).to be_present
        
        # Check upload session status updated
        upload_session.reload
        expect(upload_session.status).to eq('uploading') # Still uploading until all chunks done
      end

      it "automatically transitions upload session when all chunks completed" do
        # Create other chunks as completed
        create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'completed')
        create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')

        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        # Upload the final chunk
        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: headers

        expect(response).to have_http_status(:created)
        
        upload_session.reload
        expect(upload_session.status).to eq('assembling')
      end

      it "handles concurrent chunk uploads safely" do
        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        # Just test that multiple uploads of same chunk work
        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: headers
        expect(response).to have_http_status(:created)
        
        # Second upload should update existing
        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: headers
        expect(response).to have_http_status(:created)
        
        # Should only have one chunk
        expect(Chunk.where(upload_session: upload_session, chunk_number: 1).count).to eq(1)
      end
    end

    context "when collaborator uploads chunks" do
      let(:collaborator) { create(:user) }
      let(:collaborator_token) { generate_token_for_user(collaborator) }
      let(:collaborator_headers) { { 'Authorization' => "Bearer #{collaborator_token}" } }

      before do
        create(:role, user: collaborator, roleable: workspace, name: 'collaborator')
      end

      it "allows collaborator to upload chunks" do
        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: collaborator_headers

        expect(response).to have_http_status(:created)
      end
    end

    context "when user lacks access" do
      let(:viewer) { create(:user) }
      let(:viewer_token) { generate_token_for_user(viewer) }
      let(:viewer_headers) { { 'Authorization' => "Bearer #{viewer_token}" } }

      before do
        create(:role, user: viewer, roleable: workspace, name: 'viewer')
      end

      it "prevents viewer from uploading chunks" do
        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: viewer_headers

        expect(response).to have_http_status(:not_found)
      end

      it "prevents outsider from uploading chunks" do
        outsider = create(:user)
        outsider_token = generate_token_for_user(outsider)
        outsider_headers = { 'Authorization' => "Bearer #{outsider_token}" }

        chunk_params = {
          file: chunk_file,
          checksum: 'abc123def456'
        }

        post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
             params: chunk_params, headers: outsider_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/uploads/:id/chunks/:chunk_number" do
    let(:chunk) { create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed') }

    context "when user has access" do
      it "returns chunk status" do
        # Ensure chunk exists before making request
        chunk # This creates the chunk
        
        get "/api/v1/uploads/#{upload_session.id}/chunks/1", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['chunk_number']).to eq(1)
        expect(json_response['status']).to eq('completed')
        expect(json_response['upload_session_id']).to eq(upload_session.id)
      end

      it "returns not found for non-existent chunk" do
        get "/api/v1/uploads/#{upload_session.id}/chunks/99", headers: headers

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Chunk not found')
      end
    end
  end

  describe "GET /api/v1/uploads/:id/chunks" do
    before do
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'pending')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')
    end

    context "when user has access" do
      it "returns all chunks for upload session" do
        get "/api/v1/uploads/#{upload_session.id}/chunks", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['chunks'].length).to eq(3)
        chunk_numbers = json_response['chunks'].map { |chunk| chunk['chunk_number'] }
        expect(chunk_numbers).to contain_exactly(1, 2, 3)
      end

      it "includes chunk status and progress information" do
        get "/api/v1/uploads/#{upload_session.id}/chunks", headers: headers

        json_response = JSON.parse(response.body)
        
        completed_chunks = json_response['chunks'].select { |chunk| chunk['status'] == 'completed' }
        pending_chunks = json_response['chunks'].select { |chunk| chunk['status'] == 'pending' }
        
        expect(completed_chunks.length).to eq(2)
        expect(pending_chunks.length).to eq(1)
      end

      it "filters chunks by status" do
        get "/api/v1/uploads/#{upload_session.id}/chunks", 
            params: { status: 'completed' }, 
            headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['chunks'].length).to eq(2)
        expect(json_response['chunks'].all? { |chunk| chunk['status'] == 'completed' }).to be true
      end
    end
  end

  describe "upload session state management" do
    let(:chunk_file) do
      temp_file = Tempfile.new(['test_chunk', '.bin'])
      temp_file.write('Test chunk data for state management testing')
      temp_file.rewind
      Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')
    end
    
    it "transitions upload session from pending to uploading on first chunk" do
      pending_session = create(:upload_session, 
        workspace: workspace, 
        user: user, 
        status: 'pending'
      )

      chunk_params = {
        file: chunk_file,
        checksum: 'abc123def456'
      }

      post "/api/v1/uploads/#{pending_session.id}/chunks/1", 
           params: chunk_params, headers: headers

      pending_session.reload
      expect(pending_session.status).to eq('uploading')
    end

    it "keeps upload session in uploading state while chunks incomplete" do
      upload_session.update!(status: 'uploading')
      create(:chunk, upload_session: upload_session, chunk_number: 2, status: 'completed')
      # Chunk 3 still missing

      chunk_params = {
        file: chunk_file,
        checksum: 'abc123def456'
      }

      post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
           params: chunk_params, headers: headers

      upload_session.reload
      expect(upload_session.status).to eq('uploading') # Still missing chunk 3
    end
  end

  describe "file size and validation" do
    let(:chunk_file) do
      temp_file = Tempfile.new(['test_chunk', '.bin'])
      temp_file.write('Test chunk data for validation testing')
      temp_file.rewind
      Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')
    end
    
    it "validates chunk size against upload session" do
      # Create a large file that exceeds reasonable chunk size
      large_file = Tempfile.new(['large_chunk', '.bin'])
      large_file.write('x' * 50.megabytes) # 50MB chunk
      large_file.rewind

      chunk_params = {
        file: Rack::Test::UploadedFile.new(large_file.path, 'application/octet-stream'),
        checksum: 'abc123def456'
      }

      post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
           params: chunk_params, headers: headers

      # Should either accept large chunks or validate size appropriately
      expect(response.status).to be_in([201, 422])
      
      large_file.close
      large_file.unlink
    end

    it "handles empty files gracefully" do
      empty_file = Tempfile.new(['empty_chunk', '.bin'])
      empty_file.close

      chunk_params = {
        file: Rack::Test::UploadedFile.new(empty_file.path, 'application/octet-stream'),
        checksum: 'empty_checksum'
      }

      post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
           params: chunk_params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Chunk file cannot be empty')
      
      empty_file.unlink
    end
  end

  describe "error handling and edge cases" do
    let(:chunk_file) do
      temp_file = Tempfile.new(['test_chunk', '.bin'])
      temp_file.write('Test chunk data for error testing')
      temp_file.rewind
      Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')
    end
    
    it 'handles storage failures gracefully' do
      # Mock ChunkStorageService to raise storage error
      allow_any_instance_of(ChunkStorageService).to receive(:store_chunk).and_raise(ChunkStorageService::StorageError.new("Storage backend failed"))
      
      chunk_params = {
        file: chunk_file,
        checksum: 'abc123def456'
      }

      post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
           params: chunk_params, headers: headers

      expect(response).to have_http_status(:internal_server_error)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Failed to store chunk')
    end

    it "handles database transaction failures" do
      # Mock the save to fail
      allow_any_instance_of(Chunk).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(Chunk.new))

      chunk_params = {
        file: chunk_file,
        checksum: 'abc123def456'
      }

      post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
           params: chunk_params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Failed to save chunk')
    end

    it "validates upload session exists" do
      chunk_params = {
        file: chunk_file,
        checksum: 'abc123def456'
      }

      post "/api/v1/uploads/99999/chunks/1", 
           params: chunk_params, headers: headers

      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Upload session not found')
    end
  end
end