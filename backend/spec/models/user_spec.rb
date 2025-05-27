require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'requires email to be present' do
      user = User.new(email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires username to be present' do
      user = User.new(username: nil)
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("can't be blank")
    end

    it 'requires email to be unique' do
      create(:user, email: 'test@example.com')
      user = User.new(email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'requires username to be unique' do
      create(:user, username: 'testuser')
      user = User.new(username: 'testuser')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include('has already been taken')
    end

    it 'requires email to have valid format' do
      user = User.new(email: 'invalid_email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'accepts valid email formats' do
      user = build(:user, email: 'valid@example.com')
      expect(user).to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:workspaces).dependent(:destroy) }
    it { should have_many(:projects).dependent(:destroy) }
    it { should have_many(:roles).dependent(:destroy) }
    it { should have_many(:track_versions).dependent(:destroy) }
    it { should have_one_attached(:profile_image) }
  end

  describe 'secure password' do
    it { should have_secure_password }
    
    it 'authenticates with correct password' do
      user = create(:user, password: 'password123')
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'does not authenticate with incorrect password' do
      user = create(:user, password: 'password123')
      expect(user.authenticate('wrongpassword')).to be_falsey
    end
  end

  describe '#all_workspaces' do
    it 'returns workspaces the user owns' do
      user = create(:user)
      workspace1 = create(:workspace, user: user)
      workspace2 = create(:workspace, user: user)
      other_workspace = create(:workspace)

      expect(user.all_workspaces).to contain_exactly(workspace1, workspace2)
    end
  end

  describe '#all_projects' do
    it 'returns owned and collaborated projects' do
      user = create(:user)
      owned_project = create(:project, user: user)
      
      # Create a project where user is a collaborator (using polymorphic role)
      other_project = create(:project)
      create(:role, user: user, roleable: other_project)
      
      expect(user.all_projects).to include(owned_project, other_project)
    end
  end

  describe '#collaborated_projects' do
    it 'returns projects where user has roles' do
      user = create(:user)
      
      # Projects where user is a collaborator
      project1 = create(:project)
      project2 = create(:project)
      create(:role, user: user, roleable: project1, name: 'collaborator')
      create(:role, user: user, roleable: project2, name: 'viewer')
      
      # Project where user has no role (should not appear)
      project3 = create(:project)
      
      # User's own project (should not appear in collaborated_projects)
      owned_project = create(:project, user: user)
      
      collaborated = user.collaborated_projects
      expect(collaborated).to include(project1, project2)
      expect(collaborated).not_to include(project3, owned_project)
    end

    it 'returns empty array when user has no collaboration roles' do
      user = create(:user)
      owned_project = create(:project, user: user)
      
      expect(user.collaborated_projects).to be_empty
    end
  end

  describe '#recent_projects' do
    it 'returns recent projects ordered by updated_at' do
      user = create(:user)
      old_project = create(:project, user: user, updated_at: 2.days.ago)
      recent_project = create(:project, user: user, updated_at: 1.day.ago)

      expect(user.recent_projects).to eq([recent_project, old_project])
    end

    it 'limits results to specified count' do
      user = create(:user)
      5.times { create(:project, user: user) }

      expect(user.recent_projects(3).count).to eq(3)
    end
  end

  describe '#accessible_workspaces' do
    it 'returns workspaces the user owns' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      other_workspace = create(:workspace)

      expect(user.accessible_workspaces).to include(workspace)
      expect(user.accessible_workspaces).not_to include(other_workspace)
    end
  end

  describe '#owned_workspaces' do
    it 'returns only workspaces owned by the user' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      other_workspace = create(:workspace)

      expect(user.owned_workspaces).to include(workspace)
      expect(user.owned_workspaces).not_to include(other_workspace)
    end
  end
  end

  describe '#display_name' do
    it 'returns name when name is present' do
      user = User.new(name: 'John Doe', username: 'johndoe')
      expect(user.display_name).to eq('John Doe')
    end

    it 'returns username when name is blank' do
      user = User.new(name: '', username: 'johndoe')
      expect(user.display_name).to eq('johndoe')
    end

    it 'returns username when name is nil' do
      user = User.new(name: nil, username: 'johndoe')
      expect(user.display_name).to eq('johndoe')
    end
  end

  describe 'role-based access' do
    let(:user) { create(:user) }

    it 'can have roles on different types of resources' do
      workspace = create(:workspace)
      project = create(:project)
      track_version = create(:track_version)

      workspace_role = create(:role, user: user, roleable: workspace, name: 'owner')
      project_role = create(:role, user: user, roleable: project, name: 'collaborator')
      version_role = create(:role, user: user, roleable: track_version, name: 'viewer')

      expect(user.roles.count).to eq(3)
      expect(user.roles.pluck(:roleable_type)).to contain_exactly('Workspace', 'Project', 'TrackVersion')
    end

    it 'can check access to resources through has_access_to? method' do
      workspace = create(:workspace)
      project = create(:project, workspace: workspace)
      
      # User has workspace role, should have access to project in that workspace
      create(:role, user: user, roleable: workspace, name: 'owner')
      
      expect(user.has_access_to?(project)).to be true
    end

    it 'returns false for resources without access' do
      project = create(:project)
      
      expect(user.has_access_to?(project)).to be false
    end
  end
end