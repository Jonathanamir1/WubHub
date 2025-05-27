require 'rails_helper'

RSpec.describe "Api::V1::Workspaces", type: :request do
  describe "GET /api/v1/workspaces" do
    context "when user is authenticated" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/workspaces", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns workspaces as JSON array" do
        get "/api/v1/workspaces", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
      end
      it "returns user's accessible workspaces" do
        # Create some workspaces for our user
        workspace1 = create(:workspace, user: user, name: "My First Workspace")
        workspace2 = create(:workspace, user: user, name: "My Second Workspace")
        
        # Create a workspace for another user (should not be returned)
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user, name: "Other User's Workspace")
        
        get "/api/v1/workspaces", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        workspace_names = json_response.map { |ws| ws['name'] }
        expect(workspace_names).to contain_exactly("My First Workspace", "My Second Workspace")
      end

    end
    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/workspaces"
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message" do
        get "/api/v1/workspaces"
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('Unauthorized')
      end
    end

    context "Creating a workspace" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }
      let(:valid_workspace_params) do
        {
          workspace: {
            name: "My New Workspace",
            description: "A test workspace",
            visibility: "private"
          }
        }
      end

      it "returns success status" do
        post "/api/v1/workspaces", params: valid_workspace_params, headers: headers
        expect(response).to have_http_status(:created)
      end

      it "returns error messages when name is missing" do
        invalid_params = {
          workspace: {
            name: "",
            description: "A test workspace", 
            visibility: "private"
          }
        }
        
        post "/api/v1/workspaces", params: invalid_params, headers: headers
        
        # Check the status code
        expect(response).to have_http_status(:unprocessable_entity)
        
        # Parse the JSON response from the server
        json_response = JSON.parse(response.body)
        
        # Check what's in the response body
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include("Name can't be blank")
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
      it "returns forbidden status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user, name: "Not Mine")
        
        update_params = {
          workspace: { name: "Hacked Name" }
        }
        
        # YOUR TURN: Complete this test
        # 1. Try to update other_workspace with current user's token
        put "/api/v1/workspaces/#{other_workspace.id}", params: update_params, headers: headers

        # 2. What status code should this return?
        expect(response).to have_http_status(:forbidden)
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

  

  private

  def generate_token_for_user(user)
    payload = {
      user_id: user.id,
      iat: Time.now.to_i,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end
end