require 'rails_helper'

RSpec.describe "Api::V1::Projects", type: :request do
  
  # GET /api/v1/workspaces/:workspace_id/projects
  describe "GET /api/v1/workspaces/:workspace_id/projects" do
    context "when user is authenticated" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/workspaces/#{workspace.id}/projects", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns projects as JSON array" do
        get "/api/v1/workspaces/#{workspace.id}/projects", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
      end

      it "returns projects belonging to the workspace" do
        # Create projects for this workspace
        project1 = create(:project, workspace: workspace, user: user, title: "Project 1")
        project2 = create(:project, workspace: workspace, user: user, title: "Project 2")
        
        # Create a project in different workspace (should not appear)
        other_workspace = create(:workspace, user: user)
        other_project = create(:project, workspace: other_workspace, user: user, title: "Other Project")
        
        get "/api/v1/workspaces/#{workspace.id}/projects", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        project_titles = json_response.map { |p| p['title'] }
        expect(project_titles).to contain_exactly("Project 1", "Project 2")
      end

      it "returns empty array when no projects exist" do
        get "/api/v1/workspaces/#{workspace.id}/projects", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to eq([])
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        workspace = create(:workspace)
        get "/api/v1/workspaces/#{workspace.id}/projects"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when trying to access another user's workspace projects" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        
        get "/api/v1/workspaces/#{other_workspace.id}/projects", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # POST /api/v1/workspaces/:workspace_id/projects
  describe "POST /api/v1/workspaces/:workspace_id/projects" do
    context "when user is authenticated" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }
      let(:valid_project_params) do
        {
          project: {
            title: "My New Project",
            description: "A test project",
            visibility: "private"
          }
        }
      end

      it "creates project successfully" do
        expect {
          post "/api/v1/workspaces/#{workspace.id}/projects", params: valid_project_params, headers: headers
        }.to change(Project, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        # Get the project we just created
        new_project = workspace.projects.last
        expect(new_project.title).to eq("My New Project")
        expect(new_project.user).to eq(user)
        expect(new_project.workspace).to eq(workspace)
      end

      it "returns the created project in response" do
        post "/api/v1/workspaces/#{workspace.id}/projects", params: valid_project_params, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['title']).to eq("My New Project")
        expect(json_response['description']).to eq("A test project")
        expect(json_response['visibility']).to eq("private")
      end

      it "returns error when title is missing" do
        invalid_params = {
          project: {
            title: "",
            description: "A test project",
            visibility: "private"
          }
        }
        
        post "/api/v1/workspaces/#{workspace.id}/projects", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include("Title can't be blank")
      end

      it "returns error when visibility is invalid" do
        invalid_params = {
          project: {
            title: "My New Project",
            description: "A test project",
            visibility: "invalid_value"
          }
        }
        
        post "/api/v1/workspaces/#{workspace.id}/projects", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include("Visibility is not included in the list")
      end

      it "sets user automatically to current user" do
        post "/api/v1/workspaces/#{workspace.id}/projects", params: valid_project_params, headers: headers
        
        created_project = Project.last
        expect(created_project.user).to eq(user)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        workspace = create(:workspace)
        project_params = { project: { title: "Test" } }
        
        post "/api/v1/workspaces/#{workspace.id}/projects", params: project_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when trying to create project in another user's workspace" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }
      let(:valid_project_params) do
        {
          project: {
            title: "My New Project",
            description: "A test project",
            visibility: "private"
          }
        }
      end

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        
        post "/api/v1/workspaces/#{other_workspace.id}/projects", params: valid_project_params, headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "does not create the project" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        
        expect {
          post "/api/v1/workspaces/#{other_workspace.id}/projects", params: valid_project_params, headers: headers
        }.not_to change(Project, :count)
      end
    end
  end

  # GET /api/v1/projects/:id
  describe "GET /api/v1/projects/:id" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns the project successfully" do
        get "/api/v1/projects/#{project.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(project.id)
        expect(json_response['title']).to eq(project.title)
      end
    end

    context "when trying to view another user's project" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        get "/api/v1/projects/#{other_project.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        project = create(:project)
        get "/api/v1/projects/#{project.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PUT /api/v1/projects/:id
  describe "PUT /api/v1/projects/:id" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user, title: "Original Title") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "updates project successfully" do
        update_params = {
          project: {
            title: "Updated Title",
            description: "Updated description"
          }
        }
        
        put "/api/v1/projects/#{project.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        project.reload
        expect(project.title).to eq("Updated Title")
        expect(project.description).to eq("Updated description")
      end

      it "returns the updated project" do
        update_params = {
          project: { title: "Updated Title" }
        }
        
        put "/api/v1/projects/#{project.id}", params: update_params, headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq("Updated Title")
      end

      it "returns error for invalid data" do
        invalid_params = {
          project: { title: "" }
        }
        
        put "/api/v1/projects/#{project.id}", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end
    end

    context "when trying to update another user's project" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        update_params = { project: { title: "Hacked Title" } }
        
        put "/api/v1/projects/#{other_project.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:not_found)
        
        # Verify project was not changed
        other_project.reload
        expect(other_project.title).not_to eq("Hacked Title")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        project = create(:project)
        update_params = { project: { title: "New Title" } }
        
        put "/api/v1/projects/#{project.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # DELETE /api/v1/projects/:id
  describe "DELETE /api/v1/projects/:id" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "deletes project successfully" do
        delete "/api/v1/projects/#{project.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(Project.exists?(project.id)).to be false
      end

      it "returns success message" do
        delete "/api/v1/projects/#{project.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Project deleted successfully')
      end

      it "deletes associated track versions" do
        track_version = create(:track_version, project: project)
        
        expect {
          delete "/api/v1/projects/#{project.id}", headers: headers
        }.to change(TrackVersion, :count).by(-1)
      end
    end

    context "when trying to delete another user's project" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        delete "/api/v1/projects/#{other_project.id}", headers: headers
        
        expect(response).to have_http_status(:not_found)
        expect(Project.exists?(other_project.id)).to be true
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        project = create(:project)
        
        delete "/api/v1/projects/#{project.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /api/v1/projects/recent
  describe "GET /api/v1/projects/recent" do
    context "when user is authenticated" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns recent projects for the user" do
        workspace = create(:workspace, user: user)
        old_project = create(:project, workspace: workspace, user: user, updated_at: 2.days.ago)
        recent_project = create(:project, workspace: workspace, user: user, updated_at: 1.day.ago)
        
        # Create project for another user (should not appear)
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        get "/api/v1/projects/recent", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(2)
        expect(json_response.first['id']).to eq(recent_project.id)
        expect(json_response.last['id']).to eq(old_project.id)
      end

      it "returns empty array when user has no projects" do
        get "/api/v1/projects/recent", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end

      it "limits results to 10 projects by default" do
        workspace = create(:workspace, user: user)
        15.times { |i| create(:project, workspace: workspace, user: user, title: "Project #{i}") }
        
        get "/api/v1/projects/recent", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(10)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/projects/recent"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end