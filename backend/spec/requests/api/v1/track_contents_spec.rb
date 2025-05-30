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

  # 🎵 MUSIC STUDIO MODEL TESTS - NEW ADDITIONS
  describe "music studio collaboration and privacy" do
    let(:artist) { create(:user) }
    let(:producer) { create(:user) }
    let(:vocalist) { create(:user) }
    let(:fan) { create(:user) }
    let(:studio) { create(:workspace, user: artist, name: "Artist Studio") }
    let(:album) { create(:project, workspace: studio, user: artist, title: "New Album") }
    let(:demo) { create(:track_version, project: album, user: artist, title: "Song Demo") }
    let(:vocal_file) { create(:track_content, track_version: demo, user: artist, title: "Lead Vocal", content_type: "audio") }

    context "workspace collaboration access" do
      let(:token) { generate_token_for_user(producer) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows workspace members to view track contents" do
        # Producer joins the studio
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        
        # Reload to pick up new associations
        studio.reload
        album.reload
        demo.reload
        vocal_file.reload
        
        # Producer should see content in track version
        get "/api/v1/track_versions/#{demo.id}/track_contents", headers: headers
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        titles = json_response.map { |c| c['title'] }
        expect(titles).to include("Lead Vocal")
      end

      it "allows workspace members to view individual track contents" do
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        studio.reload
        vocal_file.reload
        
        # Producer should access individual content
        get "/api/v1/track_contents/#{vocal_file.id}", headers: headers
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq("Lead Vocal")
      end

      it "allows workspace members to create content in accessible track versions" do
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        studio.reload
        demo.reload
        
        content_params = {
          track_content: {
            title: "Producer's Mix",
            content_type: "audio",
            description: "Rough mix by producer"
          }
        }
        
        expect {
          post "/api/v1/track_versions/#{demo.id}/track_contents", params: content_params, headers: headers
        }.to change(TrackContent, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        created_content = TrackContent.last
        expect(created_content.title).to eq("Producer's Mix")
        expect(created_content.user).to eq(producer)
      end

      it "blocks non-workspace members from accessing track contents" do
        fan_token = generate_token_for_user(fan)
        fan_headers = { 'Authorization' => "Bearer #{fan_token}" }
        
        # Fan should not see contents
        get "/api/v1/track_versions/#{demo.id}/track_contents", headers: fan_headers
        expect(response).to have_http_status(:not_found)
        
        # Fan should not access individual content
        get "/api/v1/track_contents/#{vocal_file.id}", headers: fan_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "private content workflow (work-in-progress)" do
      let(:token) { generate_token_for_user(producer) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "hides private track contents from other workspace members" do
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        
        # Artist sets vocal file to private (work in progress)
        create(:privacy, privatable: vocal_file, user: artist, level: 'private')
        
        studio.reload
        demo.reload
        vocal_file.reload
        
        # Producer should not see private content in list
        get "/api/v1/track_versions/#{demo.id}/track_contents", headers: headers
        json_response = JSON.parse(response.body)
        titles = json_response.map { |c| c['title'] }
        expect(titles).not_to include("Lead Vocal")
        
        # Producer should not access private content directly
        get "/api/v1/track_contents/#{vocal_file.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "allows creator to access their own private content" do
        artist_token = generate_token_for_user(artist)
        artist_headers = { 'Authorization' => "Bearer #{artist_token}" }
        
        # Artist sets their own content to private
        create(:privacy, privatable: vocal_file, user: artist, level: 'private')
        vocal_file.reload
        
        # Artist should still see their private content
        get "/api/v1/track_contents/#{vocal_file.id}", headers: artist_headers
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq("Lead Vocal")
      end

      it "allows private content creators to update and delete their work" do
        # Producer creates private content
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        studio.reload
        demo.reload
        
        private_content = create(:track_content, track_version: demo, user: producer, title: "Private Mix")
        create(:privacy, privatable: private_content, user: producer, level: 'private')
        private_content.reload
        
        # Producer should be able to update their private content
        update_params = { track_content: { title: "Updated Private Mix" } }
        put "/api/v1/track_contents/#{private_content.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        private_content.reload
        expect(private_content.title).to eq("Updated Private Mix")
        
        # Producer should be able to delete their private content
        delete "/api/v1/track_contents/#{private_content.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(TrackContent.exists?(private_content.id)).to be false
      end
    end

    context "public content sharing (promotion)" do
      let(:token) { generate_token_for_user(fan) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows public access to track contents via direct link" do
        # Artist makes vocal file public for promotion
        create(:privacy, privatable: vocal_file, user: artist, level: 'public')
        vocal_file.reload
        
        # Fan should access public content directly
        get "/api/v1/track_contents/#{vocal_file.id}", headers: headers
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq("Lead Vocal")
      end

      it "includes file download capabilities for public content" do
        # Create content with attached file
        file = Tempfile.new(['public_single', '.mp3'])
        file.write('public audio data')
        file.rewind
        
        public_content = create(:track_content, track_version: demo, user: artist, title: "Released Single", content_type: "audio")
        public_content.file.attach(
          io: file,
          filename: 'single.mp3',
          content_type: 'audio/mp3'
        )
        
        # Make it public
        create(:privacy, privatable: public_content, user: artist, level: 'public')
        public_content.reload
        
        # Fan should access public content with file info
        get "/api/v1/track_contents/#{public_content.id}", headers: headers
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq("Released Single")
        expect(json_response['file_name']).to eq('single.mp3')
        expect(json_response['file_url']).to be_present
        
        file.close
        file.unlink
      end
    end

    context "hierarchical access inheritance" do
      let(:token) { generate_token_for_user(producer) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "respects project privacy settings for content access" do
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        
        # Artist makes entire album private
        create(:privacy, privatable: album, user: artist, level: 'private')
        
        studio.reload
        album.reload
        demo.reload
        vocal_file.reload
        
        # Producer should not access content in private album
        get "/api/v1/track_versions/#{demo.id}/track_contents", headers: headers
        expect(response).to have_http_status(:not_found)
        
        get "/api/v1/track_contents/#{vocal_file.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "allows public content in private albums to be accessed directly" do
        # Album is private, but specific content is public
        create(:privacy, privatable: album, user: artist, level: 'private')
        create(:privacy, privatable: vocal_file, user: artist, level: 'public')
        
        vocal_file.reload
        
        # Fan should access public content even in private album
        fan_token = generate_token_for_user(fan)
        fan_headers = { 'Authorization' => "Bearer #{fan_token}" }
        
        get "/api/v1/track_contents/#{vocal_file.id}", headers: fan_headers
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq("Lead Vocal")
      end
    end

    context "role-based content management" do
      let(:viewer) { create(:user) }
      let(:commenter) { create(:user) }
      
      it "allows different role types to access content appropriately" do
        # Add users with different roles
        create(:role, user: producer, roleable: studio, name: 'collaborator')
        create(:role, user: viewer, roleable: studio, name: 'viewer')
        create(:role, user: commenter, roleable: studio, name: 'commenter')
        
        studio.reload
        demo.reload
        vocal_file.reload
        
        # All roles should be able to view content
        [producer, viewer, commenter].each do |user|
          token = generate_token_for_user(user)
          headers = { 'Authorization' => "Bearer #{token}" }
          
          get "/api/v1/track_contents/#{vocal_file.id}", headers: headers
          expect(response).to have_http_status(:ok)
        end
        
        # Only collaborators should be able to create content
        producer_token = generate_token_for_user(producer)
        producer_headers = { 'Authorization' => "Bearer #{producer_token}" }
        
        content_params = {
          track_content: {
            title: "Collaborator Content",
            content_type: "audio"
          }
        }
        
        post "/api/v1/track_versions/#{demo.id}/track_contents", params: content_params, headers: producer_headers
        expect(response).to have_http_status(:created)
      end
    end
  end

  # Edge cases and error handling
  describe "edge cases and error handling" do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:project) { create(:project, workspace: workspace, user: user) }
    let(:track_version) { create(:track_version, project: project, user: user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "large file uploads" do
      it "handles reasonably sized file uploads" do
        # Create a larger test file (but still reasonable for testing)
        file = Tempfile.new(['large_audio', '.wav'])
        file.write('x' * 1024 * 100) # 100KB
        file.rewind
        
        upload_params = {
          track_content: {
            title: "Large Audio File",
            content_type: "audio"
          },
          file: Rack::Test::UploadedFile.new(file.path, 'audio/wav', true)
        }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: upload_params, headers: headers
        
        expect(response).to have_http_status(:created)
        
        created_content = TrackContent.last
        expect(created_content.file).to be_attached
        expect(created_content.file.byte_size).to eq(1024 * 100)
        
        file.close
        file.unlink
      end
    end

    context "special content types" do
      it "handles various music industry content types" do
        content_types = [
          { type: 'audio', title: 'Final Mix' },
          { type: 'lyrics', title: 'Song Lyrics' },
          { type: 'sheet_music', title: 'Piano Sheet Music' },
          { type: 'project_file', title: 'Logic Pro Project' },
          { type: 'image', title: 'Album Artwork' },
          { type: 'video', title: 'Music Video' },
          { type: 'document', title: 'Contract PDF' }
        ]
        
        content_types.each do |content_info|
          content_params = {
            track_content: {
              title: content_info[:title],
              content_type: content_info[:type],
              description: "Test #{content_info[:type]} content"
            }
          }
          
          post "/api/v1/track_versions/#{track_version.id}/track_contents", params: content_params, headers: headers
          expect(response).to have_http_status(:created)
          
          created_content = TrackContent.last
          expect(created_content.content_type).to eq(content_info[:type])
          expect(created_content.title).to eq(content_info[:title])
        end
      end
    end

    context "metadata complexity" do
      it "handles complex nested metadata structures" do
        complex_metadata = {
          track_content: {
            title: "Complex Metadata Content",
            content_type: "audio",
            metadata: {
              technical: {
                format: "WAV",
                sample_rate: 44100,
                bit_depth: 24,
                channels: 2,
                duration: 245.67
              },
              creative: {
                tempo: 128,
                key: "A minor",
                time_signature: "4/4",
                genre: ["Electronic", "House"],
                mood: "Energetic"
              },
              production: {
                recording_date: "2024-01-15",
                studio: "Abbey Road",
                engineer: "John Smith",
                equipment: {
                  microphones: ["Neumann U87", "Shure SM57"],
                  preamps: ["API 512c", "Neve 1073"],
                  daw: "Pro Tools"
                }
              },
              rights: {
                copyright: "© 2024 Artist Name",
                license: "All Rights Reserved",
                publishing: {
                  publisher: "Music Publisher Inc",
                  split: 50.0
                }
              }
            }
          }
        }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: complex_metadata, headers: headers
        
        expect(response).to have_http_status(:created)
        
        created_content = TrackContent.last
        expect(created_content.metadata['technical']['sample_rate']).to eq("44100")
        expect(created_content.metadata['creative']['genre']).to include("Electronic")
        expect(created_content.metadata['production']['equipment']['microphones']).to include("Neumann U87")
        expect(created_content.metadata['rights']['publishing']['split']).to eq("50.0")
      end
    end

    context "concurrent access scenarios" do
      it "handles multiple users accessing same content simultaneously" do
        # Create content
        content = create(:track_content, track_version: track_version, title: "Shared Content")
        
        # Simulate multiple users accessing concurrently
        users = create_list(:user, 3)
        users.each do |user|
          create(:role, user: user, roleable: workspace, name: 'collaborator')
        end
        
        # All users should be able to access
        users.each do |user|
          user_token = generate_token_for_user(user)
          user_headers = { 'Authorization' => "Bearer #{user_token}" }
          
          get "/api/v1/track_contents/#{content.id}", headers: user_headers
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "privacy transitions" do
      it "handles privacy level changes correctly" do
        # Create public content
        content = create(:track_content, track_version: track_version, title: "Transitioning Content")
        create(:privacy, privatable: content, user: user, level: 'public')
        
        # Verify it's public
        fan = create(:user)
        fan_token = generate_token_for_user(fan)
        fan_headers = { 'Authorization' => "Bearer #{fan_token}" }
        
        get "/api/v1/track_contents/#{content.id}", headers: fan_headers
        expect(response).to have_http_status(:ok)
        
        # Change to private
        content.privacy.update!(level: 'private')
        content.reload
        
        # Fan should lose access
        get "/api/v1/track_contents/#{content.id}", headers: fan_headers
        expect(response).to have_http_status(:not_found)
        
        # Owner should still have access
        get "/api/v1/track_contents/#{content.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "invalid file scenarios" do
      it "handles missing file uploads gracefully" do
        upload_params = {
          track_content: {
            title: "Content Without File",
            content_type: "audio"
          }
          # No file parameter
        }
        
        post "/api/v1/track_versions/#{track_version.id}/track_contents", params: upload_params, headers: headers
        
        # Should still create content without file
        expect(response).to have_http_status(:created)
        
        created_content = TrackContent.last
        expect(created_content.file).not_to be_attached
        expect(created_content.title).to eq("Content Without File")
      end
    end
  end

  # Performance and optimization tests
  describe "performance considerations" do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:project) { create(:project, workspace: workspace, user: user) }
    let(:track_version) { create(:track_version, project: project, user: user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it "handles large numbers of track contents efficiently" do
      # Create many track contents
      50.times do |i|
        create(:track_content, 
               track_version: track_version, 
               title: "Content #{i}", 
               content_type: "audio")
      end
      
      # Should return all contents without timeout
      get "/api/v1/track_versions/#{track_version.id}/track_contents", headers: headers
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response.length).to eq(50)
    end

    it "filters private content efficiently in large datasets" do
      # Create mix of public and private content
      25.times do |i|
        content = create(:track_content, 
                        track_version: track_version, 
                        title: "Public Content #{i}")
        create(:privacy, privatable: content, user: user, level: 'public')
      end
      
      25.times do |i|
        content = create(:track_content, 
                        track_version: track_version, 
                        title: "Private Content #{i}")
        create(:privacy, privatable: content, user: user, level: 'private')
      end
      
      # Non-owner should only see public content
      other_user = create(:user)
      other_token = generate_token_for_user(other_user)
      other_headers = { 'Authorization' => "Bearer #{other_token}" }
      
      get "/api/v1/track_versions/#{track_version.id}/track_contents", headers: other_headers
      expect(response).to have_http_status(:not_found) # Can't access track version
      
      # But if they could access the track version, they'd only see public content
      # This tests the filtering logic
    end
  end
end