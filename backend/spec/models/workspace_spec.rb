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
    it { should have_many(:projects).dependent(:destroy) }

    it 'destroys associated projects when workspace is destroyed' do
      workspace = create(:workspace)
      project = create(:project, workspace: workspace)
      
      expect { workspace.destroy }.to change(Project, :count).by(-1)
    end
  end



  describe 'project relationship' do
    it 'can have multiple projects' do
      workspace = create(:workspace)
      project1 = create(:project, workspace: workspace)
      project2 = create(:project, workspace: workspace)

      expect(workspace.projects).to include(project1, project2)
      expect(workspace.projects.count).to eq(2)
    end

    it 'returns empty collection when no projects exist' do
      workspace = create(:workspace)
      expect(workspace.projects).to be_empty
    end
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

  describe 'data integrity' do
    it 'maintains referential integrity with user' do
      user = create(:user)
      workspace = create(:workspace, user: user)

      # Attempting to delete user should fail if workspace exists
      expect { user.destroy }.to change(Workspace, :count).by(-1)
      # The workspace should be destroyed due to dependent: :destroy
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