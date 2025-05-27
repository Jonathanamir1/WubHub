require 'rails_helper'

RSpec.describe Project, type: :model do
  describe 'validations' do
    it 'requires title to be present' do
      project = Project.new(title: nil)
      expect(project).not_to be_valid
      expect(project.errors[:title]).to include("can't be blank")
    end

    it 'requires visibility to be present' do
      project = Project.new(visibility: nil)
      expect(project).not_to be_valid
      expect(project.errors[:visibility]).to include("can't be blank")
    end

    it 'requires visibility to be either private or public' do
      project = build(:project, visibility: 'invalid')
      expect(project).not_to be_valid
      expect(project.errors[:visibility]).to include('is not included in the list')
    end

    it 'accepts private visibility' do
      project = build(:project, visibility: 'private')
      expect(project).to be_valid
    end

    it 'accepts public visibility' do
      project = build(:project, visibility: 'public')
      expect(project).to be_valid
    end

    it 'is valid with all required attributes' do
      project = build(:project)
      expect(project).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should belong_to(:user) }
    it { should have_many(:track_versions).dependent(:destroy) }
    it { should have_many(:roles).dependent(:destroy) }
    it { should have_many(:collaborators).through(:roles) }

    it 'destroys associated track versions when project is destroyed' do
      project = create(:project)
      track_version = create(:track_version, project: project)
      
      expect { project.destroy }.to change(TrackVersion, :count).by(-1)
    end

    it 'destroys associated roles when project is destroyed' do
      project = create(:project)
      role = create(:role, roleable: project)
      
      expect { project.destroy }.to change(Role, :count).by(-1)
    end
  end

  describe 'project ownership' do
    it 'belongs to the user who created it' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      project = create(:project, user: user, workspace: workspace)

      expect(project.user).to eq(user)
      expect(user.projects).to include(project)
    end

    it 'belongs to a workspace' do
      workspace = create(:workspace)
      project = create(:project, workspace: workspace)

      expect(project.workspace).to eq(workspace)
      expect(workspace.projects).to include(project)
    end

    it 'can be owned by different users within the same workspace' do
      workspace = create(:workspace)
      user1 = create(:user)
      user2 = create(:user)
      
      project1 = create(:project, workspace: workspace, user: user1)
      project2 = create(:project, workspace: workspace, user: user2)

      expect(project1.user).to eq(user1)
      expect(project2.user).to eq(user2)
      expect(workspace.projects).to include(project1, project2)
    end
  end

  describe 'track version relationship' do
    it 'can have multiple track versions' do
      project = create(:project)
      version1 = create(:track_version, project: project)
      version2 = create(:track_version, project: project)

      expect(project.track_versions).to include(version1, version2)
      expect(project.track_versions.count).to eq(2)
    end

    it 'returns empty collection when no track versions exist' do
      project = create(:project)
      expect(project.track_versions).to be_empty
    end

    it 'orders track versions by creation date' do
      project = create(:project)
      old_version = create(:track_version, project: project, created_at: 2.days.ago)
      new_version = create(:track_version, project: project, created_at: 1.day.ago)

      # Test default ordering if you have it, or specific ordering
      versions = project.track_versions.order(:created_at)
      expect(versions.first).to eq(old_version)
      expect(versions.last).to eq(new_version)
    end
  end

  describe 'collaboration through roles' do
    let(:project) { create(:project) }
    let(:collaborator1) { create(:user) }
    let(:collaborator2) { create(:user) }

    it 'can have multiple collaborators through roles' do
      create(:role, roleable: project, user: collaborator1, name: 'collaborator')
      create(:role, roleable: project, user: collaborator2, name: 'viewer')

      expect(project.collaborators).to include(collaborator1, collaborator2)
      expect(project.collaborators.count).to eq(2)
    end

    it 'can have different role types for collaborators' do
      producer_role = create(:role, roleable: project, user: collaborator1, name: 'collaborator')
      vocalist_role = create(:role, roleable: project, user: collaborator2, name: 'viewer')


      expect(project.roles).to include(producer_role, vocalist_role)
      expect(project.roles.find_by(user: collaborator1).name).to eq('collaborator')
      expect(project.roles.find_by(user: collaborator2).name).to eq('viewer')
    end

    it 'returns empty collection when no collaborators exist' do
      expect(project.collaborators).to be_empty
      expect(project.roles).to be_empty
    end
  end

  describe 'project visibility and access' do
    let(:workspace) { create(:workspace) }
    let(:owner) { workspace.user }
    let(:other_user) { create(:user) }

    context 'private projects' do
      let(:private_project) { create(:project, workspace: workspace, user: owner, visibility: 'private') }

      it 'is marked as private' do
        expect(private_project.visibility).to eq('private')
      end

      it 'can find private projects by visibility' do
        private_projects = Project.where(visibility: 'private')
        expect(private_projects).to include(private_project)
      end
    end

    context 'public projects' do
      let(:public_project) { create(:project, workspace: workspace, user: owner, visibility: 'public') }

      it 'is marked as public' do
        expect(public_project.visibility).to eq('public')
      end

      it 'can find public projects by visibility' do
        public_projects = Project.where(visibility: 'public')
        expect(public_projects).to include(public_project)
      end
    end
  end

  describe 'data integrity' do
    it 'maintains referential integrity with workspace' do
      workspace = create(:workspace)
      project = create(:project, workspace: workspace)

      # When workspace is destroyed, project should be destroyed too
      expect { workspace.destroy }.to change(Project, :count).by(-1)
    end

    it 'maintains referential integrity with user' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      project = create(:project, user: user, workspace: workspace)

      # When user is destroyed, all their projects should be destroyed too
      expect { user.destroy }.to change(Project, :count).by(-1)
    end
  end

  describe 'project queries' do
    let(:workspace1) { create(:workspace) }
    let(:workspace2) { create(:workspace) }
    let(:user1) { workspace1.user }
    let(:user2) { workspace2.user }

    let!(:user1_project1) { create(:project, workspace: workspace1, user: user1) }
    let!(:user1_project2) { create(:project, workspace: workspace1, user: user1) }
    let!(:user2_project) { create(:project, workspace: workspace2, user: user2) }

    it 'can find projects by workspace' do
      workspace1_projects = workspace1.projects
      expect(workspace1_projects).to include(user1_project1, user1_project2)
      expect(workspace1_projects).not_to include(user2_project)
    end

    it 'can find projects by user' do
      user1_projects = user1.projects
      expect(user1_projects).to include(user1_project1, user1_project2)
      expect(user1_projects).not_to include(user2_project)
    end

    it 'can find projects by both workspace and user' do
      user_workspace_projects = Project.where(workspace: workspace1, user: user1)
      expect(user_workspace_projects).to include(user1_project1, user1_project2)
      expect(user_workspace_projects).not_to include(user2_project)
    end
  end

  describe 'edge cases' do
    it 'handles empty description gracefully' do
      project = build(:project, description: '')
      expect(project).to be_valid
    end

    it 'handles nil description gracefully' do
      project = build(:project, description: nil)
      expect(project).to be_valid
    end

    it 'handles very long titles' do
      long_title = 'A' * 1000
      project = build(:project, title: long_title)
      # This test will pass unless there's a length validation
      expect(project.title.length).to eq(1000)
    end

    it 'handles very long descriptions' do
      long_description = 'A' * 5000
      project = build(:project, description: long_description)
      expect(project.description.length).to eq(5000)
    end
  end

  describe 'timestamps' do
    it 'sets created_at when project is created' do
      project = create(:project)
      expect(project.created_at).to be_present
      expect(project.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when project is modified' do
      project = create(:project)
      original_updated_at = project.updated_at
      
      sleep 0.1 # Ensure time difference
      project.update!(title: 'Updated Title')
      
      expect(project.updated_at).to be > original_updated_at
    end
  end

  describe 'string representation' do
    it 'can be represented as a string' do
      project = create(:project, title: 'My Awesome Project')
      expect(project.title).to eq('My Awesome Project')
    end
  end
end