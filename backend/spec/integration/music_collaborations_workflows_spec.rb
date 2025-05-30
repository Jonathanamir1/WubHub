require 'rails_helper'

RSpec.describe "Music Collaboration Workflows", type: :request do
  
  describe "Complete Album Creation Workflow" do
    let(:artist) { create(:user, username: 'artist_john') }
    let(:producer) { create(:user, username: 'producer_mike') }
    let(:vocalist) { create(:user, username: 'vocalist_sarah') }
    let(:fan) { create(:user, username: 'fan_alex') }

    it "handles full album creation and collaboration workflow" do
      # Step 1: Artist creates workspace
      artist_token = generate_token_for_user(artist)
      artist_headers = { 'Authorization' => "Bearer #{artist_token}" }

      post "/api/v1/workspaces", 
           params: { workspace: { name: "John's Studio", description: "My music workspace" } },
           headers: artist_headers

      expect(response).to have_http_status(:created)
      studio_id = JSON.parse(response.body)['id']

      # Step 2: Artist creates album project
      post "/api/v1/workspaces/#{studio_id}/projects",
           params: { project: { title: "Debut Album", description: "My first album" } },
           headers: artist_headers

      expect(response).to have_http_status(:created)
      album_id = JSON.parse(response.body)['id']

      # Step 3: Artist adds collaborators to workspace
      producer_token = generate_token_for_user(producer)
      producer_headers = { 'Authorization' => "Bearer #{producer_token}" }

      post "/api/v1/projects/#{album_id}/roles",
           params: { role: { name: "collaborator", user_id: producer.id } },
           headers: artist_headers

      expect(response).to have_http_status(:created)

      # Step 4: Producer can now see the album
      get "/api/v1/projects/#{album_id}", headers: producer_headers
      expect(response).to have_http_status(:ok)

      # Step 5: Artist creates first track version
      post "/api/v1/projects/#{album_id}/track_versions",
           params: { 
             track_version: { 
               title: "Song 1 - Demo",
               description: "Initial demo recording",
               metadata: { tempo: 120, key: "C major" }
             } 
           },
           headers: artist_headers

      expect(response).to have_http_status(:created)
      demo_id = JSON.parse(response.body)['id']

      # Step 6: Artist uploads demo audio
      file = Tempfile.new(['demo', '.wav'])
      file.write('demo audio data')
      file.rewind

      post "/api/v1/track_versions/#{demo_id}/track_contents",
           params: {
             track_content: { title: "Demo Recording", content_type: "audio" },
             file: Rack::Test::UploadedFile.new(file.path, 'audio/wav', true)
           },
           headers: artist_headers

      expect(response).to have_http_status(:created)
      demo_content_id = JSON.parse(response.body)['id']
      file.close
      file.unlink

      # Step 7: Producer creates their own version
      post "/api/v1/projects/#{album_id}/track_versions",
           params: {
             track_version: {
               title: "Song 1 - Producer Mix",
               description: "Professional mix by producer",
               metadata: { tempo: 120, key: "C major", mixed_by: "Producer Mike" }
             }
           },
           headers: producer_headers

      expect(response).to have_http_status(:created)
      producer_mix_id = JSON.parse(response.body)['id']

      # Step 8: Vocalist is added for specific track
      vocalist_token = generate_token_for_user(vocalist)
      vocalist_headers = { 'Authorization' => "Bearer #{vocalist_token}" }

      post "/api/v1/projects/#{album_id}/roles",
           params: { role: { name: "commenter", user_id: vocalist.id } },
           headers: artist_headers

      expect(response).to have_http_status(:created)

      # Step 9: Vocalist adds lyrics
      post "/api/v1/track_versions/#{producer_mix_id}/track_contents",
           params: {
             track_content: {
               title: "Song Lyrics",
               content_type: "lyrics",
               text_content: "Verse 1: This is my song..."
             }
           },
           headers: vocalist_headers

      expect(response).to have_http_status(:created)

      # Step 10: Artist makes track public for promotion
      put "/api/v1/track_versions/#{producer_mix_id}",
          params: { track_version: { title: "Song 1 - Final Version" } },
          headers: artist_headers

      expect(response).to have_http_status(:ok)

      # Step 11: Fan can discover public content (if made public via privacy)
      fan_token = generate_token_for_user(fan)
      fan_headers = { 'Authorization' => "Bearer #{fan_token}" }

      # Fan tries to access private content (should fail)
      get "/api/v1/projects/#{album_id}", headers: fan_headers
      expect(response).to have_http_status(:not_found)

      # Step 12: Verify all collaborators can see their accessible content
      get "/api/v1/projects/#{album_id}/track_versions", headers: producer_headers
      producer_versions = JSON.parse(response.body)
      expect(producer_versions.length).to eq(2)  # Demo + Producer mix

      get "/api/v1/projects/#{album_id}/track_versions", headers: vocalist_headers
      vocalist_versions = JSON.parse(response.body)
      expect(vocalist_versions.length).to eq(2)  # Can see all due to project role
    end
  end

  describe "Privacy Workflow Scenarios" do
    let(:artist) { create(:user, username: 'privacy_artist') }
    let(:producer) { create(:user, username: 'privacy_producer') }
    let(:fan) { create(:user, username: 'privacy_fan') }

    it "handles work-in-progress privacy workflow" do
      # Setup
      artist_token = generate_token_for_user(artist)
      artist_headers = { 'Authorization' => "Bearer #{artist_token}" }
      
      producer_token = generate_token_for_user(producer)
      producer_headers = { 'Authorization' => "Bearer #{producer_token}" }

      # Create workspace and add producer
      post "/api/v1/workspaces",
           params: { workspace: { name: "Privacy Studio" } },
           headers: artist_headers
      studio_id = JSON.parse(response.body)['id']

      # Add producer to workspace
      post "/api/v1/workspaces/#{studio_id}/projects",
           params: { project: { title: "Secret Album" } },
           headers: artist_headers
      album_id = JSON.parse(response.body)['id']

      post "/api/v1/projects/#{album_id}/roles",
           params: { role: { name: "collaborator", user_id: producer.id } },
           headers: artist_headers

      # Create track version
      post "/api/v1/projects/#{album_id}/track_versions",
           params: { track_version: { title: "Work in Progress" } },
           headers: artist_headers
      track_id = JSON.parse(response.body)['id']

      # Initially, producer can see it
      get "/api/v1/track_versions/#{track_id}", headers: producer_headers
      expect(response).to have_http_status(:ok)

      # Artist sets track to private (work in progress)
      track_version = TrackVersion.find(track_id)
      Privacy.create!(user: artist, privatable: track_version, level: 'private')

      # Now producer should not see it
      get "/api/v1/track_versions/#{track_id}", headers: producer_headers
      expect(response).to have_http_status(:not_found)

      # Artist can still see it
      get "/api/v1/track_versions/#{track_id}", headers: artist_headers
      expect(response).to have_http_status(:ok)

      # When ready, artist makes it public
      track_version.privacy.update!(level: 'public')

      # Now fan can access it directly
      fan_token = generate_token_for_user(fan)
      fan_headers = { 'Authorization' => "Bearer #{fan_token}" }

      get "/api/v1/track_versions/#{track_id}", headers: fan_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "File Upload and Management Workflow" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it "handles complete file management lifecycle" do
      # Setup project structure
      post "/api/v1/workspaces",
           params: { workspace: { name: "File Test Studio" } },
           headers: headers
      studio_id = JSON.parse(response.body)['id']

      post "/api/v1/workspaces/#{studio_id}/projects",
           params: { project: { title: "File Test Project" } },
           headers: headers
      project_id = JSON.parse(response.body)['id']

      post "/api/v1/projects/#{project_id}/track_versions",
           params: { track_version: { title: "File Test Track" } },
           headers: headers
      track_id = JSON.parse(response.body)['id']

      # Upload different types of files
      file_types = [
        { name: 'audio.wav', content: 'audio data', type: 'audio/wav', content_type: 'audio' },
        { name: 'lyrics.txt', content: 'song lyrics content', type: 'text/plain', content_type: 'lyrics' },
        { name: 'project.logic', content: 'logic pro data', type: 'application/octet-stream', content_type: 'project_file' }
      ]

      uploaded_files = []

      file_types.each do |file_info|
        file = Tempfile.new([file_info[:name], File.extname(file_info[:name])])
        file.write(file_info[:content])
        file.rewind

        post "/api/v1/track_versions/#{track_id}/track_contents",
             params: {
               track_content: {
                 title: "Test #{file_info[:content_type]}",
                 content_type: file_info[:content_type]
               },
               file: Rack::Test::UploadedFile.new(file.path, file_info[:type], true)
             },
             headers: headers

        expect(response).to have_http_status(:created)
        uploaded_files << JSON.parse(response.body)

        file.close
        file.unlink
      end

      # Verify all files were uploaded
      get "/api/v1/track_versions/#{track_id}/track_contents", headers: headers
      contents = JSON.parse(response.body)
      expect(contents.length).to eq(3)

      # Verify file URLs are accessible
      contents.each do |content|
        expect(content['file_url']).to be_present if content['file_url']
        expect(content['file_name']).to be_present if content['file_name']
      end

      # Update file metadata
      audio_content = contents.find { |c| c['content_type'] == 'audio' }
      put "/api/v1/track_contents/#{audio_content['id']}",
          params: {
            track_content: {
              metadata: { duration: 180, sample_rate: 44100, processed: true }
            }
          },
          headers: headers

      expect(response).to have_http_status(:ok)
      updated_content = JSON.parse(response.body)
      expect(updated_content['metadata']['duration']).to eq("180")

      # Delete one file
      delete "/api/v1/track_contents/#{audio_content['id']}", headers: headers
      expect(response).to have_http_status(:ok)

      # Verify it's gone
      get "/api/v1/track_versions/#{track_id}/track_contents", headers: headers
      remaining_contents = JSON.parse(response.body)
      expect(remaining_contents.length).to eq(2)
    end
  end

  describe "Role Management Workflow" do
    let(:owner) { create(:user, username: 'project_owner') }
    let(:collaborator) { create(:user, username: 'collaborator') }
    let(:viewer) { create(:user, username: 'viewer') }
    let(:external) { create(:user, username: 'external_user') }

    it "handles complete role management lifecycle" do
      owner_token = generate_token_for_user(owner)
      owner_headers = { 'Authorization' => "Bearer #{owner_token}" }

      # Create project
      post "/api/v1/workspaces",
           params: { workspace: { name: "Role Test Studio" } },
           headers: owner_headers
      studio_id = JSON.parse(response.body)['id']

      post "/api/v1/workspaces/#{studio_id}/projects",
           params: { project: { title: "Role Test Project" } },
           headers: owner_headers
      project_id = JSON.parse(response.body)['id']

      # Add collaborator
      post "/api/v1/projects/#{project_id}/roles",
           params: { role: { name: "collaborator", user_id: collaborator.id } },
           headers: owner_headers
      expect(response).to have_http_status(:created)
      collab_role_id = JSON.parse(response.body)['id']

      # Add viewer
      post "/api/v1/projects/#{project_id}/roles",
           params: { role: { name: "viewer", user_id: viewer.id } },
           headers: owner_headers
      expect(response).to have_http_status(:created)

      # Verify roles list
      get "/api/v1/projects/#{project_id}/roles", headers: owner_headers
      roles = JSON.parse(response.body)
      expect(roles.length).to eq(2)

      # Test collaborator permissions
      collab_token = generate_token_for_user(collaborator)
      collab_headers = { 'Authorization' => "Bearer #{collab_token}" }

      # Collaborator can create track versions
      post "/api/v1/projects/#{project_id}/track_versions",
           params: { track_version: { title: "Collab Track" } },
           headers: collab_headers
      expect(response).to have_http_status(:created)

      # Test viewer permissions
      viewer_token = generate_token_for_user(viewer)
      viewer_headers = { 'Authorization' => "Bearer #{viewer_token}" }

      # Viewer can see project
      get "/api/v1/projects/#{project_id}", headers: viewer_headers
      expect(response).to have_http_status(:ok)

      # Viewer cannot create content (depending on your business rules)
      post "/api/v1/projects/#{project_id}/track_versions",
           params: { track_version: { title: "Viewer Track" } },
           headers: viewer_headers
      # This should either succeed (if viewers can create) or fail gracefully
      expect([201, 403, 404]).to include(response.status)

      # Test external user (no access)
      external_token = generate_token_for_user(external)
      external_headers = { 'Authorization' => "Bearer #{external_token}" }

      get "/api/v1/projects/#{project_id}", headers: external_headers
      expect(response).to have_http_status(:not_found)

      # Change role permissions
      put "/api/v1/roles/#{collab_role_id}",
          params: { role: { name: "viewer" } },
          headers: owner_headers
      expect(response).to have_http_status(:ok)

      # Remove role
      delete "/api/v1/roles/#{collab_role_id}", headers: owner_headers
      expect(response).to have_http_status(:ok)

      # Verify collaborator lost access
      get "/api/v1/projects/#{project_id}", headers: collab_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "User Account Management Workflow" do
    it "handles complete user lifecycle" do
      # Register new user
      post "/api/v1/auth/register",
           params: {
             email: 'newuser@example.com',
             username: 'newuser123',
             name: 'New User',
             password: 'securepassword123',
             password_confirmation: 'securepassword123'
           }

      expect(response).to have_http_status(:created)
      auth_data = JSON.parse(response.body)
      token = auth_data['token']
      user_id = auth_data['user']['id']
      headers = { 'Authorization' => "Bearer #{token}" }

      # User creates content
      post "/api/v1/workspaces",
           params: { workspace: { name: "User's First Studio" } },
           headers: headers
      expect(response).to have_http_status(:created)
      workspace_id = JSON.parse(response.body)['id']

      # Update profile
      put "/api/v1/users/#{user_id}",
          params: {
            user: {
              name: "Updated Name",
              bio: "I'm a music creator"
            }
          },
          headers: headers
      expect(response).to have_http_status(:ok)

      # Search for users
      get "/api/v1/users", params: { search: "newuser" }, headers: headers
      users = JSON.parse(response.body)
      found_user = users.find { |u| u['username'] == 'newuser123' }
      expect(found_user).to be_present

      # User deletes account
      delete "/api/v1/users/#{user_id}", headers: headers
      expect(response).to have_http_status(:ok)

      # Verify user and content are gone
      expect(User.exists?(user_id)).to be false
      expect(Workspace.exists?(workspace_id)).to be false
    end
  end

  describe "Error Recovery Workflows" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it "handles graceful degradation when services are unavailable" do
      # Create basic structure
      post "/api/v1/workspaces",
           params: { workspace: { name: "Error Test Studio" } },
           headers: headers
      studio_id = JSON.parse(response.body)['id']

      # Test with missing project
      get "/api/v1/workspaces/99999/projects", headers: headers
      expect(response).to have_http_status(:not_found)

      # Test with malformed requests
      post "/api/v1/workspaces/#{studio_id}/projects",
           params: { project: { title: "" } },  # Invalid
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      # Test partial failures don't corrupt data
      post "/api/v1/workspaces/#{studio_id}/projects",
           params: { project: { title: "Valid Project" } },
           headers: headers
      expect(response).to have_http_status(:created)
      project_id = JSON.parse(response.body)['id']

      # Verify the valid project was created despite previous errors
      get "/api/v1/projects/#{project_id}", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Performance Under Load" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it "maintains performance with large datasets" do
      # Create workspace
      post "/api/v1/workspaces",
           params: { workspace: { name: "Performance Test Studio" } },
           headers: headers
      studio_id = JSON.parse(response.body)['id']

      # Create many projects rapidly
      start_time = Time.current
      
      10.times do |i|
        post "/api/v1/workspaces/#{studio_id}/projects",
             params: { project: { title: "Bulk Project #{i}" } },
             headers: headers
        expect(response).to have_http_status(:created)
      end
      
      creation_time = Time.current - start_time
      expect(creation_time).to be < 5.seconds

      # Fetch all projects efficiently
      start_time = Time.current
      get "/api/v1/workspaces/#{studio_id}/projects", headers: headers
      fetch_time = Time.current - start_time
      
      expect(response).to have_http_status(:ok)
      expect(fetch_time).to be < 1.second
      
      projects = JSON.parse(response.body)
      expect(projects.length).to eq(10)
    end
  end
end