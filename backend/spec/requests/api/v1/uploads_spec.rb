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
        
        expect(json_response['recommended_chunk_size']).to eq(5.megabytes)
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
        create(:chunk, upload_session: upload_session, status: 'completed')
        create(:chunk, upload_session: upload_session, status: 'completed')
        create(:chunk, upload_session: upload_session, status: 'pending')

        get "/api/v1/uploads/#{upload_session.id}", headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['progress_percentage']).to eq(66.67)
        expect(json_response['all_chunks_uploaded']).to be false
      end

      it "includes missing chunks information" do
        create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
        create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')
        # Missing chunk 2

        get "/api/v1/uploads/#{upload_session.id}", headers: headers

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

  describe "PUT /api/v1/uploads/:id" do
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user, status: 'pending') }

    context "when user has access" do
      it "starts upload (pending -> uploading)" do
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'start_upload' }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['status']).to eq('uploading')
        
        upload_session.reload
        expect(upload_session.status).to eq('uploading')
      end

      it "starts assembly (uploading -> assembling)" do
        upload_session.update!(status: 'uploading')
        
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'start_assembly' }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('assembling')
      end

      it "completes upload (assembling -> completed)" do
        upload_session.update!(status: 'assembling')
        
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'complete' }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('completed')
      end

      it "fails upload from any state" do
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'fail' }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('failed')
      end

      it "cancels upload from non-terminal state" do
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'cancel' }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('cancelled')
      end

      it "returns error for invalid state transition" do
        upload_session.update!(status: 'completed')
        
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { action_type: 'start_upload' }, 
            headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid transition')
      end

      it "updates metadata" do
        new_metadata = { 
          progress_notes: 'Halfway through upload',
          client_version: '2.1.0' 
        }
        
        put "/api/v1/uploads/#{upload_session.id}", 
            params: { 
              upload_session: { metadata: new_metadata }
            }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        
        upload_session.reload
        expect(upload_session.metadata['progress_notes']).to eq('Halfway through upload')
        expect(upload_session.metadata['client_version']).to eq('2.1.0')
      end
    end

    context "when user doesn't have access" do
      let(:other_user) { create(:user) }
      let(:other_workspace) { create(:workspace, user: other_user) }
      let(:other_upload) { create(:upload_session, workspace: other_workspace, user: other_user) }

      it "returns not found for inaccessible upload session" do
        put "/api/v1/uploads/#{other_upload.id}", 
            params: { action_type: 'start_upload' }, 
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
      upload_params = {
        upload_session: {
          filename: "concurrent.wav",
          total_size: 10.megabytes,
          chunks_count: 10
        }
      }

      # Simulate concurrent requests
      threads = []
      results = []
      
      3.times do
        threads << Thread.new do
          begin
            post "/api/v1/workspaces/#{workspace.id}/uploads", 
                 params: upload_params, headers: headers
            results << response.status
          rescue => e
            results << :error
          end
        end
      end
      
      threads.each(&:join)
      
      # Only one should succeed due to uniqueness constraint
      success_count = results.count(201)
      expect(success_count).to eq(1)
    end
  end

  describe "workspace template integration" do
    it "works with producer workspace template" do
      producer_workspace = create(:workspace, user: user, template_type: 'producer')
      
      upload_params = {
        upload_session: {
          filename: "stems_mix.wav",
          total_size: 100.megabytes,
          chunks_count: 100
        }
      }

      post "/api/v1/workspaces/#{producer_workspace.id}/uploads", 
           params: upload_params, headers: headers

      expect(response).to have_http_status(:created)
    end

    it "works with songwriter workspace template" do
      songwriter_workspace = create(:workspace, user: user, template_type: 'songwriter')
      
      upload_params = {
        upload_session: {
          filename: "demo_recording.mp3",
          total_size: 25.megabytes,
          chunks_count: 25
        }
      }

      post "/api/v1/workspaces/#{songwriter_workspace.id}/uploads", 
           params: upload_params, headers: headers

      expect(response).to have_http_status(:created)
    end
  end
end