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

      it "returns onboarding status for user in progress" do
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
      it "starts onboarding successfully" do
        post "/api/v1/onboarding/start", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Onboarding started')
        expect(json_response['current_step']).to eq('workspace_creation')
      end

      it "updates user's onboarding step" do
        expect {
          post "/api/v1/onboarding/start", headers: headers
        }.to change { user.reload.onboarding_step }.from('not_started').to('workspace_creation')
      end

      it "allows restarting onboarding" do
        user.update!(onboarding_step: 'completed', onboarding_completed_at: 1.day.ago)
        
        post "/api/v1/onboarding/start", headers: headers
        
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.onboarding_step).to eq('workspace_creation')
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/onboarding/start"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/onboarding/complete" do
    context "when user is authenticated" do
      it "completes onboarding successfully" do
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

      it "allows completing from any step (including skip scenario)" do
        user.update!(onboarding_step: 'not_started')
        
        post "/api/v1/onboarding/complete", headers: headers
        
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.onboarding_completed?).to be true
      end

      it "sets completion timestamp" do
        freeze_time = Time.current
        
        Timecop.freeze(freeze_time) do
          post "/api/v1/onboarding/complete", headers: headers
          
          user.reload
          expect(user.onboarding_completed_at).to be_within(1.second).of(freeze_time)
        end
      end

      it "handles skip functionality (frontend calls complete directly)" do
        # Frontend skip button calls complete endpoint directly
        user.update!(onboarding_step: 'workspace_creation')
        
        post "/api/v1/onboarding/complete", headers: headers
        
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.onboarding_completed?).to be true
        expect(user.onboarding_step).to eq('completed')
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

  describe "onboarding workflow integration" do
    context "typical user journey" do
      it "follows complete onboarding flow" do
        # Start as new user
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('not_started')
        expect(status['needs_onboarding']).to be true
        
        # Start onboarding
        post "/api/v1/onboarding/start", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Check status during onboarding
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('workspace_creation')
        expect(status['needs_onboarding']).to be true
        
        # Complete onboarding
        post "/api/v1/onboarding/complete", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Verify completion
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('completed')
        expect(status['needs_onboarding']).to be false
        expect(status['completed_at']).to be_present
      end

      it "follows skip onboarding flow (frontend calls complete directly)" do
        # Start onboarding
        post "/api/v1/onboarding/start", headers: headers
        
        # Frontend skip button calls complete endpoint directly
        post "/api/v1/onboarding/complete", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Verify completed state
        get "/api/v1/onboarding/status", headers: headers
        status = JSON.parse(response.body)
        expect(status['current_step']).to eq('completed')
        expect(status['needs_onboarding']).to be false
        expect(status['completed_at']).to be_present
      end
    end

    context "edge cases" do
      it "handles multiple start calls" do
        post "/api/v1/onboarding/start", headers: headers
        post "/api/v1/onboarding/start", headers: headers
        
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.onboarding_step).to eq('workspace_creation')
      end

      it "handles multiple complete calls" do
        post "/api/v1/onboarding/complete", headers: headers
        original_time = user.reload.onboarding_completed_at
        
        Timecop.travel(1.minute.from_now) do
          post "/api/v1/onboarding/complete", headers: headers
          expect(response).to have_http_status(:ok)
          
          user.reload
          # Should update the completion time
          expect(user.onboarding_completed_at).to be > original_time
        end
      end

      it "allows completing from any step (direct skip)" do
        # User can skip directly without starting
        post "/api/v1/onboarding/complete", headers: headers
        expect(response).to have_http_status(:ok)
        
        user.reload
        expect(user.onboarding_completed?).to be true
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
        
        # Create workspace during onboarding
        post "/api/v1/workspaces", params: workspace_params, headers: headers
        expect(response).to have_http_status(:created)
        
        workspace = Workspace.last
        expect(workspace.name).to eq("My First Studio")
        expect(workspace.user).to eq(user)
        
        # User should still be in onboarding until they explicitly complete
        user.reload
        expect(user.onboarding_step).to eq('workspace_creation')
        
        # Then complete onboarding
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

  describe "removed skip endpoint" do
    it "skip endpoint no longer exists" do
      post "/api/v1/onboarding/skip", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end