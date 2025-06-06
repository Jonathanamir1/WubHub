require 'rails_helper'

RSpec.describe "Api::V1::Containers", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "GET /api/v1/workspaces/:workspace_id/containers" do
    it "returns containers for a workspace" do
      workspace = create(:workspace, user: user)  # Make sure user owns workspace
      container = create(:container, workspace: workspace)
      
      get "/api/v1/workspaces/#{workspace.id}/containers", headers: headers
      
      puts "Response status: #{response.status}"
      puts "Response body: #{response.body}"
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first['id']).to eq(container.id)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_id/containers" do
    it "creates a new container in the workspace" do
      workspace = create(:workspace, user: user)
      
      container_params = {
        container: {
          name: "New Beat Pack",
          container_type: "beat_pack", 
          template_level: 1
        }
      }
      
      expect {
        post "/api/v1/workspaces/#{workspace.id}/containers", 
            params: container_params, 
            headers: headers
      }.to change(Container, :count).by(1)
      
      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['name']).to eq("New Beat Pack")
      expect(json_response['workspace_id']).to eq(workspace.id)
    end

      it "returns errors when container creation fails" do
        workspace = create(:workspace, user: user)
        
        invalid_params = {
          container: {
            name: "",  # Invalid - name is required
            container_type: "beat_pack",
            template_level: 1
          }
        }
        
        expect {
          post "/api/v1/workspaces/#{workspace.id}/containers", 
              params: invalid_params, 
              headers: headers
        }.not_to change(Container, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Name can't be blank")
      end
  end

  describe "authorization" do
    it "prevents access to other users' workspace containers" do
      other_user = create(:user)
      other_workspace = create(:workspace, user: other_user)
      create(:container, workspace: other_workspace)
      
      get "/api/v1/workspaces/#{other_workspace.id}/containers", headers: headers
      
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Workspace not found')
    end
    
    it "prevents creating containers in other users' workspaces" do
      other_user = create(:user)
      other_workspace = create(:workspace, user: other_user)
      
      container_params = {
        container: {
          name: "Unauthorized Container",
          container_type: "folder",
          template_level: 1
        }
      }
      
      post "/api/v1/workspaces/#{other_workspace.id}/containers", 
          params: container_params, 
          headers: headers
      
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Workspace not found')
    end
  end
end