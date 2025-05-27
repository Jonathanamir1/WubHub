require 'rails_helper'

RSpec.describe "Api::V1::Workspaces", type: :request do
  # Add this after your existing DELETE test
  describe "GET /api/v1/workspaces/:id" do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user, name: "My Workspace", description: "Test workspace") }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "when user owns the workspace" do
      it "returns the workspace successfully" do
        get "/api/v1/workspaces/#{workspace.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(workspace.id)
        expect(json_response['name']).to eq("My Workspace")
        expect(json_response['description']).to eq("Test workspace")
      end

      it "includes project count" do
        # Create some projects in the workspace
        create_list(:project, 3, workspace: workspace, user: user)
        
        get "/api/v1/workspaces/#{workspace.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['project_count']).to eq(3)
      end
    end

    context "when trying to view another user's workspace" do
      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        
        get "/api/v1/workspaces/#{other_workspace.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when workspace doesn't exist" do
      it "returns not found status" do
        get "/api/v1/workspaces/99999", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/workspaces/#{workspace.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Add workspace visibility tests
  describe "workspace visibility" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "with public workspaces" do
      it "shows public workspaces in index" do
        public_workspace = create(:workspace, user: user, visibility: "public", name: "Public WS")
        private_workspace = create(:workspace, user: user, visibility: "private", name: "Private WS")
        
        get "/api/v1/workspaces", headers: headers
        json_response = JSON.parse(response.body)
        
        workspace_names = json_response.map { |ws| ws['name'] }
        expect(workspace_names).to contain_exactly("Public WS", "Private WS")
      end
    end

    context "with private workspaces" do
      it "only shows user's own private workspaces" do
        my_private = create(:workspace, user: user, visibility: "private", name: "My Private")
        other_private = create(:workspace, user: other_user, visibility: "private", name: "Other Private")
        
        get "/api/v1/workspaces", headers: headers
        json_response = JSON.parse(response.body)
        
        workspace_names = json_response.map { |ws| ws['name'] }
        expect(workspace_names).to contain_exactly("My Private")
        expect(workspace_names).not_to include("Other Private")
      end
    end
  end

  # Add error handling tests
  describe "error handling" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "when deleting workspace with projects" do
      it "deletes workspace and cascades to projects" do
        workspace = create(:workspace, user: user)
        project = create(:project, workspace: workspace, user: user)
        
        expect {
          delete "/api/v1/workspaces/#{workspace.id}", headers: headers
        }.to change(Project, :count).by(-1)
        
        expect(response).to have_http_status(:ok)
        expect(Workspace.exists?(workspace.id)).to be false
      end
    end

    context "with invalid visibility values" do
      it "rejects invalid visibility" do
        invalid_params = {
          workspace: {
            name: "Test Workspace",
            visibility: "invalid_value"
          }
        }
        
        post "/api/v1/workspaces", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Visibility is not included in the list")
      end
    end
  end

  describe "PUT /api/v1/workspaces/:id" do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user, name: "Original Name") }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  
    it "updates the workspace successfully" do
      update_params = {
        workspace: {
          name: "Updated Name"
        }
      }
      
      # YOUR TURN: Fill in the blanks
      # 1. Make the PUT request
      put "/api/v1/workspaces/#{workspace.id}", params: update_params, headers: headers
      # 2. Check the status code
      expect(response).to have_http_status(:ok)
      # 3. Verify the name was updated
      workspace.reload
      expect(workspace.name).to eq("Updated Name")
    end

    context "when trying to update another user's workspace" do
      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user, name: "Not Mine")
        
        update_params = {
          workspace: { name: "Hacked Name" }
        }
        
        # YOUR TURN: Complete this test
        # 1. Try to update other_workspace with current user's token
        put "/api/v1/workspaces/#{other_workspace.id}", params: update_params, headers: headers

        # 2. What status code should this return?
        expect(response).to have_http_status(:not_found)
        # 3. Verify the workspace name was NOT changed
        other_workspace.reload
        expect(other_workspace.name).to eq("Not Mine")
      end
    end  
  end

  describe "DELETE /api/v1/workspaces/:id" do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }
    
    it "deletes the workspace successfully" do
      # YOUR TURN: Complete this test
      # Think about:
      # 1. What HTTP method and route?
      delete "/api/v1/workspaces/#{workspace.id}", headers: headers
      # 2. What status code for successful deletion?
      expect(response).to have_http_status(:ok)
      # 3. How to verify it was actually deleted from database?
      expect(Workspace.exists?(workspace.id)).to be false
    end
  end

end