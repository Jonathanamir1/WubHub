require 'rails_helper'

RSpec.describe "Api::V1::Workspaces", type: :request do
  # Add this after your existing DELETE test
  describe "GET /api/v1/workspaces" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "when user is authenticated" do
      it "returns user's accessible workspaces" do
        # User owns some workspaces
        owned_workspace = create(:workspace, user: user, name: "My Studio")
        
        # User is member of another workspace
        other_workspace = create(:workspace, name: "Shared Studio")
        role = create(:role, user: user, roleable: other_workspace, name: 'collaborator')
        
        # User has no access to this workspace
        private_workspace = create(:workspace, name: "Someone Else's Studio")
        
        get "/api/v1/workspaces", headers: headers
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        workspace_names = json_response.map { |w| w['name'] }
        expect(workspace_names).to include("My Studio", "Shared Studio")
      end

      it "returns empty array when user has no workspaces" do
        get "/api/v1/workspaces", headers: headers
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/workspaces"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/workspaces" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "when user is authenticated" do
      it "creates workspace successfully" do
        workspace_params = {
          workspace: {
            name: "New Music Studio",
            description: "My awesome studio workspace",
            workspace_type: "client_based"
          }
        }

        expect {
          post "/api/v1/workspaces", params: workspace_params, headers: headers
        }.to change(Workspace, :count).by(1)

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq("New Music Studio")
        expect(json_response['description']).to eq("My awesome studio workspace")
        
        # Verify user owns the workspace
        created_workspace = Workspace.last
        expect(created_workspace.user).to eq(user)
      end

      it "returns error when name is missing" do
        invalid_params = {
          workspace: {
            name: "",
            description: "Test"
          }
        }

        post "/api/v1/workspaces", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Name can't be blank")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        workspace_params = { workspace: { name: "Test" } }
        post "/api/v1/workspaces", params: workspace_params
        expect(response).to have_http_status(:unauthorized)
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



  describe "workspace privacy integration" do
    let(:artist) { create(:user) }
    let(:producer) { create(:user) }
    let(:fan) { create(:user) }
    let(:token) { generate_token_for_user(producer) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "public workspace discovery" do
      it "allows access to public workspaces even without membership" do
        # Artist creates public workspace
        public_workspace = create(:workspace, user: artist, name: "Public Studio")
        create(:privacy, privatable: public_workspace, user: artist, level: 'public')
        
        # Producer (not a member) should be able to view it
        get "/api/v1/workspaces/#{public_workspace.id}", headers: headers
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq("Public Studio")
      end

      it "lists public workspaces in index for non-members" do
        # Artist creates public workspace  
        public_workspace = create(:workspace, user: artist, name: "Public Studio")
        create(:privacy, privatable: public_workspace, user: artist, level: 'public')
        
        # Artist creates private workspace
        private_workspace = create(:workspace, user: artist, name: "Private Studio")
        
        # Producer should see public workspace in their list
        get "/api/v1/workspaces", headers: headers
        
        json_response = JSON.parse(response.body)
        workspace_names = json_response.map { |w| w['name'] }
        
        expect(workspace_names).to include("Public Studio")
        expect(workspace_names).not_to include("Private Studio")
      end
    end

    context "private workspace restrictions" do
      it "blocks access to private workspaces for non-members" do
        # Artist creates workspace (default private)
        private_workspace = create(:workspace, user: artist, name: "Private Studio")
        
        # Producer (not a member) should be blocked
        get "/api/v1/workspaces/#{private_workspace.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "workspace collaboration" do
      it "shows collaborated workspaces in index" do
        # Artist creates workspace and adds producer as collaborator
        studio = create(:workspace, user: artist, name: "Collaboration Studio")
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        
        # Producer should see it in their workspace list
        get "/api/v1/workspaces", headers: headers
        
        json_response = JSON.parse(response.body)
        workspace_names = json_response.map { |w| w['name'] }
        expect(workspace_names).to include("Collaboration Studio")
      end
    end
  end


end