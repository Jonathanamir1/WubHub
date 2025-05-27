require 'rails_helper'

RSpec.describe "Api::V1::TrackVersions", type: :request do
  
  # GET /api/v1/projects/:project_id/track_versions
  describe "GET /api/v1/projects/:project_id/track_versions" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/projects/#{project.id}/track_versions", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns track versions as JSON array" do
        get "/api/v1/projects/#{project.id}/track_versions", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
      end

      it "returns track versions belonging to the project" do
        version1 = create(:track_version, project: project, user: user, title: "Version 1")
        version2 = create(:track_version, project: project, user: user, title: "Version 2")
        
        # Create version in different project (should not appear)
        other_project = create(:project, workspace: workspace, user: user)
        other_version = create(:track_version, project: other_project, user: user, title: "Other Version")
        
        get "/api/v1/projects/#{project.id}/track_versions", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        titles = json_response.map { |v| v['title'] }
        expect(titles).to contain_exactly("Version 1", "Version 2")
      end

      it "orders versions by creation date (newest first)" do
        old_version = create(:track_version, project: project, user: user, title: "Old", created_at: 2.days.ago)
        new_version = create(:track_version, project: project, user: user, title: "New", created_at: 1.day.ago)
        
        get "/api/v1/projects/#{project.id}/track_versions", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.first['title']).to eq("New")
        expect(json_response.last['title']).to eq("Old")
      end

      it "returns empty array when no versions exist" do
        get "/api/v1/projects/#{project.id}/track_versions", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to eq([])
      end
    end

    context "when trying to access another user's project versions" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        get "/api/v1/projects/#{other_project.id}/track_versions", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        project = create(:project)
        get "/api/v1/projects/#{project.id}/track_versions"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # POST /api/v1/projects/:project_id/track_versions
  describe "POST /api/v1/projects/:project_id/track_versions" do
    context "when user owns the project" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }
      let(:valid_version_params) do
        {
          track_version: {
            title: "Demo Version",
            description: "Initial demo recording",
            waveform_data: "[0.1, 0.2, 0.3]",
            metadata: { tempo: 120, key: "C major" }
          }
        }
      end

      it "creates track version successfully" do
        expect {
          post "/api/v1/projects/#{project.id}/track_versions", params: valid_version_params, headers: headers
        }.to change(TrackVersion, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        new_version = project.track_versions.last
        expect(new_version.title).to eq("Demo Version")
        expect(new_version.user).to eq(user)
        expect(new_version.project).to eq(project)
      end

      it "returns the created track version" do
        post "/api/v1/projects/#{project.id}/track_versions", params: valid_version_params, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['title']).to eq("Demo Version")
        expect(json_response['description']).to eq("Initial demo recording")
        expect(json_response['metadata']['tempo']).to eq("120")
      end

      it "returns error when title is missing" do
        invalid_params = {
          track_version: {
            title: "",
            description: "Test"
          }
        }
        
        post "/api/v1/projects/#{project.id}/track_versions", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Title can't be blank")
      end

      it "sets user automatically to current user" do
        post "/api/v1/projects/#{project.id}/track_versions", params: valid_version_params, headers: headers
        
        created_version = TrackVersion.last
        expect(created_version.user).to eq(user)
      end

      it "handles metadata as JSON" do
        complex_metadata = {
          track_version: {
            title: "Test Version",
            metadata: {
              audio: { format: "WAV", sample_rate: 44100 },
              mixing: { eq_settings: { low: -2, mid: 1, high: 0 } },
              tags: ["demo", "needs_vocals"]
            }
          }
        }
        
        post "/api/v1/projects/#{project.id}/track_versions", params: complex_metadata, headers: headers
        
        created_version = TrackVersion.last
        expect(created_version.metadata['audio']['sample_rate']).to eq("44100")
        expect(created_version.metadata['tags']).to include("demo")
      end
    end

    context "when trying to create version in another user's project" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        version_params = { track_version: { title: "Hack Attempt" } }
        
        post "/api/v1/projects/#{other_project.id}/track_versions", params: version_params, headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "does not create the track version" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        
        version_params = { track_version: { title: "Hack Attempt" } }
        
        expect {
          post "/api/v1/projects/#{other_project.id}/track_versions", params: version_params, headers: headers
        }.not_to change(TrackVersion, :count)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        project = create(:project)
        version_params = { track_version: { title: "Test" } }
        
        post "/api/v1/projects/#{project.id}/track_versions", params: version_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /api/v1/track_versions/:id
  describe "GET /api/v1/track_versions/:id" do
    context "when user has access to the track version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns the track version successfully" do
        get "/api/v1/track_versions/#{track_version.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(track_version.id)
        expect(json_response['title']).to eq(track_version.title)
      end

      it "includes associated track contents" do
        content1 = create(:track_content, track_version: track_version, title: "Audio Mix")
        content2 = create(:track_content, track_version: track_version, title: "Lyrics")
        
        get "/api/v1/track_versions/#{track_version.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        content_titles = json_response['track_contents'].map { |c| c['title'] }
        expect(content_titles).to contain_exactly("Audio Mix", "Lyrics")
      end
    end

    context "when trying to view another user's track version" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        get "/api/v1/track_versions/#{other_version.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_version = create(:track_version)
        get "/api/v1/track_versions/#{track_version.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PUT /api/v1/track_versions/:id
  describe "PUT /api/v1/track_versions/:id" do
    context "when user owns the track version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user, title: "Original Title") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "updates track version successfully" do
        update_params = {
          track_version: {
            title: "Updated Title",
            description: "Updated description",
            waveform_data: "[0.5, 0.6, 0.7]"
          }
        }
        
        put "/api/v1/track_versions/#{track_version.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        track_version.reload
        expect(track_version.title).to eq("Updated Title")
        expect(track_version.description).to eq("Updated description")
        expect(track_version.waveform_data).to eq("[0.5, 0.6, 0.7]")
      end

      it "updates metadata correctly" do
        update_params = {
          track_version: {
            metadata: { tempo: 140, key: "D minor", new_field: "test" }
          }
        }
        
        put "/api/v1/track_versions/#{track_version.id}", params: update_params, headers: headers
        
        track_version.reload
        expect(track_version.metadata['tempo']).to eq("140")
        expect(track_version.metadata['key']).to eq("D minor")
        expect(track_version.metadata['new_field']).to eq("test")
      end

      it "returns error for invalid data" do
        invalid_params = {
          track_version: { title: "" }
        }
        
        put "/api/v1/track_versions/#{track_version.id}", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Title can't be blank")
      end
    end

    context "when user owns the project but not the specific version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:other_user) { create(:user) }
      let(:track_version) { create(:track_version, project: project, user: other_user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows project owner to update any version in their project" do
        update_params = {
          track_version: { title: "Updated by Project Owner" }
        }
        
        put "/api/v1/track_versions/#{track_version.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        track_version.reload
        expect(track_version.title).to eq("Updated by Project Owner")
      end
    end

    context "when trying to update another user's track version" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        update_params = { track_version: { title: "Hacked Title" } }
        
        put "/api/v1/track_versions/#{other_version.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:not_found)
        
        other_version.reload
        expect(other_version.title).not_to eq("Hacked Title")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_version = create(:track_version)
        update_params = { track_version: { title: "New Title" } }
        
        put "/api/v1/track_versions/#{track_version.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # DELETE /api/v1/track_versions/:id
  describe "DELETE /api/v1/track_versions/:id" do
    context "when user owns the track version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "deletes track version successfully" do
        delete "/api/v1/track_versions/#{track_version.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(TrackVersion.exists?(track_version.id)).to be false
      end

      it "returns success message" do
        delete "/api/v1/track_versions/#{track_version.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Track version deleted successfully')
      end

      it "deletes associated track contents" do
        content = create(:track_content, track_version: track_version)
        
        expect {
          delete "/api/v1/track_versions/#{track_version.id}", headers: headers
        }.to change(TrackContent, :count).by(-1)
      end

      it "deletes associated comments" do
        comment = create(:comment, track_version: track_version)
        
        expect {
          delete "/api/v1/track_versions/#{track_version.id}", headers: headers
        }.to change(Comment, :count).by(-1)
      end
    end

    context "when user owns the project but not the specific version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:other_user) { create(:user) }
      let(:track_version) { create(:track_version, project: project, user: other_user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows project owner to delete any version in their project" do
        delete "/api/v1/track_versions/#{track_version.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(TrackVersion.exists?(track_version.id)).to be false
      end
    end

    context "when trying to delete another user's track version" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        delete "/api/v1/track_versions/#{other_version.id}", headers: headers
        
        expect(response).to have_http_status(:not_found)
        expect(TrackVersion.exists?(other_version.id)).to be true
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_version = create(:track_version)
        
        delete "/api/v1/track_versions/#{track_version.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end