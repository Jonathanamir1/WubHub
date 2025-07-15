# spec/requests/api/v1/onboarding_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Onboarding", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "GET /api/v1/onboarding/status" do
    context "when user is authenticated" do
      it "returns success status" do
        get "/api/v1/onboarding/status", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns onboarding status for new user" do
        get "/api/v1/onboarding/status", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['needs_onboarding']).to be true
        expect(json_response['current_step']).to eq('not_started')
        expect(json_response['completed_at']).to be_nil
      end

      it "returns onboarding status for user in workspace_creation" do
        user.update!(onboarding_step: 'workspace_creation')
        
        get "/api/v1/onboarding/status", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['needs_onboarding']).to be true
        expect(json_response['current_step']).to eq('workspace_creation')
        expect(json_response['completed_at']).to be_nil
      end

      it "returns onboarding status for completed user" do
        completion_time = 1.day.ago
        user.update!(
          onboarding_step: 'completed',
          onboarding_completed_at: completion_time
        )
        
        get "/api/v1/onboarding/status", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['needs_onboarding']).to be false
        expect(json_response['current_step']).to eq('completed')
        expect(json_response['completed_at']).to be_present
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/onboarding/status"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/onboarding/start" do
    context "when user is authenticated" do
      it "starts onboarding successfully for new users" do
        post "/api/v1/onboarding/start", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Onboarding started')
        expect(json_response['current_step']).to eq('workspace_creation')
      end

      it "updates user's onboarding step to workspace_creation" do
        expect {
          post "/api/v1/onboarding/start", headers: headers
        }.to change { user.reload.onboarding_step }.from('not_started').to('workspace_creation')
      end

      it "allows starting from workspace_creation step (idempotent)" do
        user.update!(onboarding_step: 'workspace_creation')
        
        post "/api/v1/onboarding/start", headers: headers
        
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.onboarding_step).to eq('workspace_creation')
      end

      it "prevents starting when onboarding is already completed" do
        user.update!(onboarding_step: 'completed', onboarding_completed_at: 1.day.ago)
        
        post "/api/v1/onboarding/start", headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Onboarding already completed')
        expect(json_response['error']).to include('Use reset endpoint to restart')
        expect(json_response['current_step']).to eq('completed')
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/onboarding/start"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/onboarding/create_first_workspace" do
    before do
      user.update!(onboarding_step: 'workspace_creation')
    end

    context "when user is authenticated and in correct step" do
      it "successfully creates project_based workspace" do
        workspace_params = {
          name: "My Music Projects",
          description: "My personal music workspace",
          workspace_type: "project_based"
        }

        expect {
          post "/api/v1/onboarding/create_first_workspace", 
               params: { workspace: workspace_params }, 
               headers: headers
        }.to change(Workspace, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('First workspace created successfully')
        expect(json_response['workspace']['workspace_type']).to eq('project_based')
        expect(json_response['workspace']['name']).to eq('My Music Projects')
        expect(json_response['current_step']).to eq('completed')
      end

      it "successfully creates client_based workspace" do
        workspace_params = {
          name: "Studio Services",
          description: "Client work workspace",
          workspace_type: "client_based"
        }

        expect {
          post "/api/v1/onboarding/create_first_workspace", 
               params: { workspace: workspace_params }, 
               headers: headers
        }.to change(Workspace, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['workspace']['workspace_type']).to eq('client_based')
      end

      it "successfully creates library workspace" do
        workspace_params = {
          name: "Sample Library",
          description: "My collection of samples and loops",
          workspace_type: "library"
        }

        expect {
          post "/api/v1/onboarding/create_first_workspace", 
               params: { workspace: workspace_params }, 
               headers: headers
        }.to change(Workspace, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['workspace']['workspace_type']).to eq('library')
      end

      it "automatically completes onboarding after workspace creation" do
        workspace_params = {
          name: "Test Workspace",
          workspace_type: "project_based"
        }

        expect {
          post "/api/v1/onboarding/create_first_workspace", 
               params: { workspace: workspace_params }, 
               headers: headers
        }.to change { user.reload.onboarding_completed? }.from(false).to(true)
        
        user.reload
        expect(user.onboarding_step).to eq('completed')
        expect(user.onboarding_completed_at).to be_present
      end

      it "rejects invalid workspace types" do
        workspace_params = {
          name: "Test Workspace",
          workspace_type: "invalid_type"
        }

        post "/api/v1/onboarding/create_first_workspace", 
             params: { workspace: workspace_params }, 
             headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid workspace type')
      end

      it "requires workspace name" do
        workspace_params = {
          workspace_type: "project_based"
        }

        post "/api/v1/onboarding/create_first_workspace", 
             params: { workspace: workspace_params }, 
             headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Name can't be blank")
      end
    end

    context "when user is not in correct onboarding step" do
      it "returns error when user hasn't started onboarding" do
        user.update!(onboarding_step: 'not_started')
        
        workspace_params = {
          name: "Test Workspace",
          workspace_type: "project_based"
        }
        
        post "/api/v1/onboarding/create_first_workspace", 
             params: { workspace: workspace_params }, 
             headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Cannot create workspace at this onboarding step')
      end

      it "allows creating workspace from workspace_creation step" do
        user.update!(onboarding_step: 'workspace_creation')
        
        workspace_params = {
          name: "Test Workspace",
          workspace_type: "project_based"
        }
        
        post "/api/v1/onboarding/create_first_workspace", 
             params: { workspace: workspace_params }, 
             headers: headers
        
        expect(response).to have_http_status(:created)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        workspace_params = {
          name: "Test Workspace",
          workspace_type: "project_based"
        }
        
        post "/api/v1/onboarding/create_first_workspace", 
             params: { workspace: workspace_params }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/onboarding/complete" do
    context "when user is authenticated" do
      it "completes onboarding successfully from workspace_creation step" do
        user.update!(onboarding_step: 'workspace_creation')
        
        post "/api/v1/onboarding/complete", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Onboarding completed')
        expect(json_response['completed_at']).to be_present
      end

      it "updates user's onboarding status" do
        user.update!(onboarding_step: 'workspace_creation')
        
        expect {
          post "/api/v1/onboarding/complete", headers: headers
        }.to change { user.reload.onboarding_completed? }.from(false).to(true)
        
        user.reload
        expect(user.onboarding_step).to eq('completed')
        expect(user.onboarding_completed_at).to be_present
      end

      it "allows completing from any step (skip functionality)" do
        user.update!(onboarding_step: 'not_started')
        
        post "/api/v1/onboarding/complete", headers: headers
        
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.onboarding_completed?).to be true
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/onboarding/complete"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/onboarding/reset" do
    context "when user is authenticated" do
      it "resets onboarding successfully" do
        user.update!(
          onboarding_step: 'completed',
          onboarding_completed_at: 1.day.ago
        )
        
        post "/api/v1/onboarding/reset", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Onboarding reset')
        expect(json_response['current_step']).to eq('not_started')
      end

      it "resets user's onboarding state" do
        user.update!(
          onboarding_step: 'completed',
          onboarding_completed_at: 1.day.ago
        )
        
        expect {
          post "/api/v1/onboarding/reset", headers: headers
        }.to change { user.reload.onboarding_completed? }.from(true).to(false)
        
        user.reload
        expect(user.onboarding_step).to eq('not_started')
        expect(user.onboarding_completed_at).to be_nil
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/onboarding/reset"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "complete onboarding workflow integration" do
    context "typical user journey" do
      it "follows complete enhanced onboarding flow" do
        # Start as new user
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('not_started')
        expect(status['needs_onboarding']).to be true
        
        # Start onboarding
        post "/api/v1/onboarding/start", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Check status after starting
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('workspace_creation')
        
        # Create first workspace (this completes onboarding)
        workspace_params = {
          name: "My Music Projects",
          workspace_type: "project_based"
        }
        post "/api/v1/onboarding/create_first_workspace", 
             params: { workspace: workspace_params }, 
             headers: headers
        expect(response).to have_http_status(:created)
        
        # Verify completion
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('completed')
        expect(status['needs_onboarding']).to be false
        expect(status['completed_at']).to be_present
      end

      it "handles skip flow (complete directly from any step)" do
        # Start onboarding
        post "/api/v1/onboarding/start", headers: headers
        
        # Skip workspace creation by completing directly
        post "/api/v1/onboarding/complete", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Verify completed state
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('completed')
        expect(status['needs_onboarding']).to be false
      end

      it "handles restart flow via reset endpoint" do
        # Complete onboarding first
        post "/api/v1/onboarding/complete", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Verify completed
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('completed')
        
        # Reset onboarding
        post "/api/v1/onboarding/reset", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Verify reset
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('not_started')
        expect(status['needs_onboarding']).to be true
        
        # Can start again after reset
        post "/api/v1/onboarding/start", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "workspace creation integration" do
    context "when user completes onboarding by creating workspace" do
      it "workspace creation works during onboarding" do
        user.update!(onboarding_step: 'workspace_creation')
        
        workspace_params = {
          workspace: {
            name: "My First Studio",
            description: "Created during onboarding",
            workspace_type: "project_based"
          }
        }
        
        # Create workspace during onboarding via regular workspace route
        post "/api/v1/workspaces", params: workspace_params, headers: headers
        expect(response).to have_http_status(:created)
        
        workspace = Workspace.last
        expect(workspace.name).to eq("My First Studio")
        expect(workspace.user).to eq(user)
        
        # User should still be in onboarding until they explicitly complete
        user.reload
        expect(user.onboarding_step).to eq('workspace_creation')
        
        # Then complete onboarding manually
        post "/api/v1/onboarding/complete", headers: headers
        expect(response).to have_http_status(:ok)
        
        user.reload
        expect(user.onboarding_completed?).to be true
      end
    end
  end

  describe "error handling" do
    context "with database errors" do
      it "handles database failures gracefully" do
        allow_any_instance_of(User).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(user))
        
        post "/api/v1/onboarding/start", headers: headers
        
        expect(response.status).to be_in([422, 500])
      end
    end

    context "with invalid user states" do
      it "handles users with invalid onboarding steps" do
        user.update_column(:onboarding_step, 'invalid_step')
        
        get "/api/v1/onboarding/status", headers: headers
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['current_step']).to be_present
      end
    end
  end
end