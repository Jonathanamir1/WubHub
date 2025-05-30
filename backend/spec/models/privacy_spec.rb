require 'rails_helper'

RSpec.describe Privacy, type: :model do
  describe 'basic validations' do
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
    end

    it 'prevents workspaces from being set to private' do
      workspace = create(:workspace)
      invalid_privacy = build(:privacy, privatable: workspace, level: 'private', user: workspace.user)
      
      expect(invalid_privacy).not_to be_valid
      expect(invalid_privacy.errors[:level]).to include("Workspaces cannot be private - remove collaborators instead")
    end
  end

  describe 'music studio workspace model' do
    let(:artist) { create(:user) }
    let(:producer) { create(:user) }
    let(:vocalist) { create(:user) }
    let(:fan) { create(:user) }
    let(:workspace) { create(:workspace, user: artist, name: "John Doe Music") }
    let(:album) { create(:project, workspace: workspace, user: artist, title: "Album 1") }
    let(:track) { create(:track_version, project: album, user: artist, title: "Song Demo") }
    let(:vocal_file) { create(:track_content, track_version: track, user: artist) }

    context 'workspace membership controls base access' do
      it 'workspace members see all content by default' do
        # Add team members
        create(:role, user: producer, roleable: workspace, name: 'collaborator')
        create(:role, user: vocalist, roleable: workspace, name: 'commenter')
        
        # Everyone in workspace can see everything
        [producer, vocalist].each do |member|
          expect(workspace.accessible_by?(member)).to be true
          expect(album.accessible_by?(member)).to be true
          expect(track.accessible_by?(member)).to be true
          expect(vocal_file.accessible_by?(member)).to be true
        end
        
        # Non-members cannot see anything
        expect(workspace.accessible_by?(fan)).to be false
        expect(album.accessible_by?(fan)).to be false
        expect(track.accessible_by?(fan)).to be false
        expect(vocal_file.accessible_by?(fan)).to be false
      end
    end

    context 'private work-in-progress workflow' do
      before do
        create(:role, user: producer, roleable: workspace, name: 'collaborator')
        create(:role, user: vocalist, roleable: workspace, name: 'commenter')
      end

      it 'allows private work on track versions' do
        # Producer works on private mix
        create(:privacy, privatable: track, user: producer, level: 'private')
        track.reload
        
        # Only producer can see private track
        expect(track.accessible_by?(producer)).to be true
        expect(track.accessible_by?(artist)).to be false    # Even owner can't see
        expect(track.accessible_by?(vocalist)).to be false
        
        # But album is still visible to everyone
        expect(album.accessible_by?(producer)).to be true
        expect(album.accessible_by?(vocalist)).to be true
      end

      it 'allows private work on track contents' do
        # Vocalist works on private vocal file
        create(:privacy, privatable: vocal_file, user: vocalist, level: 'private')
        vocal_file.reload
        
        # Only vocalist can see private content
        expect(vocal_file.accessible_by?(vocalist)).to be true
        expect(vocal_file.accessible_by?(artist)).to be false
        expect(vocal_file.accessible_by?(producer)).to be false
        
        # Track and album still visible
        expect(track.accessible_by?(producer)).to be true
        expect(album.accessible_by?(producer)).to be true
      end
    end

    context 'public sharing for promotion' do
      it 'allows public access to tracks via link' do
        # Track is ready for public sharing
        create(:privacy, privatable: track, user: artist, level: 'public')
        track.reload
        
        # Anyone can access public track
        expect(track.accessible_by?(fan)).to be true
        expect(track.accessible_by?(artist)).to be true
        expect(track.accessible_by?(producer)).to be true
      end

      it 'allows public workspace discovery' do
        # Workspace becomes discoverable
        create(:privacy, privatable: workspace, user: artist, level: 'public')
        workspace.reload
        
        # Anyone can discover public workspace
        expect(workspace.accessible_by?(fan)).to be true
      end
    end

    context 'hierarchy inheritance works correctly' do
      before do
        create(:role, user: producer, roleable: workspace, name: 'collaborator')
      end

      it 'inherits workspace access down the hierarchy' do
        # All items inherit workspace access by default
        expect(album.accessible_by?(producer)).to be true
        expect(track.accessible_by?(producer)).to be true
        expect(vocal_file.accessible_by?(producer)).to be true
      end

      it 'private items break inheritance chain' do
        # Make album private
        create(:privacy, privatable: album, user: artist, level: 'private')
        album.reload
        track.reload
        vocal_file.reload
        
        # Producer loses access to album and everything inside
        expect(album.accessible_by?(producer)).to be false
        expect(track.accessible_by?(producer)).to be false    # Inherits from private album
        expect(vocal_file.accessible_by?(producer)).to be false # Inherits from private track
      end
    end

    context 'edge cases' do
    
      it 'handles user who is not in workspace trying to access public item' do
        # Fan can't access workspace
        expect(workspace.accessible_by?(fan)).to be false
        
        # But can access public track directly
        create(:privacy, privatable: track, user: artist, level: 'public')
        track.reload
        expect(track.accessible_by?(fan)).to be true
      end
      
      it 'handles multiple privacy settings in hierarchy' do
        create(:role, user: producer, roleable: workspace, name: 'collaborator')
        
        # Public album in private workspace
        create(:privacy, privatable: album, user: artist, level: 'public')
        album.reload
        
        # Producer (workspace member) can see album
        expect(album.accessible_by?(producer)).to be true
        # Fan (non-member) can also see public album
        expect(album.accessible_by?(fan)).to be true
      end
    end
  end


end