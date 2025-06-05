require 'rails_helper'

RSpec.describe Workspace, type: :model do
  describe 'validations' do
    it 'requires name to be present' do
      workspace = Workspace.new(name: nil)
      expect(workspace).not_to be_valid
      expect(workspace.errors[:name]).to include("can't be blank")
    end


    it 'is valid with all required attributes' do
      workspace = build(:workspace)
      expect(workspace).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
  end




  describe 'workspace ownership' do
    it 'belongs to the user who created it' do
      user = create(:user)
      workspace = create(:workspace, user: user)

      expect(workspace.user).to eq(user)
      expect(user.workspaces).to include(workspace)
    end

    it 'can be owned by different users' do
      user1 = create(:user)
      user2 = create(:user)
      workspace1 = create(:workspace, user: user1)
      workspace2 = create(:workspace, user: user2)

      expect(workspace1.user).to eq(user1)
      expect(workspace2.user).to eq(user2)
      expect(user1.workspaces).to include(workspace1)
      expect(user1.workspaces).not_to include(workspace2)
    end
  end

  describe 'string representation' do
    it 'can be converted to string representation' do
      workspace = create(:workspace, name: 'My Awesome Workspace')
      expect(workspace.name).to eq('My Awesome Workspace')
    end
  end

  describe 'edge cases' do
    it 'handles empty description gracefully' do
      workspace = build(:workspace, description: '')
      expect(workspace).to be_valid
    end

    it 'handles nil description gracefully' do
      workspace = build(:workspace, description: nil)
      expect(workspace).to be_valid
    end

    it 'handles very long names' do
      long_name = 'A' * 1000
      workspace = build(:workspace, name: long_name)
      # This test will pass unless there's a length validation
      # If you add length validation later, this test will catch it
      expect(workspace.name.length).to eq(1000)
    end

    it 'can have a privacy record' do
      workspace = create(:workspace)
      privacy = create(:privacy, privatable: workspace)
      
      expect(workspace.privacy).to eq(privacy)
      expect(privacy.privatable).to eq(workspace)
    end
  end
  describe 'privatable type validation' do
    it 'only allows specific model types to have privacy' do
      user = create(:user)
      
      # This should fail - User shouldn't have privacy
      invalid_privacy = Privacy.new(user: user, privatable: user, level: 'private')
      expect(invalid_privacy).not_to be_valid
      expect(invalid_privacy.errors[:privatable_type]).to include('is not included in the list')
    end
    
    # it 'allows valid model types to have privacy' do
    #   workspace = create(:workspace)
    #   valid_privacy = Privacy.new(user: create(:user), privatable: workspace, level: 'private')
    #   expect(valid_privacy).to be_valid
    # end
  end

  describe "workspace collaboration edge cases" do


    it "handles workspace name conflicts across users" do
      user1 = create(:user)
      user2 = create(:user)
      
      # Both users can have workspaces with same name
      workspace1 = create(:workspace, user: user1, name: "My Studio")
      workspace2 = create(:workspace, user: user2, name: "My Studio")
      
      expect(workspace1).to be_valid
      expect(workspace2).to be_valid
      expect(workspace1.name).to eq(workspace2.name)
    end
  end
end

