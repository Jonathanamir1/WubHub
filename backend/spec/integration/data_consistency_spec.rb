require 'rails_helper'

RSpec.describe "Data Consistency", type: :request do
  describe "referential integrity" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it "maintains consistency during cascading deletes" do
      # Create full hierarchy
      post "/api/v1/workspaces",
           params: { workspace: { name: "Consistency Test" } },
           headers: headers
      workspace_id = JSON.parse(response.body)['id']

      post "/api/v1/workspaces/#{workspace_id}/projects",
           params: { project: { title: "Test Project" } },
           headers: headers
      project_id = JSON.parse(response.body)['id']

      post "/api/v1/projects/#{project_id}/track_versions",
           params: { track_version: { title: "Test Track" } },
           headers: headers
      track_id = JSON.parse(response.body)['id']

      post "/api/v1/track_versions/#{track_id}/track_contents",
           params: { track_content: { title: "Test Content", content_type: "audio" } },
           headers: headers
      content_id = JSON.parse(response.body)['id']

      # Add role
      collaborator = create(:user)
      post "/api/v1/projects/#{project_id}/roles",
           params: { role: { name: "collaborator", user_id: collaborator.id } },
           headers: headers
      role_id = JSON.parse(response.body)['id']

      # Count records before deletion
      workspace_count = Workspace.count
      project_count = Project.count
      track_count = TrackVersion.count
      content_count = TrackContent.count
      role_count = Role.count

      # Delete workspace (should cascade)
      delete "/api/v1/workspaces/#{workspace_id}", headers: headers
      expect(response).to have_http_status(:ok)

      # Verify cascading worked correctly
      expect(Workspace.count).to eq(workspace_count - 1)
      expect(Project.count).to eq(project_count - 1)
      expect(TrackVersion.count).to eq(track_count - 1)
      expect(TrackContent.count).to eq(content_count - 1)
      expect(Role.count).to eq(role_count - 1)

      # Verify specific records are gone
      expect(Workspace.exists?(workspace_id)).to be false
      expect(Project.exists?(project_id)).to be false
      expect(TrackVersion.exists?(track_id)).to be false
      expect(TrackContent.exists?(content_id)).to be false
      expect(Role.exists?(role_id)).to be false
    end

    it "handles partial failures without data corruption" do
      # Create workspace
      post "/api/v1/workspaces",
           params: { workspace: { name: "Partial Failure Test" } },
           headers: headers
      workspace_id = JSON.parse(response.body)['id']

      # Try to create project with invalid data, then valid data
      post "/api/v1/workspaces/#{workspace_id}/projects",
           params: { project: { title: "" } },  # Invalid
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      # Database should be unchanged
      workspace = Workspace.find(workspace_id)
      expect(workspace.projects.count).to eq(0)

      # Valid creation should still work
      post "/api/v1/workspaces/#{workspace_id}/projects",
           params: { project: { title: "Valid Project" } },
           headers: headers
      expect(response).to have_http_status(:created)

      workspace.reload
      expect(workspace.projects.count).to eq(1)
    end
  end
end