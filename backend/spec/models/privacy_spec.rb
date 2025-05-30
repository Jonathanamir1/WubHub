  require 'rails_helper'

  RSpec.describe Privacy, type: :model do
    describe 'associations' do
      it 'allows project privacy' do
        project = create(:project)
        privacy = Privacy.new(user: create(:user), privatable: project, level: 'public')
        
        expect(privacy.privatable).to eq(project)
        expect(privacy.privatable_type).to eq('Project')
      end

      it 'allows track version privacy' do
        track_version = create(:track_version)
        privacy = Privacy.new(user: create(:user), privatable: track_version, level: 'private')
        
        expect(privacy.privatable).to eq(track_version)
        expect(privacy.privatable_type).to eq('TrackVersion')
      end

      it 'allows track content privacy' do
        track_content = create(:track_content)
        privacy = Privacy.new(user: create(:user), privatable: track_content, level: 'inherited')
        
        expect(privacy.privatable).to eq(track_content)
        expect(privacy.privatable_type).to eq('TrackContent')
      end
    end
    
    describe 'validations' do
      it 'requires level to be present' do
        privacy = Privacy.new(user: create(:user), privatable: create(:project), level: nil)
        expect(privacy).not_to be_valid
        expect(privacy.errors[:level]).to include("can't be blank")
      end

      it 'only allows valid privacy levels' do
        valid_privacy = Privacy.new(user: create(:user), privatable: create(:project), level: 'inherited')
        invalid_privacy = Privacy.new(user: create(:user), privatable: create(:project), level: 'invalid_level')
        
        expect(valid_privacy).to be_valid
        expect(invalid_privacy).not_to be_valid
        expect(invalid_privacy.errors[:level]).to include('is not included in the list')
      end  
      # Only one Privacy record per resource (uniqueness)
      it 'prevents duplicate privacy records for same resource' do
        project = create(:project)
        user = create(:user)
        
        # Create first privacy record
        Privacy.create!(user: user, privatable: project, level: 'private')
        
        # Try to create second privacy record for same project
        duplicate_privacy = Privacy.new(user: user, privatable: project, level: 'public')
        
        expect(duplicate_privacy).not_to be_valid
        expect(duplicate_privacy.errors[:user_id]).to include('has already been taken')
      end
    end

    describe 'instance methods' do
      it 'has convenience method to check if private' do
        project = create(:project)
        privacy = create(:privacy, :private_level, privatable: project)
        expect(privacy.private?).to be true
        
        privacy.update(level: 'public')
        expect(privacy.private?).to be false
      end
      it 'has convenience method to check if public' do
        track_version = create(:track_version)
        privacy = create(:privacy, :public_level, privatable: track_version)
        expect(privacy.public?).to be true
      end

      it 'has convenience method to check if inherited' do
        track_content = create(:track_version)
        privacy = create(:privacy, privatable: track_content)
        expect(privacy.level).to eq("inherited")
      end
    end
    describe 'privacy association' do
      it 'can have a privacy record' do
        project = create(:project)
        privacy = create(:privacy, privatable: project)
        
        expect(project.privacy).to eq(privacy)
        expect(privacy.privatable).to eq(project)
      end
    end
    describe 'workspace access control' do
      let(:owner) { create(:user) }
      let(:collaborator) { create(:user) }
      let(:stranger) { create(:user) }
      let(:workspace) { create(:workspace, user: owner) }

      context 'when workspace is private' do
        it 'only allows owner and collaborators to access' do
          create(:privacy, privatable: workspace, user: owner, level: 'private')
          create(:role, user: collaborator, roleable: workspace, name: 'collaborator')
          
          expect(workspace.accessible_by?(owner)).to be true
          expect(workspace.accessible_by?(collaborator)).to be true
          expect(workspace.accessible_by?(stranger)).to be false
        end
      end

      context 'when workspace is public' do
        it 'allows anyone to access' do
          create(:privacy, privatable: workspace, user: owner, level: 'public')
          
          expect(workspace.accessible_by?(owner)).to be true
          expect(workspace.accessible_by?(collaborator)).to be true
          expect(workspace.accessible_by?(stranger)).to be true
        end
      end
    end

    describe 'project access control' do
      let(:owner) { create(:user) }
      let(:workspace_collaborator) { create(:user) }
      let(:stranger) { create(:user) }
      let(:workspace) { create(:workspace, user: owner) }
      let(:project) { create(:project, user: owner, workspace: workspace) }

      context 'when project is public' do
        it 'allows anyone to access' do
          create(:privacy, privatable: project, user: owner, level: 'public')
          
          expect(project.accessible_by?(owner)).to be true
          expect(project.accessible_by?(workspace_collaborator)).to be true
          expect(project.accessible_by?(stranger)).to be true
        end
      end

      context 'when project is private' do
        it 'only allows owner to access' do
          create(:privacy, privatable: project, user: owner, level: 'private')
          
          expect(project.accessible_by?(owner)).to be true
          expect(project.accessible_by?(workspace_collaborator)).to be false
          expect(project.accessible_by?(stranger)).to be false
        end
      end

      context 'when project is inherited' do
        it 'allows workspace collaborators to access' do
          create(:role, user: workspace_collaborator, roleable: workspace, name: 'collaborator')
          create(:privacy, privatable: project, user: owner, level: 'inherited')
          
          expect(project.accessible_by?(owner)).to be true
          expect(project.accessible_by?(workspace_collaborator)).to be true
          expect(project.accessible_by?(stranger)).to be false
        end
      end
    end

    describe 'track version access control' do
      let(:owner) { create(:user) }
      let(:project_collaborator) { create(:user) }
      let(:stranger) { create(:user) }
      let(:workspace) { create(:workspace, user: owner) }
      let(:project) { create(:project, user: owner, workspace: workspace) }
      let(:track_version) { create(:track_version, user: owner, project: project) }

      context 'when track version is private' do
        it 'only allows owner to access' do
          create(:role, user: project_collaborator, roleable: project, name: 'collaborator')
          create(:privacy, privatable: track_version, user: owner, level: 'private')
          
          expect(track_version.accessible_by?(owner)).to be true
          expect(track_version.accessible_by?(project_collaborator)).to be false
          expect(track_version.accessible_by?(stranger)).to be false
        end
      end

      context 'when track version is inherited' do
        it 'allows project collaborators to access' do
          create(:role, user: project_collaborator, roleable: project, name: 'collaborator')
          create(:privacy, privatable: track_version, user: owner, level: 'inherited')
          
          expect(track_version.accessible_by?(owner)).to be true
          expect(track_version.accessible_by?(project_collaborator)).to be true
          expect(track_version.accessible_by?(stranger)).to be false
        end
      end
    end

    describe 'track content access control' do
      let(:owner) { create(:user) }
      let(:track_collaborator) { create(:user) }
      let(:project_collaborator) { create(:user) }
      let(:stranger) { create(:user) }
      let(:workspace) { create(:workspace, user: owner) }
      let(:project) { create(:project, user: owner, workspace: workspace) }
      let(:track_version) { create(:track_version, user: owner, project: project) }
      let(:track_content) { create(:track_content, track_version: track_version) }

      context 'when track content is private' do
        it 'only allows owner to access' do
          create(:role, user: track_collaborator, roleable: track_version, name: 'collaborator')
          create(:role, user: project_collaborator, roleable: project, name: 'collaborator')
          create(:privacy, privatable: track_content, level: 'private')
          
          expect(track_content.accessible_by?(owner)).to be true
          expect(track_content.accessible_by?(track_collaborator)).to be false
          expect(track_content.accessible_by?(project_collaborator)).to be false
          expect(track_content.accessible_by?(stranger)).to be false
        end
      end

      context 'when track content is inherited' do
        it 'allows track version collaborators to access' do
          create(:role, user: track_collaborator, roleable: track_version, name: 'collaborator')
          create(:role, user: project_collaborator, roleable: project, name: 'collaborator')
          create(:privacy, privatable: track_content, level: 'inherited')
          
          expect(track_content.accessible_by?(owner)).to be true
          expect(track_content.accessible_by?(track_collaborator)).to be true
          expect(track_content.accessible_by?(project_collaborator)).to be true
          expect(track_content.accessible_by?(stranger)).to be false
        end
      end
    end
  end