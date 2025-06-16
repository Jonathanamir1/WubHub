# spec/requests/api/v1/containers_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Containers", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "GET /api/v1/workspaces/:workspace_id/containers" do
    context "when user owns workspace" do
      it "returns all containers in workspace" do
        container1 = create(:container, workspace: workspace, name: "Beats")
        container2 = create(:container, workspace: workspace, name: "Vocals")
        other_workspace_container = create(:container, name: "Other")

        get "/api/v1/workspaces/#{workspace.id}/containers", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json.length).to eq(2)
        names = json.map { |c| c['name'] }
        expect(names).to include("Beats", "Vocals")
        expect(names).not_to include("Other")
      end

      it "returns nested container hierarchy" do
        parent = create(:container, workspace: workspace, name: "Projects")
        child1 = create(:container, workspace: workspace, name: "Song1", parent_container: parent)
        child2 = create(:container, workspace: workspace, name: "Song2", parent_container: parent)
        grandchild = create(:container, workspace: workspace, name: "Stems", parent_container: child1)

        get "/api/v1/workspaces/#{workspace.id}/containers", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        # Should return all containers, not just root level
        expect(json.length).to eq(4)
        paths = json.map { |c| c['path'] }
        expect(paths).to include("/Projects", "/Projects/Song1", "/Projects/Song2", "/Projects/Song1/Stems")
      end

      it "returns empty array when no containers exist" do
        get "/api/v1/workspaces/#{workspace.id}/containers", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end

    context "when user doesn't own workspace" do
      let(:other_user) { create(:user) }
      let(:other_workspace) { create(:workspace, user: other_user) }

      it "returns not found for unauthorized workspace" do
        get "/api/v1/workspaces/#{other_workspace.id}/containers", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user has collaborator access" do
      let(:other_user) { create(:user) }
      let(:shared_workspace) { create(:workspace, user: other_user) }

      before do
        create(:role, user: user, roleable: shared_workspace, name: 'collaborator')
      end

      it "allows access to shared workspace containers" do
        container = create(:container, workspace: shared_workspace, name: "Shared Beats")

        get "/api/v1/workspaces/#{shared_workspace.id}/containers", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.first['name']).to eq("Shared Beats")
      end
    end
  end

  describe "GET /api/v1/containers/:id" do
    let(:container) { create(:container, workspace: workspace, name: "My Folder") }

    context "when user has access" do
      it "returns container details" do
        get "/api/v1/containers/#{container.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['id']).to eq(container.id)
        expect(json['name']).to eq("My Folder")
        expect(json['path']).to eq("/My Folder")
        expect(json['workspace_id']).to eq(workspace.id)
      end

      it "includes child containers and assets" do
        child_container = create(:container, workspace: workspace, parent_container: container, name: "Subfolder")
        asset = create(:asset, workspace: workspace, container: container, user: user, filename: "song.mp3")

        get "/api/v1/containers/#{container.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['child_containers']).to be_present
        expect(json['child_containers'].first['name']).to eq("Subfolder")
        
        expect(json['assets']).to be_present
        expect(json['assets'].first['filename']).to eq("song.mp3")
      end
    end

    context "when container doesn't exist" do
      it "returns not found" do
        get "/api/v1/containers/99999", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/workspaces/:workspace_id/containers" do
    context "when user owns workspace" do
      it "creates container successfully" do
        container_params = {
          container: {
            name: "New Beats Folder"
          }
        }

        expect {
          post "/api/v1/workspaces/#{workspace.id}/containers", 
               params: container_params, headers: headers
        }.to change(Container, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        
        expect(json['name']).to eq("New Beats Folder")
        expect(json['workspace_id']).to eq(workspace.id)
        expect(json['path']).to eq("/New Beats Folder")
        expect(json['parent_container_id']).to be_nil
      end

      it "creates nested container successfully" do
        parent_container = create(:container, workspace: workspace, name: "Projects")
        
        container_params = {
          container: {
            name: "Song 1",
            parent_container_id: parent_container.id
          }
        }

        post "/api/v1/workspaces/#{workspace.id}/containers", 
             params: container_params, headers: headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        
        expect(json['name']).to eq("Song 1")
        expect(json['parent_container_id']).to eq(parent_container.id)
        expect(json['path']).to eq("/Projects/Song 1")
      end

      it "returns error for invalid container" do
        container_params = {
          container: { name: "" }
        }

        post "/api/v1/workspaces/#{workspace.id}/containers", 
             params: container_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include("Name can't be blank")
      end

      it "returns error for duplicate name in same location" do
        create(:container, workspace: workspace, name: "Duplicate")
        
        container_params = {
          container: { name: "Duplicate" }
        }

        post "/api/v1/workspaces/#{workspace.id}/containers", 
             params: container_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include("Name has already been taken")
      end
    end

    context "when user doesn't own workspace" do
      let(:other_workspace) { create(:workspace) }

      it "returns not found" do
        container_params = {
          container: { name: "Unauthorized Folder" }
        }

        post "/api/v1/workspaces/#{other_workspace.id}/containers", 
             params: container_params, headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/v1/containers/:id" do
    let(:container) { create(:container, workspace: workspace, name: "Original Name") }

    context "when user has access" do
      it "updates container successfully" do
        update_params = {
          container: { name: "Updated Name" }
        }

        put "/api/v1/containers/#{container.id}", 
            params: update_params, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['name']).to eq("Updated Name")
        expect(json['path']).to eq("/Updated Name")
        
        container.reload
        expect(container.name).to eq("Updated Name")
      end

      it "updates nested container path correctly" do
        parent = create(:container, workspace: workspace, name: "Projects")
        child = create(:container, workspace: workspace, name: "Original", parent_container: parent)
        
        update_params = {
          container: { name: "Updated Song" }
        }

        put "/api/v1/containers/#{child.id}", 
            params: update_params, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['path']).to eq("/Projects/Updated Song")
      end

      it "returns error for invalid update" do
        update_params = {
          container: { name: "" }
        }

        put "/api/v1/containers/#{container.id}", 
            params: update_params, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /api/v1/containers/:id" do
    let(:container) { create(:container, workspace: workspace, name: "To Delete") }

    context "when user has access" do
      it "deletes container successfully" do
        container_id = container.id

        expect {
          delete "/api/v1/containers/#{container_id}", headers: headers
        }.to change(Container, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Container deleted successfully')
      end

      it "deletes container with all nested contents" do
        child_container = create(:container, workspace: workspace, parent_container: container)
        asset = create(:asset, workspace: workspace, container: container, user: user)

        expect {
          delete "/api/v1/containers/#{container.id}", headers: headers
        }.to change(Container, :count).by(-2)  # Parent and child
         .and change(Asset, :count).by(-1)     # Asset in container
      end
    end
  end

  describe "GET /api/v1/workspaces/:workspace_id/tree" do
    context "when user has access" do
      it "returns complete folder tree structure" do
        # Create nested structure
        beats = create(:container, workspace: workspace, name: "Beats")
        vocals = create(:container, workspace: workspace, name: "Vocals")
        projects = create(:container, workspace: workspace, name: "Projects")
        song1 = create(:container, workspace: workspace, name: "Song 1", parent_container: projects)
        stems = create(:container, workspace: workspace, name: "Stems", parent_container: song1)
        
        # Add some files
        create(:asset, workspace: workspace, container: beats, user: user, filename: "kick.wav")
        create(:asset, workspace: workspace, container: vocals, user: user, filename: "lead.wav")
        create(:asset, workspace: workspace, container: nil, user: user, filename: "master.mp3") # Root file

        get "/api/v1/workspaces/#{workspace.id}/tree", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        # Should return hierarchical structure
        expect(json['containers']).to be_present
        expect(json['assets']).to be_present  # Root level assets
        
        # Check that nested structure is preserved
        projects_container = json['containers'].find { |c| c['name'] == 'Projects' }
        expect(projects_container['child_containers']).to be_present
        expect(projects_container['child_containers'].first['name']).to eq('Song 1')
      end
    end
  end
end