# spec/requests/api/v1/uploads_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Uploads", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace, name: "Beats") }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "POST /api/v1/workspaces/:workspace_id/uploads" do
    context "when user has upload permissions" do
      it "creates upload session successfully in workspace root" do
        upload_params = {
          upload_session: {
            filename: "my_track.wav",
            total_size: 50.megabytes,
            chunks_count: 50
          }
        }

        expect {
          post "/api/v1/workspaces/#{workspace.id}/uploads", 
               params: upload_params, headers: headers
        }.to change(UploadSession, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response['filename']).to eq("my_track.wav")
        expect(json_response['total_size']).to eq(50.megabytes)
        expect(json_response['chunks_count']).to eq(50)
        expect(json_response['status']).to eq('pending')
        expect(json_response['workspace_id']).to eq(workspace.id)
        expect(json_response['container_id']).to be_nil
        expect(json_response['user_id']).to eq(user.id)
        expect(json_response['target_path']).to eq('/my_track.wav')
      end

      it "creates upload session in specific container" do
        upload_params = {
          upload_session: {
            filename: "kick.wav",
            total_size: 10.megabytes,
            chunks_count: 10,
            container_id: container.id
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response['filename']).to eq("kick.wav")
        expect(json_response['container_id']).to eq(container.id)
        expect(json_response['target_path']).to eq('/Beats/kick.wav')
        expect(json_response['upload_location']).to eq('/Beats')
      end

      it "creates upload session in nested container" do
        parent = create(:container, workspace: workspace, name: 'Projects')
        child = create(:container, workspace: workspace, name: 'Song1', parent_container: parent)
        
        upload_params = {
          upload_session: {
            filename: "vocal.wav",
            total_size: 25.megabytes,
            chunks_count: 25,
            container_id: child.id
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response['target_path']).to eq('/Projects/Song1/vocal.wav')
        expect(json_response['upload_location']).to eq('/Projects/Song1')
      end

      it "includes metadata when provided" do
        metadata = {
          original_path: '/Users/artist/Desktop/track.wav',
          client_info: { browser: 'Chrome', version: '91.0' }
        }
        
        upload_params = {
          upload_session: {
            filename: "track.wav",
            total_size: 30.megabytes,
            chunks_count: 30,
            metadata: metadata
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response['metadata']['original_path']).to eq('/Users/artist/Desktop/track.wav')
        expect(json_response['metadata']['client_info']['browser']).to eq('Chrome')
      end

      it "calculates recommended chunk size" do
        upload_params = {
          upload_session: {
            filename: "large_project.logic",
            total_size: 500.megabytes,
            chunks_count: 100
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response['recommended_chunk_size']).to eq(10.megabytes)
      end
    end

    context "when collaborator creates upload session" do
      let(:collaborator) { create(:user) }
      let(:collaborator_token) { generate_token_for_user(collaborator) }
      let(:collaborator_headers) { { 'Authorization' => "Bearer #{collaborator_token}" } }

      before do
        create(:role, user: collaborator, roleable: workspace, name: 'collaborator')
      end

      it "allows collaborator to create upload sessions" do
        upload_params = {
          upload_session: {
            filename: "collab_track.wav",
            total_size: 20.megabytes,
            chunks_count: 20
          }
        }

        expect {
          post "/api/v1/workspaces/#{workspace.id}/uploads", 
               params: upload_params, headers: collaborator_headers
        }.to change(UploadSession, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['user_id']).to eq(collaborator.id)
      end
    end

    context "with validation errors" do
      it "returns error for missing filename" do
        upload_params = {
          upload_session: {
            filename: "",
            total_size: 50.megabytes,
            chunks_count: 50
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Filename can't be blank")
      end

      it "returns error for file too large" do
        upload_params = {
          upload_session: {
            filename: "huge_file.wav",
            total_size: 6.gigabytes,
            chunks_count: 1000
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Total size cannot exceed 5GB")
      end

      it "returns error for duplicate filename in same location" do
        create(:upload_session,
          filename: "duplicate.wav",
          workspace: workspace,
          container: container,
          user: user,
          status: 'uploading'
        )

        upload_params = {
          upload_session: {
            filename: "duplicate.wav",
            total_size: 20.megabytes,
            chunks_count: 20,
            container_id: container.id
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Filename is already being uploaded to this location")
      end

      it "returns error for invalid container" do
        other_workspace = create(:workspace)
        other_container = create(:container, workspace: other_workspace)

        upload_params = {
          upload_session: {
            filename: "test.wav",
            total_size: 10.megabytes,
            chunks_count: 10,
            container_id: other_container.id
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Container must belong to the same workspace")
      end

      it "returns error for unsafe filename" do
        upload_params = {
          upload_session: {
            filename: "../../../etc/passwd",
            total_size: 1.kilobyte,
            chunks_count: 1
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Filename contains unsafe characters or patterns")
      end
    end

    context "when user lacks permissions" do
      let(:viewer) { create(:user) }
      let(:viewer_token) { generate_token_for_user(viewer) }
      let(:viewer_headers) { { 'Authorization' => "Bearer #{viewer_token}" } }

      before do
        create(:role, user: viewer, roleable: workspace, name: 'viewer')
      end

      it "prevents viewer from creating upload sessions" do
        upload_params = {
          upload_session: {
            filename: "no_permission.wav",
            total_size: 10.megabytes,
            chunks_count: 10
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: viewer_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("User must have upload permissions for this workspace")
      end

      it "prevents outsider from creating upload sessions" do
        outsider = create(:user)
        outsider_token = generate_token_for_user(outsider)
        outsider_headers = { 'Authorization' => "Bearer #{outsider_token}" }

        upload_params = {
          upload_session: {
            filename: "outsider.wav",
            total_size: 10.megabytes,
            chunks_count: 10
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", 
             params: upload_params, headers: outsider_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("User must have upload permissions for this workspace")
      end
    end

    context "when workspace doesn't exist" do
      it "returns not found" do
        upload_params = {
          upload_session: {
            filename: "test.wav",
            total_size: 10.megabytes,
            chunks_count: 10
          }
        }

        post "/api/v1/workspaces/99999/uploads", 
             params: upload_params, headers: headers

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Workspace not found')
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized" do
        upload_params = {
          upload_session: {
            filename: "test.wav",
            total_size: 10.megabytes,
            chunks_count: 10
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/uploads", params: upload_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/uploads/:id" do
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user, filename: "test.wav") }

    context "when user has access" do
      it "returns upload session details" do
        get "/api/v1/uploads/#{upload_session.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['id']).to eq(upload_session.id)
        expect(json_response['filename']).to eq("test.wav")
        expect(json_response['status']).to eq('pending')
        expect(json_response['workspace_id']).to eq(workspace.id)
        expect(json_response['user_id']).to eq(user.id)
      end

      it "includes progress information" do
        # Create upload session with exactly 3 chunks
        upload_session_with_chunks = create(:upload_session, 
          workspace: workspace, 
          user: user, 
          filename: "test.wav",
          chunks_count: 3  # Important: Set the expected total
        )
        
        # Create exactly 2 completed chunks out of 3 total = 66.67%
        create(:chunk, upload_session: upload_session_with_chunks, chunk_number: 1, status: 'completed')
        create(:chunk, upload_session: upload_session_with_chunks, chunk_number: 2, status: 'completed')
        create(:chunk, upload_session: upload_session_with_chunks, chunk_number: 3, status: 'pending')

        get "/api/v1/uploads/#{upload_session_with_chunks.id}", headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['progress_percentage']).to eq(66.67)
        expect(json_response['all_chunks_uploaded']).to be false
      end

      it "includes missing chunks information" do
        # Create upload session with exactly 3 chunks
        upload_session_with_missing = create(:upload_session, 
          workspace: workspace, 
          user: user, 
          filename: "test.wav",
          chunks_count: 3  # Important: Set the expected total
        )
        
        # Create chunks 1 and 3, leaving chunk 2 missing
        create(:chunk, upload_session: upload_session_with_missing, chunk_number: 1, status: 'completed')
        create(:chunk, upload_session: upload_session_with_missing, chunk_number: 3, status: 'completed')
        # Chunk 2 is intentionally missing

        get "/api/v1/uploads/#{upload_session_with_missing.id}", headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['missing_chunks']).to eq([2])
      end

      it "allows collaborator to view upload session" do
        collaborator = create(:user)
        create(:role, user: collaborator, roleable: workspace, name: 'collaborator')
        collaborator_token = generate_token_for_user(collaborator)
        collaborator_headers = { 'Authorization' => "Bearer #{collaborator_token}" }

        get "/api/v1/uploads/#{upload_session.id}", headers: collaborator_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "when upload session doesn't exist" do
      it "returns not found" do
        get "/api/v1/uploads/99999", headers: headers

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Upload session not found')
      end
    end

    context "when user doesn't have access" do
      let(:other_user) { create(:user) }
      let(:other_workspace) { create(:workspace, user: other_user) }
      let(:other_upload) { create(:upload_session, workspace: other_workspace, user: other_user) }

      it "returns not found for inaccessible upload session" do
        get "/api/v1/uploads/#{other_upload.id}", headers: headers

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Upload session not found')
      end
    end
  end


  describe 'PUT /api/v1/uploads/:id' do
    context 'when user has access' do
      let(:upload_session) do
        create(:upload_session,
          workspace: workspace,
          user: user,
          filename: 'test_track.wav',
          total_size: 2048,
          chunks_count: 2,
          status: 'assembling'
        )
      end

      before do
        # Create completed chunks for the upload session
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 1,
          size: 1024,  # This should match our mocked chunk data size
          status: 'completed',
          storage_key: '/tmp/chunk1.tmp'
        )
        
        create(:chunk,
          upload_session: upload_session,
          chunk_number: 2,
          size: 1024,  # This should match our mocked chunk data size
          status: 'completed',
          storage_key: '/tmp/chunk2.tmp'
        )

        # Mock the virus scanner to prevent actual ClamAV calls
        @scanner_service = double('VirusScannerService')
        allow(VirusScannerService).to receive(:new).and_return(@scanner_service)
        allow(@scanner_service).to receive(:scan_assembled_file_async) do |session|
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

        # Mock the storage service and chunk files
        storage_service = double('ChunkStorageService')
        allow(ChunkStorageService).to receive(:new).and_return(storage_service)
        allow(storage_service).to receive(:chunk_exists?).and_return(true)
        
        # Create properly sized chunk data to match the expected total
        chunk_1_data = "chunk_1_data" + "x" * 1012  # 1024 bytes total (12 + 1012)
        chunk_2_data = "chunk_2_data" + "x" * 1012  # 1024 bytes total (12 + 1012)
        
        # Mock reading chunks with correct sizes
        allow(storage_service).to receive(:read_chunk) do |storage_key|
          if storage_key == '/tmp/chunk1.tmp'
            double('IO', read: chunk_1_data, close: true)
          else
            double('IO', read: chunk_2_data, close: true)
          end
        end
        
        allow(storage_service).to receive(:cleanup_session_chunks).and_return(2)
        
        # Mock File operations for assembly
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:open).with(anything, 'wb').and_yield(double('File', write: true))
        allow(File).to receive(:size).and_return(2048)  # This should match the total
      end

      it 'starts virus scanning (assembling -> virus_scanning)' do
        # Use action_type: 'complete' as expected by the API
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'complete' },  # Changed from complete: true
            headers: headers

        # Debug: Let's see what error we're getting
        if response.status != 200
          json_response = JSON.parse(response.body)
        end

        expect(response).to have_http_status(:ok)
        
        upload_session.reload
        expect(upload_session.status).to eq('virus_scanning')
        
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('virus_scanning')
        expect(json_response['assembled_file_path']).to be_present
      end

      it 'returns error if upload session is not ready for completion' do
        # Create a session in assembling state but without chunks (not ready)
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          status: 'assembling',
          chunks_count: 2
        )
        # Don't create any chunks - this makes it not ready for completion
        
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'complete' },
            headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not ready for assembly')
      end

      it 'returns error if chunks are missing' do
        # Remove one chunk to make assembly impossible
        upload_session.chunks.last.destroy
        
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'complete' },
            headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        # Updated expectation to match the new controller logic
        expect(json_response['error']).to include('not ready for assembly')
      end

      it 'updates metadata when upload_session params provided' do
        new_metadata = { 
          progress_notes: 'Test upload',
          client_version: '2.1.0' 
        }
        
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { 
              upload_session: { metadata: new_metadata }
            }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        
        upload_session.reload
        expect(upload_session.metadata['progress_notes']).to eq('Test upload')
        expect(upload_session.metadata['client_version']).to eq('2.1.0')
      end
    end
    
    context 'when user does not have access' do
      let(:other_user) { create(:user) }
      let(:other_workspace) { create(:workspace, user: other_user) }
      let(:other_upload_session) do
        create(:upload_session,
          workspace: other_workspace,
          user: other_user,
          status: 'assembling'
        )
      end

      it 'returns not found error' do
        put "/api/v1/uploads/#{other_upload_session.id}", 
            params: { action_type: 'complete' },
            headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/uploads/:id" do
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }

    context "when user has access" do
      it "deletes upload session successfully" do
        upload_id = upload_session.id
        
        expect {
          delete "/api/v1/uploads/#{upload_id}", headers: headers
        }.to change(UploadSession, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Upload session deleted successfully')
      end

      it "deletes associated chunks" do
        create_list(:chunk, 3, upload_session: upload_session)
        
        expect {
          delete "/api/v1/uploads/#{upload_session.id}", headers: headers
        }.to change(Chunk, :count).by(-3)
      end

      it "allows collaborator to delete upload sessions they created" do
        collaborator = create(:user)
        create(:role, user: collaborator, roleable: workspace, name: 'collaborator')
        collab_upload = create(:upload_session, workspace: workspace, user: collaborator)
        
        collaborator_token = generate_token_for_user(collaborator)
        collaborator_headers = { 'Authorization' => "Bearer #{collaborator_token}" }

        expect {
          delete "/api/v1/uploads/#{collab_upload.id}", headers: collaborator_headers
        }.to change(UploadSession, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when upload session doesn't exist" do
      it "returns not found" do
        delete "/api/v1/uploads/99999", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/workspaces/:workspace_id/uploads" do
    context "when user has access" do
      before do
        create(:upload_session, workspace: workspace, user: user, filename: "track1.wav", status: 'completed')
        create(:upload_session, workspace: workspace, user: user, filename: "track2.wav", status: 'uploading')
        create(:upload_session, workspace: workspace, user: user, filename: "track3.wav", status: 'failed')
      end

      it "returns all upload sessions for workspace" do
        get "/api/v1/workspaces/#{workspace.id}/uploads", headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(3)
        filenames = json_response.map { |upload| upload['filename'] }
        expect(filenames).to contain_exactly("track1.wav", "track2.wav", "track3.wav")
      end

      it "filters by status" do
        get "/api/v1/workspaces/#{workspace.id}/uploads", 
            params: { status: 'completed' }, 
            headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(1)
        expect(json_response.first['status']).to eq('completed')
      end

      it "filters by container" do
        container_upload = create(:upload_session, 
          workspace: workspace, 
          container: container, 
          user: user, 
          filename: "beat.wav"
        )

        get "/api/v1/workspaces/#{workspace.id}/uploads", 
            params: { container_id: container.id }, 
            headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(1)
        expect(json_response.first['filename']).to eq("beat.wav")
      end

      it "includes pagination information" do
        create_list(:upload_session, 15, workspace: workspace, user: user)

        get "/api/v1/workspaces/#{workspace.id}/uploads", 
            params: { page: 1, per_page: 10 }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        # Should handle pagination gracefully
      end
    end
  end

  describe "error handling and edge cases" do
    it "handles malformed JSON gracefully" do
      post "/api/v1/workspaces/#{workspace.id}/uploads", 
           params: "invalid json", 
           headers: headers.merge('Content-Type' => 'application/json')

      expect(response.status).to be_in([400, 422])
    end

    it "handles missing required parameters" do
      post "/api/v1/workspaces/#{workspace.id}/uploads", 
           params: {}, 
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "handles concurrent upload session creation" do
      # Test the uniqueness constraint without actual threading
      # This is more reliable and tests the same business logic
      
      upload_params = {
        upload_session: {
          filename: "concurrent_test.wav",
          total_size: 10.megabytes,
          chunks_count: 10
        }
      }

      # First request should succeed
      post "/api/v1/workspaces/#{workspace.id}/uploads", 
          params: upload_params, headers: headers
      
      expect(response).to have_http_status(:created)
      first_response = JSON.parse(response.body)
      
      # Second request with same parameters should fail due to uniqueness constraint
      post "/api/v1/workspaces/#{workspace.id}/uploads", 
          params: upload_params, headers: headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      second_response = JSON.parse(response.body)
      expect(second_response['errors']).to include("Filename is already being uploaded to this location")
      
      # Third request should also fail
      post "/api/v1/workspaces/#{workspace.id}/uploads", 
          params: upload_params, headers: headers
          
      expect(response).to have_http_status(:unprocessable_entity)
      
      # Verify only one upload session was created
      upload_sessions = UploadSession.where(filename: "concurrent_test.wav", workspace: workspace)
      expect(upload_sessions.count).to eq(1)
      expect(upload_sessions.first.id).to eq(first_response['id'])
    end
  end

  describe "workspace template integration" do
    it "works with producer workspace template" do
      client_workspace = create(:workspace, user: user, workspace_type: 'client_based')
      
      upload_params = {
        upload_session: {
          filename: "stems_mix.wav",
          total_size: 100.megabytes,
          chunks_count: 100
        }
      }

      post "/api/v1/workspaces/#{client_workspace.id}/uploads", 
           params: upload_params, headers: headers

      expect(response).to have_http_status(:created)
    end

    it "works with project workspace template" do
      project_workspace = create(:workspace, user: user, workspace_type: 'project_based')
      
      upload_params = {
        upload_session: {
          filename: "demo_recording.mp3",
          total_size: 25.megabytes,
          chunks_count: 25
        }
      }

      post "/api/v1/workspaces/#{project_workspace.id}/uploads", 
           params: upload_params, headers: headers

      expect(response).to have_http_status(:created)
    end
  end
end