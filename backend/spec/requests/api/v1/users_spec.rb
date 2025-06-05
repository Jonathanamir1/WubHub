require 'rails_helper'

RSpec.describe "Api::V1::Users", type: :request do
  
  # GET /api/v1/users (search/list users)
  describe "GET /api/v1/users" do
    context "when user is authenticated" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/users", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns users as JSON array" do
        get "/api/v1/users", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to be_an(Array)
      end

      it "returns all users when no search parameter" do
        user1 = create(:user, username: "musician1")
        user2 = create(:user, username: "producer2")
        user3 = create(:user, username: "vocalist3")
        
        get "/api/v1/users", headers: headers
        json_response = JSON.parse(response.body)
        
        usernames = json_response.map { |u| u['username'] }
        expect(usernames).to include("musician1", "producer2", "vocalist3")
      end

      it "filters users by username when search parameter provided" do
        user1 = create(:user, username: "musician_rock")
        user2 = create(:user, username: "musician_jazz")
        user3 = create(:user, username: "producer_house")
        
        get "/api/v1/users", params: { search: "musician" }, headers: headers
        json_response = JSON.parse(response.body)
        
        usernames = json_response.map { |u| u['username'] }
        expect(usernames).to include("musician_rock", "musician_jazz")
        expect(usernames).not_to include("producer_house")
      end

      it "returns empty array when no users match search" do
        create(:user, username: "testuser")
        
        get "/api/v1/users", params: { search: "nonexistent" }, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).to eq([])
      end

      it "excludes sensitive information from response" do
        other_user = create(:user, email: "secret@example.com", password_digest: "encrypted")
        
        get "/api/v1/users", headers: headers
        json_response = JSON.parse(response.body)
        
        user_data = json_response.find { |u| u['id'] == other_user.id }
        expect(user_data).not_to have_key('password_digest')
        expect(user_data).not_to have_key('email') # Email should be private in user listings
      end

      it "includes public profile information" do
        other_user = create(:user, username: "testmusician", name: "Test Musician", bio: "I make beats")
        
        get "/api/v1/users", headers: headers
        json_response = JSON.parse(response.body)
        
        user_data = json_response.find { |u| u['id'] == other_user.id }
        expect(user_data['username']).to eq("testmusician")
        expect(user_data['name']).to eq("Test Musician")
        expect(user_data['bio']).to eq("I make beats")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/users"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # GET /api/v1/users/:id (show user profile)
  describe "GET /api/v1/users/:id" do
    context "when user exists" do
      let(:current_user) { create(:user) }
      let(:target_user) { create(:user, username: "targetuser", name: "Target User", bio: "Music producer") }
      let(:token) { generate_token_for_user(current_user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns success status" do
        get "/api/v1/users/#{target_user.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns user profile data" do
        get "/api/v1/users/#{target_user.id}", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['id']).to eq(target_user.id)
        expect(json_response['username']).to eq("targetuser")
        expect(json_response['name']).to eq("Target User")
        expect(json_response['bio']).to eq("Music producer")
      end

      it "includes profile image URL when attached" do
        # Create a test image file
        file = Tempfile.new(['test_avatar', '.jpg'])
        file.write('fake image data')
        file.rewind
        
        target_user.profile_image.attach(
          io: file,
          filename: 'avatar.jpg',
          content_type: 'image/jpeg'
        )
        
        get "/api/v1/users/#{target_user.id}", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['profile_image_url']).to be_present
        
        file.close
        file.unlink
      end

      it "returns null profile_image_url when no image attached" do
        get "/api/v1/users/#{target_user.id}", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['profile_image_url']).to be_nil
      end

      it "excludes sensitive information" do
        get "/api/v1/users/#{target_user.id}", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response).not_to have_key('password_digest')
      end

      it "includes email only when viewing own profile" do
        # Viewing someone else's profile - no email
        get "/api/v1/users/#{target_user.id}", headers: headers
        json_response = JSON.parse(response.body)
        expect(json_response).not_to have_key('email')
        
        # Viewing own profile - includes email
        get "/api/v1/users/#{current_user.id}", headers: headers
        json_response = JSON.parse(response.body)
        expect(json_response['email']).to eq(current_user.email)
      end
    end

    context "when user does not exist" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        get "/api/v1/users/99999", headers: headers
        expect(response).to have_http_status(:not_found)
      end

      it "returns error message" do
        get "/api/v1/users/99999", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['error']).to eq('User not found')
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        user = create(:user)
        get "/api/v1/users/#{user.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # PUT /api/v1/users/:id (update user profile)
  describe "PUT /api/v1/users/:id" do
    context "when updating own profile" do
      let(:user) { create(:user, name: "Original Name", bio: "Original bio") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "updates user profile successfully" do
        update_params = {
          user: {
            name: "Updated Name",
            bio: "Updated bio",
            username: "updatedusername"
          }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        user.reload
        expect(user.name).to eq("Updated Name")
        expect(user.bio).to eq("Updated bio")
        expect(user.username).to eq("updatedusername")
      end

      it "returns the updated user data" do
        update_params = {
          user: { name: "Updated Name" }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['name']).to eq("Updated Name")
        expect(json_response['id']).to eq(user.id)
      end

      it "allows partial updates" do
        original_bio = user.bio
        update_params = {
          user: { name: "Just Name Update" }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        user.reload
        expect(user.name).to eq("Just Name Update")
        expect(user.bio).to eq(original_bio) # Should remain unchanged
      end

      it "allows password updates" do
        update_params = {
          user: {
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        user.reload
        expect(user.authenticate("newpassword123")).to eq(user)
        expect(user.authenticate("oldpassword")).to be_falsey
      end

      it "returns error for invalid password confirmation" do
        update_params = {
          user: {
            password: "newpassword123",
            password_confirmation: "differentpassword"
          }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Password confirmation doesn't match Password")
      end

      it "returns error when username is taken" do
        other_user = create(:user, username: "taken_username")
        
        update_params = {
          user: { username: "taken_username" }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Username has already been taken")
      end

      it "returns error when email is taken" do
        other_user = create(:user, email: "taken@example.com")
        
        update_params = {
          user: { email: "taken@example.com" }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Email has already been taken")
      end

      it "returns error for invalid email format" do
        update_params = {
          user: { email: "invalid_email_format" }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Email is invalid")
      end

      it "handles profile image upload" do
        file = Tempfile.new(['test_avatar', '.jpg'])
        file.write('fake image data')
        file.rewind
        
        update_params = {
          user: { name: "Updated Name" },
          profile_image: Rack::Test::UploadedFile.new(file.path, 'image/jpeg', true)
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        user.reload
        expect(user.profile_image).to be_attached
        expect(user.profile_image.filename.to_s).to include('test_avatar')
        
        file.close
        file.unlink
      end
    end

    context "when trying to update another user's profile" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user, name: "Other User") }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns forbidden status" do
        update_params = {
          user: { name: "Hacked Name" }
        }
        
        put "/api/v1/users/#{other_user.id}", params: update_params, headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the other user's profile" do
        original_name = other_user.name
        update_params = {
          user: { name: "Hacked Name" }
        }
        
        put "/api/v1/users/#{other_user.id}", params: update_params, headers: headers
        
        other_user.reload
        expect(other_user.name).to eq(original_name)
      end

      it "returns appropriate error message" do
        update_params = {
          user: { name: "Hacked Name" }
        }
        
        put "/api/v1/users/#{other_user.id}", params: update_params, headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['error']).to eq('You can only update your own profile')
      end
    end

    context "when user does not exist" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        update_params = {
          user: { name: "New Name" }
        }
        
        put "/api/v1/users/99999", params: update_params, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        user = create(:user)
        update_params = {
          user: { name: "New Name" }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # DELETE /api/v1/users/:id (delete user account)
  describe "DELETE /api/v1/users/:id" do
    context "when deleting own account" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }





      it "deletes associated workspaces" do
        workspace = create(:workspace, user: user)
        
        expect {
          delete "/api/v1/users/#{user.id}", headers: headers
        }.to change(Workspace, :count).by(-1)
      end






    end

    context "when trying to delete another user's account" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns forbidden status" do
        delete "/api/v1/users/#{other_user.id}", headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "does not delete the other user's account" do
        delete "/api/v1/users/#{other_user.id}", headers: headers
        expect(User.exists?(other_user.id)).to be true
      end

      it "returns appropriate error message" do
        delete "/api/v1/users/#{other_user.id}", headers: headers
        json_response = JSON.parse(response.body)
        
        expect(json_response['error']).to eq('You can only delete your own account')
      end
    end

    context "when user does not exist" do
      let(:user) { create(:user) }
      let(:token) { generate_token_for_user(user) }
      let(:headers) { { 'Authorization' => "Bearer #{token}" } }

      it "returns not found status" do
        delete "/api/v1/users/99999", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        user = create(:user)
        delete "/api/v1/users/#{user.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Edge cases and additional scenarios
  describe "edge cases" do
    let(:user) { create(:user) }
    let(:token) { generate_token_for_user(user) }
    let(:headers) { { 'Authorization' => "Bearer #{token}" } }

    context "when handling large profile images" do
      it "handles profile image upload within size limits" do
        # Create a larger test image (but still reasonable)
        file = Tempfile.new(['large_avatar', '.jpg'])
        file.write('x' * 1024 * 100) # 100KB
        file.rewind
        
        update_params = {
          user: { name: "Updated Name" },
          profile_image: Rack::Test::UploadedFile.new(file.path, 'image/jpeg', true)
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        user.reload
        expect(user.profile_image).to be_attached
        
        file.close
        file.unlink
      end
    end

    context "when handling special characters in usernames" do
      it "allows valid special characters in usernames" do
        update_params = {
          user: { username: "user_name-123" }
        }
        
        put "/api/v1/users/#{user.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        
        user.reload
        expect(user.username).to eq("user_name-123")
      end
    end

    context "when searching with edge cases" do
      it "handles case-insensitive search" do
        create(:user, username: "MixMaster")
        
        get "/api/v1/users", params: { search: "mixmaster" }, headers: headers
        json_response = JSON.parse(response.body)
        
        usernames = json_response.map { |u| u['username'] }
        expect(usernames).to include("MixMaster")
      end

      it "handles partial username matches" do
        create(:user, username: "guitarist_pro")
        create(:user, username: "bassist_amateur")
        
        get "/api/v1/users", params: { search: "ist" }, headers: headers
        json_response = JSON.parse(response.body)
        
        usernames = json_response.map { |u| u['username'] }
        expect(usernames).to include("guitarist_pro", "bassist_amateur")
      end

      it "handles empty search parameter" do
        create(:user, username: "testuser")
        
        get "/api/v1/users", params: { search: "" }, headers: headers
        json_response = JSON.parse(response.body)
        
        # Should return all users when search is empty
        expect(json_response.length).to be >= 1
      end
    end
  end
end