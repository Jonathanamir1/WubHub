require 'rails_helper'

RSpec.describe "Database Performance", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "N+1 query prevention" do
    it "avoids N+1 queries when loading workspaces with projects" do
      # Create workspace with many projects
      workspace = create(:workspace, user: user)
      projects = create_list(:project, 10, workspace: workspace, user: user)
      
      # Track queries using bullet gem or custom query counter
      query_count = 0
      callback = lambda { |*args| query_count += 1 }
      
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get "/api/v1/workspaces/#{workspace.id}", headers: headers
      end
      
      # Should be constant regardless of project count
      expect(query_count).to be < 10
    end

    it "avoids N+1 queries when loading track versions with contents" do
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      track_version = create(:track_version, project: project, user: user)
      
      # Create many track contents
      create_list(:track_content, 20, track_version: track_version)
      
      query_count = 0
      callback = lambda { |*args| query_count += 1 }
      
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get "/api/v1/track_versions/#{track_version.id}", headers: headers
      end
      
      # Should not scale with number of track contents
      expect(query_count).to be < 15
    end

    it "avoids N+1 queries when checking permissions across hierarchy" do
      # Create complex hierarchy
      workspace = create(:workspace, user: user)
      projects = create_list(:project, 5, workspace: workspace, user: user)
      
      projects.each do |project|
        track_versions = create_list(:track_version, 3, project: project, user: user)
        track_versions.each do |tv|
          create_list(:track_content, 2, track_version: tv)
        end
      end
      
      # Add collaborator with complex roles
      collaborator = create(:user)
      create(:role, user: collaborator, roleable: workspace, name: 'viewer')
      create(:role, user: collaborator, roleable: projects.first, name: 'collaborator')
      
      query_count = 0
      callback = lambda { |*args| query_count += 1 }
      
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get "/api/v1/workspaces", headers: { 'Authorization' => "Bearer #{generate_token_for_user(collaborator)}" }
      end
      
      # Permission checking should be efficient
      expect(query_count).to be < 20
    end
  end

  describe "large dataset handling" do
    it "handles workspaces with many projects efficiently" do
      workspace = create(:workspace, user: user)
      create_list(:project, 100, workspace: workspace, user: user)
      
      start_time = Time.current
      get "/api/v1/workspaces/#{workspace.id}/projects", headers: headers
      end_time = Time.current
      
      expect(response).to have_http_status(:ok)
      expect(end_time - start_time).to be < 2.seconds
    end

    it "handles users with many workspaces efficiently" do
      create_list(:workspace, 50, user: user)
      
      start_time = Time.current
      get "/api/v1/workspaces", headers: headers
      end_time = Time.current
      
      expect(response).to have_http_status(:ok)
      expect(end_time - start_time).to be < 2.seconds
    end
  end

  describe "concurrent access scenarios" do
    it "handles simultaneous workspace creation" do
      threads = []
      results = []
      
      5.times do |i|
        threads << Thread.new do
          workspace_params = {
            workspace: {
              name: "Concurrent Workspace #{i}",
              description: "Created in thread #{i}"
            }
          }
          
          begin
            post "/api/v1/workspaces", params: workspace_params, headers: headers
            results << response.status
          rescue => e
            results << :error
          end
        end
      end
      
      threads.each(&:join)
      
      # Most should succeed
      success_count = results.count(201)
      expect(success_count).to be >= 4
    end

    it "handles race conditions in role assignment" do
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      collaborator = create(:user)
      
      threads = []
      results = []
      
      # Try to assign same role simultaneously
      3.times do
        threads << Thread.new do
          role_params = {
            role: {
              name: "collaborator",
              user_id: collaborator.id
            }
          }
          
          begin
            post "/api/v1/projects/#{project.id}/roles", params: role_params, headers: headers
            results << response.status
          rescue => e
            results << :error
          end
        end
      end
      
      threads.each(&:join)
      
      # Should have one success and rest should fail gracefully
      success_count = results.count(201)
      expect(success_count).to eq(1)
    end
  end
end