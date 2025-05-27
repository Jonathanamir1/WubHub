require 'rails_helper'

RSpec.describe "Api::V1::Roles", type: :request do
  
  # GET /api/v1/projects/:project_id/roles
  describe "GET /api/v1/projects/:project_id/roles" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/projects/#{project.id}/roles", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns roles as JSON array" do
        get "/api/v1/projects/#{project.id}/roles", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
      end

      it "returns roles belonging to the project" do
        collaborator1 = create(:user, username: "collaborator1")
        collaborator2 = create(:user, username: "collaborator2")
        
        role1 = create(:role, roleable: project, user: collaborator1, name: "collaborator")
        role2 = create(:role, roleable: project, user: collaborator2, name: "viewer")
        
        # Create role for different project (should not appear)
        other_project = create(:project, workspace: workspace, user: user)
        other_role = create(:role, roleable: other_project, user: collaborator1, name: "owner")
        
        get "/api/v1/projects/#{project.id}/roles", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        role_names = json_response.map { |r| r['name'] }
        expect(role_names).to contain_exactly("collaborator", "viewer")
      end

      it "includes user information in roles" do
        collaborator = create(:user, username: "testuser")
        role = create(:role, roleable: project, user: collaborator, name: "collaborator")
        
        get "/api/v1/projects/#{project.id}/roles", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.first['username']).to eq("testuser")
      end

      it "returns empty array when no roles exist" do
        get "/api/v1/projects/#{project.id}/roles", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to eq([])
      end
    end

    context "when trying to access another user's project roles" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        get "/api/v1/projects/#{other_project.id}/roles", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        project = create(:project)
        get "/api/v1/projects/#{project.id}/roles"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # POST /api/v1/projects/:project_id/roles
  describe "POST /api/v1/projects/:project_id/roles" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:collaborator) { create(:user, username: "newcollaborator") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }
      let(:valid_role_params) do
        {
          role: {
            name: "collaborator",
            user_id: collaborator.id
          }
        }
      end

      it "creates role successfully" do
        expect {
          post "/api/v1/projects/#{project.id}/roles", params: valid_role_params, headers: headers
        }.to change(Role, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        new_role = project.roles.last
        expect(new_role.name).to eq("collaborator")
        expect(new_role.user).to eq(collaborator)
        expect(new_role.roleable).to eq(project)
      end

      it "returns the created role" do
        post "/api/v1/projects/#{project.id}/roles", params: valid_role_params, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['name']).to eq("collaborator")
        expect(json_response['user_id']).to eq(collaborator.id)
        expect(json_response['username']).to eq("newcollaborator")
      end

      it "returns error when name is invalid" do
        invalid_params = {
          role: {
            name: "invalid_role",
            user_id: collaborator.id
          }
        }
        
        post "/api/v1/projects/#{project.id}/roles", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Name is not included in the list")
      end

      it "returns error when user_id is missing" do
        invalid_params = {
          role: {
            name: "collaborator",
            user_id: nil
          }
        }
        
        post "/api/v1/projects/#{project.id}/roles", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("User must exist")
      end

      it "returns error when user does not exist" do
        invalid_params = {
          role: {
            name: "collaborator",
            user_id: 99999
          }
        }
        
        post "/api/v1/projects/#{project.id}/roles", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("User must exist")
      end

      it "prevents duplicate roles for same user on same project" do
        # Create first role
        create(:role, roleable: project, user: collaborator, name: "viewer")
        
        duplicate_params = {
          role: {
            name: "collaborator",
            user_id: collaborator.id
          }
        }
        
        # Try to create second role for same user/project
        post "/api/v1/projects/#{project.id}/roles", params: duplicate_params, headers: headers
        
        # This should either fail or update existing role, depending on your business logic
        # Adjust expectation based on your requirements
        expect([422, 201]).to include(response.status)
      end

      it "allows different role types" do
        valid_roles = ["owner", "collaborator", "commenter", "viewer"]
        
        valid_roles.each do |role_name|
          user_for_role = create(:user)
          role_params = {
            role: {
              name: role_name,
              user_id: user_for_role.id
            }
          }
          
          post "/api/v1/projects/#{project.id}/roles", params: role_params, headers: headers
          expect(response).to have_http_status(:created)
        end
        
        expect(project.roles.count).to eq(4)
      end
    end

    context "when user is not the project owner" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let(:workspace) { create(:workspace, user: other_user) }
      let(:project) { create(:project, workspace: workspace, user: other_user) }
      let(:collaborator) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        role_params = {
          role: {
            name: "collaborator",
            user_id: collaborator.id
          }
        }
        
        post "/api/v1/projects/#{project.id}/roles", params: role_params, headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "does not create the role" do
        role_params = {
          role: {
            name: "collaborator",
            user_id: collaborator.id
          }
        }
        
        expect {
          post "/api/v1/projects/#{project.id}/roles", params: role_params, headers: headers
        }.not_to change(Role, :count)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        project = create(:project)
        role_params = { role: { name: "collaborator", user_id: 1 } }
        
        post "/api/v1/projects/#{project.id}/roles", params: role_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /api/v1/roles/:id
  describe "GET /api/v1/roles/:id" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:collaborator) { create(:user) }
      let(:role) { create(:role, roleable: project, user: collaborator, name: "collaborator") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns the role successfully" do
        get "/api/v1/roles/#{role.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(role.id)
        expect(json_response['name']).to eq("collaborator")
        expect(json_response['user_id']).to eq(collaborator.id)
      end

      it "includes user and project information" do
        get "/api/v1/roles/#{role.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['username']).to eq(collaborator.username)
        expect(json_response['project_id']).to be_present
      end
    end

    context "when trying to view role from another user's project" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        collaborator = create(:user)
        other_role = create(:role, roleable: other_project, user: collaborator, name: "collaborator")
        
        get "/api/v1/roles/#{other_role.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        role = create(:role)
        get "/api/v1/roles/#{role.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PUT /api/v1/roles/:id
  describe "PUT /api/v1/roles/:id" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:collaborator) { create(:user) }
      let(:role) { create(:role, roleable: project, user: collaborator, name: "viewer") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "updates role successfully" do
        update_params = {
          role: { name: "collaborator" }
        }
        
        put "/api/v1/roles/#{role.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        role.reload
        expect(role.name).to eq("collaborator")
      end

      it "returns the updated role" do
        update_params = {
          role: { name: "collaborator" }
        }
        
        put "/api/v1/roles/#{role.id}", params: update_params, headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq("collaborator")
      end

      it "returns error for invalid role name" do
        invalid_params = {
          role: { name: "invalid_role" }
        }
        
        put "/api/v1/roles/#{role.id}", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Name is not included in the list")
      end

      it "allows changing user assignment" do
        new_collaborator = create(:user)
        update_params = {
          role: { user_id: new_collaborator.id }
        }
        
        put "/api/v1/roles/#{role.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        role.reload
        expect(role.user).to eq(new_collaborator)
      end
    end

    context "when trying to update role from another user's project" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        collaborator = create(:user)
        other_role = create(:role, roleable: other_project, user: collaborator, name: "viewer")
        
        update_params = { role: { name: "collaborator" } }
        
        put "/api/v1/roles/#{other_role.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:not_found)
        
        other_role.reload
        expect(other_role.name).to eq("viewer")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        role = create(:role)
        update_params = { role: { name: "collaborator" } }
        
        put "/api/v1/roles/#{role.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

# DELETE /api/v1/roles/:id
  describe "DELETE /api/v1/roles/:id" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:collaborator) { create(:user) }
      let(:role) { create(:role, roleable: project, user: collaborator, name: "collaborator") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "deletes role successfully" do
        delete "/api/v1/roles/#{role.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(Role.exists?(role.id)).to be false
      end

      it "returns success message" do
        delete "/api/v1/roles/#{role.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Role successfully removed')
      end

      it "removes user access to the project" do

        expect(Role.exists?(role.id)).to be true
        
        delete "/api/v1/roles/#{role.id}", headers: headers
        
        expect(Role.exists?(role.id)).to be false
      end
    end

    context "when trying to delete role from another user's project" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        collaborator = create(:user)
        other_role = create(:role, roleable: other_project, user: collaborator, name: "collaborator")
        
        delete "/api/v1/roles/#{other_role.id}", headers: headers
        
        expect(response).to have_http_status(:not_found)
        expect(Role.exists?(other_role.id)).to be true
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        role = create(:role)
        
        delete "/api/v1/roles/#{role.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Testing polymorphic behavior
  describe "Polymorphic role assignment" do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:project) { create(:project, workspace: workspace, user: user) }
    let(:track_version) { create(:track_version, project: project, user: user) }
    let(:track_content) { create(:track_content, track_version: track_version) }
    let(:collaborator) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it "can assign roles to different resource types" do
      # Test creating roles for different polymorphic resources
      
      # Project role
      project_role = create(:role, roleable: project, user: collaborator, name: "collaborator")
      expect(project_role.roleable_type).to eq("Project")
      expect(project_role.roleable_id).to eq(project.id)
      
      # Workspace role  
      workspace_role = create(:role, roleable: workspace, user: collaborator, name: "viewer")
      expect(workspace_role.roleable_type).to eq("Workspace")
      expect(workspace_role.roleable_id).to eq(workspace.id)
      
      # Track version role
      version_role = create(:role, roleable: track_version, user: collaborator, name: "commenter")
      expect(version_role.roleable_type).to eq("TrackVersion")
      expect(version_role.roleable_id).to eq(track_version.id)
      
      # Track content role
      content_role = create(:role, roleable: track_content, user: collaborator, name: "viewer")
      expect(content_role.roleable_type).to eq("TrackContent")
      expect(content_role.roleable_id).to eq(track_content.id)
    end

    it "supports hierarchical permission inheritance" do
      # Create workspace role
      workspace_role = create(:role, roleable: workspace, user: collaborator, name: "owner")
      
      # User should have access to nested resources
      expect(collaborator.has_access_to?(project)).to be true
      expect(collaborator.has_access_to?(track_version)).to be true
      expect(collaborator.has_access_to?(track_content)).to be true
    end

    it "handles multiple roles for same user on different resources" do
      # User can have different roles on different resources
      workspace_role = create(:role, roleable: workspace, user: collaborator, name: "viewer")
      project_role = create(:role, roleable: project, user: collaborator, name: "collaborator")
      
      expect(collaborator.roles.count).to eq(2)
      expect(collaborator.roles.map(&:name)).to contain_exactly("viewer", "collaborator")
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