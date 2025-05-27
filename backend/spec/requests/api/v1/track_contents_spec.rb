require 'rails_helper'

RSpec.describe "Api::V1::TrackContents", type: :request do
  
  # GET /api/v1/track_versions/:track_version_id/track_contents
  describe "GET /api/v1/track_versions/:track_version_id/track_contents" do
    context "when user has access to the track version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/track_versions/#{track_version.id}/track_contents", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns track contents as JSON array" do
        get "/api/v1/track_versions/#{track_version.id}/track_contents", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
      end

      it "returns track contents belonging to the track version" do
        content1 = create(:track_content, track_version: track_version, title: "Audio Mix", content_type: "audio")
        content2 = create(:track_content, track_version: track_version, title: "Lyrics", content_type: "lyrics")
        
        # Create content in different track version (should not appear)
        other_version = create(:track_version, project: project, user: user)
        other_content = create(:track_content, track_version: other_version, title: "Other Content")
        
        get "/api/v1/track_versions/#{track_version.id}/track_contents", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        titles = json_response.map { |c| c['title'] }
        expect(titles).to contain_exactly("Audio Mix", "Lyrics")
      end

      it "returns empty array when no contents exist" do
        get "/api/v1/track_versions/#{track_version.id}/track_contents", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to eq([])
      end
    end

    context "when trying to access another user's track version contents" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        get "/api/v1/track_versions/#{other_version.id}/track_contents", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_version = create(:track_version)
        get "/api/v1/track_versions/#{track_version.id}/track_contents"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # POST /api/v1/track_versions/:track_version_id/track_contents
  describe "POST /api/v1/track_versions/:track_version_id/track_contents" do
    context "when user has access to the track version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }
      let(:valid_content_params) do
        {
          track_content: {
            title: "Final Mix",
            description: "The final stereo mix",
            content_type: "audio",
            text_content: "Mix notes here",
            metadata: { format: "WAV", duration: 180 }
          }
        }
      end

      it "creates track content successfully" do
        expect {
          post "/api/v1/track_versions/#{track_version.id}/track_contents", params: valid_content_params, headers: headers
        }.to change(TrackContent, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        new_content = track_version.track_contents.last
        expect(new_content.title).to eq("Final Mix")
        expect(new_content.content_type).to eq("audio")
        expect(new_content.track_version).to eq(track_version)
      end

      it "returns the created track content" do
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: valid_content_params, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['title']).to eq("Final Mix")
        expect(json_response['description']).to eq("The final stereo mix")
        expect(json_response['content_type']).to eq("audio")
        expect(json_response['metadata']['format']).to eq("WAV")
      end

      it "returns error when content_type is missing" do
        invalid_params = {
          track_content: {
            title: "Test Content",
            content_type: ""
          }
        }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Content type can't be blank")
      end

      it "handles different content types" do
        lyrics_params = {
          track_content: {
            content_type: "lyrics",
            text_content: "Verse 1: Sample lyrics here...",
            title: "Song Lyrics"
          }
        }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: lyrics_params, headers: headers
        
        expect(response).to have_http_status(:created)
        
        created_content = TrackContent.last
        expect(created_content.content_type).to eq("lyrics")
        expect(created_content.text_content).to eq("Verse 1: Sample lyrics here...")
      end

      it "handles metadata as JSON" do
        complex_metadata = {
          track_content: {
            title: "Complex Content",
            content_type: "audio",
            metadata: {
              audio: { format: "WAV", sample_rate: 44100, bit_depth: 24 },
              processing: { eq_settings: { low: -2, mid: 1, high: 0 } },
              tags: ["final", "mastered"]
            }
          }
        }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: complex_metadata, headers: headers
        
        created_content = TrackContent.last
        expect(created_content.metadata['audio']['sample_rate']).to eq("44100")
        expect(created_content.metadata['tags']).to include("final")
      end

      it "handles file uploads" do
        # Create a temporary file for testing
        file = Tempfile.new(['test_audio', '.wav'])
        file.write('fake audio data')
        file.rewind
        
        upload_params = {
          track_content: {
            title: "Audio File",
            content_type: "audio"
          },
          file: Rack::Test::UploadedFile.new(file.path, 'audio/wav', true)
        }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: upload_params, headers: headers
        
        expect(response).to have_http_status(:created)
        
        created_content = TrackContent.last
        expect(created_content.file).to be_attached
        expect(created_content.file.filename.to_s).to include('test_audio')
        
        file.close
        file.unlink
      end
    end

    context "when trying to create content in another user's track version" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        content_params = { track_content: { title: "Hack Attempt", content_type: "audio" } }
        
        post "/api/v1/track_versions/#{other_version.id}/track_contents", params: content_params, headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "does not create the track content" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        content_params = { track_content: { title: "Hack Attempt", content_type: "audio" } }
        
        expect {
          post "/api/v1/track_versions/#{other_version.id}/track_contents", params: content_params, headers: headers
        }.not_to change(TrackContent, :count)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_version = create(:track_version)
        content_params = { track_content: { title: "Test", content_type: "audio" } }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: content_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /api/v1/track_contents/:id
  describe "GET /api/v1/track_contents/:id" do
    context "when user has access to the track content" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:track_content) { create(:track_content, track_version: track_version) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns the track content successfully" do
        get "/api/v1/track_contents/#{track_content.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(track_content.id)
        expect(json_response['title']).to eq(track_content.title)
        expect(json_response['content_type']).to eq(track_content.content_type)
      end

      it "includes file information when file is attached" do
        # Create a temporary file and attach it
        file = Tempfile.new(['test_audio', '.wav'])
        file.write('fake audio data')
        file.rewind
        
        track_content.file.attach(
          io: file,
          filename: 'test_audio.wav',
          content_type: 'audio/wav'
        )
        
        get "/api/v1/track_contents/#{track_content.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['file_name']).to eq('test_audio.wav')
        expect(json_response['file_size']).to be_present
        expect(json_response['file_url']).to be_present
        
        file.close
        file.unlink
      end
    end

    context "when trying to view another user's track content" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        other_content = create(:track_content, track_version: other_version)
        
        get "/api/v1/track_contents/#{other_content.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_content = create(:track_content)
        get "/api/v1/track_contents/#{track_content.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PUT /api/v1/track_contents/:id
  describe "PUT /api/v1/track_contents/:id" do
    context "when user has permission to modify the track content" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:track_content) { create(:track_content, track_version: track_version, title: "Original Title") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "updates track content successfully" do
        update_params = {
          track_content: {
            title: "Updated Title",
            description: "Updated description",
            text_content: "Updated text content"
          }
        }
        
        put "/api/v1/track_contents/#{track_content.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        track_content.reload
        expect(track_content.title).to eq("Updated Title")
        expect(track_content.description).to eq("Updated description")
        expect(track_content.text_content).to eq("Updated text content")
      end

      it "updates metadata correctly" do
        update_params = {
          track_content: {
            metadata: { format: "MP3", bitrate: 320, new_field: "test" }
          }
        }
        
        put "/api/v1/track_contents/#{track_content.id}", params: update_params, headers: headers
        
        track_content.reload
        expect(track_content.metadata['format']).to eq("MP3")
        expect(track_content.metadata['bitrate']).to eq("320")
        expect(track_content.metadata['new_field']).to eq("test")
      end

      it "returns error for invalid data" do
        invalid_params = {
          track_content: { content_type: "" }
        }
        
        put "/api/v1/track_contents/#{track_content.id}", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Content type can't be blank")
      end
    end

    context "when user owns the project but content was created by another user" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:other_user) { create(:user) }
      let(:track_version) { create(:track_version, project: project, user: other_user) }
      let(:track_content) { create(:track_content, track_version: track_version) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows project owner to update content in their project" do
        update_params = {
          track_content: { title: "Updated by Project Owner" }
        }
        
        put "/api/v1/track_contents/#{track_content.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        track_content.reload
        expect(track_content.title).to eq("Updated by Project Owner")
      end
    end

    context "when trying to update another user's track content" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        other_content = create(:track_content, track_version: other_version)
        
        update_params = { track_content: { title: "Hacked Title" } }
        
        put "/api/v1/track_contents/#{other_content.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:not_found)
        
        other_content.reload
        expect(other_content.title).not_to eq("Hacked Title")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_content = create(:track_content)
        update_params = { track_content: { title: "New Title" } }
        
        put "/api/v1/track_contents/#{track_content.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # DELETE /api/v1/track_contents/:id
  describe "DELETE /api/v1/track_contents/:id" do
    context "when user has permission to modify the track content" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:track_content) { create(:track_content, track_version: track_version) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "deletes track content successfully" do
        delete "/api/v1/track_contents/#{track_content.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(TrackContent.exists?(track_content.id)).to be false
      end

      it "returns success message" do
        delete "/api/v1/track_contents/#{track_content.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Content deleted successfully')
      end

      it "deletes attached files" do
        # Create a temporary file and attach it
        file = Tempfile.new(['test_audio', '.wav'])
        file.write('fake audio data')
        file.rewind
        
        track_content.file.attach(
          io: file,
          filename: 'test_audio.wav',
          content_type: 'audio/wav'
        )
        
        expect(track_content.file).to be_attached
        
        delete "/api/v1/track_contents/#{track_content.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(TrackContent.exists?(track_content.id)).to be false
        
        file.close
        file.unlink
      end
    end

    context "when user owns the project but content was created by another user" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:other_user) { create(:user) }
      let(:track_version) { create(:track_version, project: project, user: other_user) }
      let(:track_content) { create(:track_content, track_version: track_version) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows project owner to delete content in their project" do
        delete "/api/v1/track_contents/#{track_content.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(TrackContent.exists?(track_content.id)).to be false
      end
    end

    context "when trying to delete another user's track content" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        other_content = create(:track_content, track_version: other_version)
        
        delete "/api/v1/track_contents/#{other_content.id}", headers: headers
        
        expect(response).to have_http_status(:not_found)
        expect(TrackContent.exists?(other_content.id)).to be true
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_content = create(:track_content)
        
        delete "/api/v1/track_contents/#{track_content.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end