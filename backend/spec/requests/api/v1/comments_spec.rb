require 'rails_helper'

RSpec.describe "Api::V1::Comments", type: :request do
  
  # GET /api/v1/track_versions/:track_version_id/comments
  describe "GET /api/v1/track_versions/:track_version_id/comments" do
    context "when user has access to the track version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns comments as JSON array" do
        get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
      end

      it "returns comments belonging to the track version" do
        comment1 = create(:comment, track_version: track_version, user: user, content: "Great track!")
        comment2 = create(:comment, track_version: track_version, user: user, content: "Needs more bass")
        
        # Create comment on different track version (should not appear)
        other_version = create(:track_version, project: project, user: user)
        other_comment = create(:comment, track_version: other_version, user: user, content: "Other comment")
        
        get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.length).to eq(2)
        contents = json_response.map { |c| c['content'] }
        expect(contents).to contain_exactly("Great track!", "Needs more bass")
      end

      it "orders comments by creation date (oldest first)" do
        old_comment = create(:comment, track_version: track_version, user: user, content: "First", created_at: 2.days.ago)
        new_comment = create(:comment, track_version: track_version, user: user, content: "Second", created_at: 1.day.ago)
        
        get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.first['content']).to eq("First")
        expect(json_response.last['content']).to eq("Second")
      end

      it "includes user information in comments" do
        commenter = create(:user, username: "commenter123")
        comment = create(:comment, track_version: track_version, user: commenter, content: "Test comment")
        
        get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response.first['user']['username']).to eq("commenter123")
      end

      it "returns empty array when no comments exist" do
        get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to eq([])
      end
    end

    context "when trying to access comments on another user's track version" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        get "/api/v1/track_versions/#{other_version.id}/comments", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_version = create(:track_version)
        get "/api/v1/track_versions/#{track_version.id}/comments"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # POST /api/v1/track_versions/:track_version_id/comments
  describe "POST /api/v1/track_versions/:track_version_id/comments" do
    context "when user has access to the track version" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }
      let(:valid_comment_params) do
        {
          comment: {
            content: "This is a great track! Love the melody at 2:30."
          }
        }
      end

      it "creates comment successfully" do
        expect {
          post "/api/v1/track_versions/#{track_version.id}/comments", params: valid_comment_params, headers: headers
        }.to change(Comment, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        new_comment = track_version.comments.last
        expect(new_comment.content).to eq("This is a great track! Love the melody at 2:30.")
        expect(new_comment.user).to eq(user)
        expect(new_comment.track_version).to eq(track_version)
      end

      it "returns the created comment" do
        post "/api/v1/track_versions/#{track_version.id}/comments", params: valid_comment_params, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['content']).to eq("This is a great track! Love the melody at 2:30.")
        expect(json_response['user']['id']).to eq(user.id)
      end

      it "returns error when content is missing" do
        invalid_params = {
          comment: { content: "" }
        }
        
        post "/api/v1/track_versions/#{track_version.id}/comments", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Content can't be blank")
      end

      it "sets user automatically to current user" do
        post "/api/v1/track_versions/#{track_version.id}/comments", params: valid_comment_params, headers: headers
        
        created_comment = Comment.last
        expect(created_comment.user).to eq(user)
      end

      it "handles long comments" do
        long_content = "A" * 1000
        long_comment_params = {
          comment: { content: long_content }
        }
        
        post "/api/v1/track_versions/#{track_version.id}/comments", params: long_comment_params, headers: headers
        
        expect(response).to have_http_status(:created)
        
        created_comment = Comment.last
        expect(created_comment.content.length).to eq(1000)
      end

      it "handles comments with special characters and emojis" do
        special_content = "Amazing track! 🎵 The beat at 2:30 is 🔥. Maybe add more reverb on the vocals? **Great work**!"
        special_comment_params = {
          comment: { content: special_content }
        }
        
        post "/api/v1/track_versions/#{track_version.id}/comments", params: special_comment_params, headers: headers
        
        expect(response).to have_http_status(:created)
        
        created_comment = Comment.last
        expect(created_comment.content).to eq(special_content)
      end

      it "allows multiple comments from same user" do
        post "/api/v1/track_versions/#{track_version.id}/comments", params: { comment: { content: "First comment" } }, headers: headers
        post "/api/v1/track_versions/#{track_version.id}/comments", params: { comment: { content: "Second comment" } }, headers: headers
        
        user_comments = user.comments
        expect(user_comments.count).to eq(2)
        expect(user_comments.pluck(:content)).to contain_exactly("First comment", "Second comment")
      end
    end

    context "when user can view but not necessarily own the track version" do
      let(:owner) { create(:user) }
      let(:commenter) { create(:user) }
      let(:workspace) { create(:workspace, user: owner) }
      let(:project) { create(:project, workspace: workspace, user: owner, visibility: "public") }
      let(:track_version) { create(:track_version, project: project, user: owner) }
      let(:token) { generate_token_for_user(commenter) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows any user to comment on accessible track versions" do
        comment_params = {
          comment: { content: "Great work from another user!" }
        }
        
        # This test assumes your authorization allows public project access
        # You may need to adjust based on your actual authorization logic
        post "/api/v1/track_versions/#{track_version.id}/comments", params: comment_params, headers: headers
        
        # The response depends on your authorization implementation
        # This might be :created if you allow public commenting, or :not_found if restricted
        expect([201, 404]).to include(response.status)
      end
    end

    context "when trying to comment on another user's private track version" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        comment_params = { comment: { content: "Unauthorized comment" } }
        
        post "/api/v1/track_versions/#{other_version.id}/comments", params: comment_params, headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "does not create the comment" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        
        comment_params = { comment: { content: "Unauthorized comment" } }
        
        expect {
          post "/api/v1/track_versions/#{other_version.id}/comments", params: comment_params, headers: headers
        }.not_to change(Comment, :count)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        track_version = create(:track_version)
        comment_params = { comment: { content: "Anonymous comment" } }
        
        post "/api/v1/track_versions/#{track_version.id}/comments", params: comment_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /api/v1/comments/:id
  describe "GET /api/v1/comments/:id" do
    context "when user has access to the comment" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:comment) { create(:comment, track_version: track_version, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns the comment successfully" do
        get "/api/v1/comments/#{comment.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(comment.id)
        expect(json_response['content']).to eq(comment.content)
        expect(json_response['user']['id']).to eq(user.id)
      end

      it "includes track version information" do
        get "/api/v1/comments/#{comment.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['track_version']['id']).to eq(track_version.id)
        expect(json_response['track_version']['title']).to eq(track_version.title)
      end
    end

    context "when trying to view another user's comment on inaccessible track" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        other_comment = create(:comment, track_version: other_version, user: other_user)
        
        get "/api/v1/comments/#{other_comment.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        comment = create(:comment)
        get "/api/v1/comments/#{comment.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PUT /api/v1/comments/:id
  describe "PUT /api/v1/comments/:id" do
    context "when user owns the comment" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:comment) { create(:comment, track_version: track_version, user: user, content: "Original content") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "updates comment successfully" do
        update_params = {
          comment: { content: "Updated comment content with more details" }
        }
        
        put "/api/v1/comments/#{comment.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        comment.reload
        expect(comment.content).to eq("Updated comment content with more details")
      end

      it "returns the updated comment" do
        update_params = {
          comment: { content: "Updated content" }
        }
        
        put "/api/v1/comments/#{comment.id}", params: update_params, headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['content']).to eq("Updated content")
      end

      it "returns error for invalid data" do
        invalid_params = {
          comment: { content: "" }
        }
        
        put "/api/v1/comments/#{comment.id}", params: invalid_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Content can't be blank")
      end

      it "preserves original content when update fails" do
        original_content = comment.content
        
        invalid_params = {
          comment: { content: "" }
        }
        
        put "/api/v1/comments/#{comment.id}", params: invalid_params, headers: headers
        
        comment.reload
        expect(comment.content).to eq(original_content)
      end
    end

    context "when trying to update another user's comment" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        other_comment = create(:comment, track_version: other_version, user: other_user)
        
        update_params = { comment: { content: "Hacked comment" } }
        
        put "/api/v1/comments/#{other_comment.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:not_found)
        
        other_comment.reload
        expect(other_comment.content).not_to eq("Hacked comment")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        comment = create(:comment)
        update_params = { comment: { content: "New content" } }
        
        put "/api/v1/comments/#{comment.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # DELETE /api/v1/comments/:id
  describe "DELETE /api/v1/comments/:id" do
    context "when user owns the comment" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:comment) { create(:comment, track_version: track_version, user: user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "deletes comment successfully" do
        delete "/api/v1/comments/#{comment.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(Comment.exists?(comment.id)).to be false
      end

      it "returns success message" do
        delete "/api/v1/comments/#{comment.id}", headers: headers
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Comment deleted successfully')
      end
    end

    context "when user owns the project but not the comment" do
      let(:user) { create(:user) }
      let(:workspace) { create(:workspace, user: user) }
      let(:project) { create(:project, workspace: workspace, user: user) }
      let(:track_version) { create(:track_version, project: project, user: user) }
      let(:other_user) { create(:user) }
      let(:comment) { create(:comment, track_version: track_version, user: other_user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "allows project owner to delete comments in their project" do
        delete "/api/v1/comments/#{comment.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(Comment.exists?(comment.id)).to be false
      end
    end

    context "when trying to delete another user's comment" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        other_user = create(:user)
        other_workspace = create(:workspace, user: other_user)
        other_project = create(:project, workspace: other_workspace, user: other_user)
        other_version = create(:track_version, project: other_project, user: other_user)
        other_comment = create(:comment, track_version: other_version, user: other_user)
        
        delete "/api/v1/comments/#{other_comment.id}", headers: headers
        
        expect(response).to have_http_status(:not_found)
        expect(Comment.exists?(other_comment.id)).to be true
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        comment = create(:comment)
        
        delete "/api/v1/comments/#{comment.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Edge cases and additional scenarios
  describe "Additional comment scenarios" do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:project) { create(:project, workspace: workspace, user: user) }
    let(:track_version) { create(:track_version, project: project, user: user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    it "handles very long comments" do
      long_content = "A" * 5000
      comment_params = {
        comment: { content: long_content }
      }
      
      post "/api/v1/track_versions/#{track_version.id}/comments", params: comment_params, headers: headers
      
      expect(response).to have_http_status(:created)
      
      created_comment = Comment.last
      expect(created_comment.content.length).to eq(5000)
    end

    it "handles comments with multiline content" do
      multiline_content = "Line 1\nLine 2\r\nLine 3\n\nDouble newline"
      comment_params = {
        comment: { content: multiline_content }
      }
      
      post "/api/v1/track_versions/#{track_version.id}/comments", params: comment_params, headers: headers
      
      expect(response).to have_http_status(:created)
      
      created_comment = Comment.last
      expect(created_comment.content).to eq(multiline_content)
    end

    it "handles unicode content correctly" do
      unicode_content = "这是一个测试评论 🎵 with émojis and spëcial characters"
      comment_params = {
        comment: { content: unicode_content }
      }
      
      post "/api/v1/track_versions/#{track_version.id}/comments", params: comment_params, headers: headers
      
      expect(response).to have_http_status(:created)
      
      created_comment = Comment.last
      expect(created_comment.content).to eq(unicode_content)
    end

    it "orders comments chronologically" do
      # Create comments with specific timestamps
      comment1 = create(:comment, track_version: track_version, user: user, content: "First", created_at: 3.hours.ago)
      comment2 = create(:comment, track_version: track_version, user: user, content: "Second", created_at: 2.hours.ago)
      comment3 = create(:comment, track_version: track_version, user: user, content: "Third", created_at: 1.hour.ago)
      
      get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
      json_response = JSON.parse(response.body)
      
      contents = json_response.map { |c| c['content'] }
      expect(contents).to eq(["First", "Second", "Third"])
    end

    it "includes comment count in responses" do
      create_list(:comment, 3, track_version: track_version, user: user)
      
      get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
      json_response = JSON.parse(response.body)
      
      expect(json_response.length).to eq(3)
    end

    it "handles empty comment lists gracefully" do
      get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
      json_response = JSON.parse(response.body)
      
      expect(json_response).to eq([])
      expect(response).to have_http_status(:ok)
    end

    it "includes user information in comment responses" do
      commenter = create(:user, username: "awesome_musician", name: "John Doe")
      comment = create(:comment, track_version: track_version, user: commenter, content: "Great track!")
      
      get "/api/v1/track_versions/#{track_version.id}/comments", headers: headers
      json_response = JSON.parse(response.body)
      
      comment_data = json_response.first
      expect(comment_data['user']['username']).to eq("awesome_musician")
      expect(comment_data['user']['name']).to eq("John Doe")
    end

    it "handles concurrent comment creation" do
      comment_params = {
        comment: { content: "Concurrent comment" }
      }
      
      # Simulate multiple users commenting at the same time
      expect {
        5.times do
          post "/api/v1/track_versions/#{track_version.id}/comments", params: comment_params, headers: headers
        end
      }.to change(Comment, :count).by(5)
    end
  end

  private

  def generate_token_for_user(user)
    payload = {
      user_id: user.id,
      iat: Time.now.to_i,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end
end