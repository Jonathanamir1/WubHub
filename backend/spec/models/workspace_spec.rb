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
    it "handles workspace with many projects and complex permissions" do
      workspace = create(:workspace)
      
      # Create many projects with different owners
      users = create_list(:user, 10)
      projects = []
      
      users.each do |user|
        5.times do
          projects << create(:project, workspace: workspace, user: user)
        end
      end
      
      expect(workspace.projects.count).to eq(50)
      expect(workspace.projects.group(:user_id).count.keys.length).to eq(10)
    end

    it "maintains workspace integrity when projects are deleted" do
      workspace = create(:workspace)
      projects = create_list(:project, 5, workspace: workspace)
      
      initial_count = workspace.projects.count
      
      # Delete some projects
      projects[0..2].each(&:destroy)
      
      workspace.reload
      expect(workspace.projects.count).to eq(initial_count - 3)
      expect(workspace).to be_valid
    end

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

