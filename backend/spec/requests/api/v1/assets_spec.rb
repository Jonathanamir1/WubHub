# spec/requests/api/v1/assets_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Assets", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user, workspace_type: 'client_based') }
  let(:container) { create(:container, workspace: workspace, name: "Beats") }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "GET /api/v1/workspaces/:workspace_id/assets" do
    context "when user has access to workspace" do
      it "returns all assets in workspace" do
        asset1 = create(:asset, workspace: workspace, container: container, user: user, filename: "kick.wav")
        asset2 = create(:asset, workspace: workspace, container: nil, user: user, filename: "master.mp3")
        
        get "/api/v1/workspaces/#{workspace.id}/assets", headers: headers
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        filenames = json_response.map { |a| a['filename'] }
        expect(filenames).to contain_exactly("kick.wav", "master.mp3")
      end

      it "includes file metadata" do
        asset = create(:asset, 
          workspace: workspace, 
          container: container, 
          user: user, 
          filename: "vocals.wav",
          file_size: 5_000_000,
          content_type: "audio/wav"
        )
        
        get "/api/v1/workspaces/#{workspace.id}/assets", headers: headers
        
        json_response = JSON.parse(response.body)
        asset_data = json_response.first
        
        expect(asset_data['filename']).to eq("vocals.wav")
        expect(asset_data['file_size']).to eq(5_000_000)
        expect(asset_data['content_type']).to eq("audio/wav")
        expect(asset_data['path']).to eq("/Beats/vocals.wav")
        expect(asset_data['user_id']).to eq(user.id)
      end

      it "filters assets by container" do
        container_asset = create(:asset, workspace: workspace, container: container, user: user)
        root_asset = create(:asset, workspace: workspace, container: nil, user: user)
        
        get "/api/v1/workspaces/#{workspace.id}/assets", 
            params: { container_id: container.id }, 
            headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(1)
        expect(json_response.first['container_id']).to eq(container.id)
      end

      it "filters assets by file type" do
        audio_asset = create(:asset, workspace: workspace, user: user, content_type: "audio/wav")
        image_asset = create(:asset, workspace: workspace, user: user, content_type: "image/jpeg")
        
        get "/api/v1/workspaces/#{workspace.id}/assets", 
            params: { content_type: "audio/wav" }, 
            headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(1)
        expect(json_response.first['content_type']).to eq("audio/wav")
      end

      it "returns empty array when workspace has no assets" do
        get "/api/v1/workspaces/#{workspace.id}/assets", headers: headers
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end

    context "when user doesn't have access to workspace" do
      let(:other_user) { create(:user) }
      let(:other_workspace) { create(:workspace, user: other_user, workspace_type: 'client_based') }

      it "returns not found" do
        get "/api/v1/workspaces/#{other_workspace.id}/assets", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/containers/:container_id/assets" do
    context "when user has access to container" do
      it "returns assets in specific container" do
        asset1 = create(:asset, workspace: workspace, container: container, user: user, filename: "snare.wav")
        asset2 = create(:asset, workspace: workspace, container: container, user: user, filename: "hihat.wav")
        other_asset = create(:asset, workspace: workspace, container: nil, user: user, filename: "master.wav")
        
        get "/api/v1/containers/#{container.id}/assets", headers: headers
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        filenames = json_response.map { |a| a['filename'] }
        expect(filenames).to contain_exactly("snare.wav", "hihat.wav")
      end
    end
  end

  describe "POST /api/v1/workspaces/:workspace_id/assets" do
    context "when user has access to workspace" do
      it "creates asset in workspace root" do
        file = fixture_file_upload('spec/fixtures/test_audio.wav', 'audio/wav')
        
        asset_params = {
          asset: {
            filename: "new_track.wav"
          },
          file: file
        }

        expect {
          post "/api/v1/workspaces/#{workspace.id}/assets", 
               params: asset_params, headers: headers
        }.to change(Asset, :count).by(1)

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['filename']).to eq("new_track.wav")
        expect(json_response['workspace_id']).to eq(workspace.id)
        expect(json_response['container_id']).to be_nil
        expect(json_response['user_id']).to eq(user.id)
      end

      it "creates asset in specific container" do
        file = fixture_file_upload('spec/fixtures/test_audio.wav', 'audio/wav')
        
        asset_params = {
          asset: {
            filename: "beat.wav",
            container_id: container.id
          },
          file: file
        }

        post "/api/v1/workspaces/#{workspace.id}/assets", 
             params: asset_params, headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['filename']).to eq("beat.wav")
        expect(json_response['container_id']).to eq(container.id)
        expect(json_response['path']).to eq("/Beats/beat.wav")
      end

      it "extracts file metadata from uploaded file" do
        file = fixture_file_upload('spec/fixtures/test_audio.wav', 'audio/wav')
        
        asset_params = {
          asset: { filename: "metadata_test.wav" },
          file: file
        }

        post "/api/v1/workspaces/#{workspace.id}/assets", 
             params: asset_params, headers: headers

        json_response = JSON.parse(response.body)
        expect(json_response['content_type']).to eq('audio/wav')
        expect(json_response['file_size']).to be > 0
      end

      it "returns error for duplicate filename in same location" do
        create(:asset, workspace: workspace, container: container, filename: "duplicate.wav", user: user)
        
        file = fixture_file_upload('spec/fixtures/test_audio.wav', 'audio/wav')
        asset_params = {
          asset: {
            filename: "duplicate.wav",
            container_id: container.id
          },
          file: file
        }

        post "/api/v1/workspaces/#{workspace.id}/assets", 
             params: asset_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Filename has already been taken")
      end

      it "allows same filename in different containers" do
        other_container = create(:container, workspace: workspace, name: "Vocals")
        create(:asset, workspace: workspace, container: container, filename: "sample.wav", user: user)
        
        file = fixture_file_upload('spec/fixtures/test_audio.wav', 'audio/wav')
        asset_params = {
          asset: {
            filename: "sample.wav",
            container_id: other_container.id
          },
          file: file
        }

        post "/api/v1/workspaces/#{workspace.id}/assets", 
             params: asset_params, headers: headers

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe "GET /api/v1/assets/:id" do
    let(:asset) { create(:asset, workspace: workspace, container: container, user: user, filename: "my_track.wav") }

    context "when user has access" do
      it "returns the asset with full details" do
        get "/api/v1/assets/#{asset.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(asset.id)
        expect(json_response['filename']).to eq("my_track.wav")
        expect(json_response['path']).to eq("/Beats/my_track.wav")
        expect(json_response['container_id']).to eq(container.id)
        expect(json_response['workspace_id']).to eq(workspace.id)
      end

      it "includes download URL when file is attached" do
        asset_with_file = create(:asset, :with_attached_file, workspace: workspace, user: user)
        
        get "/api/v1/assets/#{asset_with_file.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['download_url']).to be_present
      end
    end

    context "when user doesn't have access" do
      let(:other_user) { create(:user) }
      let(:other_workspace) { create(:workspace, user: other_user) }
      let(:inaccessible_asset) { create(:asset, workspace: other_workspace, user: other_user) }

      it "returns not found" do
        get "/api/v1/assets/#{inaccessible_asset.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/v1/assets/:id" do
    let(:asset) { create(:asset, workspace: workspace, container: container, user: user, filename: "old_name.wav") }

    context "when user has access" do
      it "updates asset filename" do
        update_params = {
          asset: { filename: "new_name.wav" }
        }
        
        put "/api/v1/assets/#{asset.id}", 
            params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['filename']).to eq("new_name.wav")
        expect(json_response['path']).to eq("/Beats/new_name.wav")
        
        asset.reload
        expect(asset.filename).to eq("new_name.wav")
      end

      it "moves asset to different container" do
        vocals_container = create(:container, workspace: workspace, name: "Vocals")
        
        update_params = {
          asset: { container_id: vocals_container.id }
        }
        
        put "/api/v1/assets/#{asset.id}", 
            params: update_params, headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['container_id']).to eq(vocals_container.id)
        expect(json_response['path']).to eq("/Vocals/old_name.wav")
      end

      it "moves asset to workspace root" do
        update_params = {
          asset: { container_id: nil }
        }
        
        put "/api/v1/assets/#{asset.id}", 
            params: update_params, headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['container_id']).to be_nil
        expect(json_response['path']).to eq("/old_name.wav")
      end
    end
  end

  describe "DELETE /api/v1/assets/:id" do
    let(:asset) { create(:asset, workspace: workspace, container: container, user: user) }

    context "when user has access" do
      it "deletes the asset" do
        asset_id = asset.id
        
        expect {
          delete "/api/v1/assets/#{asset_id}", headers: headers
        }.to change(Asset, :count).by(-1)
        
        expect(response).to have_http_status(:ok)
        expect(Asset.exists?(asset_id)).to be false
      end

      it "deletes asset with attached file" do
        asset_with_file = create(:asset, :with_attached_file, workspace: workspace, user: user)
        
        expect {
          delete "/api/v1/assets/#{asset_with_file.id}", headers: headers
        }.to change(Asset, :count).by(-1)
        
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /api/v1/assets/:id/download" do
    let(:asset) { create(:asset, :with_attached_file, workspace: workspace, user: user, filename: "download_test.wav") }

    context "when user has access" do
      it "provides download redirect" do
        get "/api/v1/assets/#{asset.id}/download", headers: headers
        
        expect(response).to have_http_status(:found)
        expect(response.headers['Location']).to be_present
      end
    end

    context "when asset has no file attached" do
      let(:asset_no_file) { create(:asset, workspace: workspace, user: user) }

      it "returns not found" do
        get "/api/v1/assets/#{asset_no_file.id}/download", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "template-specific asset operations" do
    context "with different workspace templates" do
      it "handles client_based workspace assets" do
        client_based_workspace = create(:workspace, user: user, workspace_type: 'client_based')
        asset = create(:asset, workspace: client_based_workspace, user: user, filename: "stem_mix.wav")
        
        get "/api/v1/assets/#{asset.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "handles client_based workspace assets" do
        client_based = create(:workspace, user: user, workspace_type: 'client_based')
        asset = create(:asset, workspace: client_based, user: user, filename: "demo_recording.mp3")
        
        get "/api/v1/assets/#{asset.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end
  end
end