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

    describe 'complex inheritance scenarios' do
      let(:artist) { create(:user) }
      let(:producer) { create(:user) }
      let(:label_exec) { create(:user) }
      let(:fan) { create(:user) }
      
      let(:studio) { create(:workspace, user: artist, name: "Artist Studio") }
      let(:album) { create(:project, workspace: studio, user: artist, title: "New Album") }
      let(:track) { create(:track_version, project: album, user: artist, title: "Song Demo") }
      let(:vocal_file) { create(:track_content, track_version: track, user: artist) }

      context 'multiple privacy layers' do
        it 'handles public content in private project in public workspace' do
          # Public workspace
          create(:privacy, privatable: studio, user: artist, level: 'public')
          
          # Private project within it
          create(:privacy, privatable: album, user: artist, level: 'private')
          
          # Public content within private project
          create(:privacy, privatable: vocal_file, user: artist, level: 'public')
          
          studio.reload
          album.reload
          vocal_file.reload
          
          # Fan can access public workspace
          expect(studio.accessible_by?(fan)).to be true
          
          # Fan cannot access private project
          expect(album.accessible_by?(fan)).to be false
          
          # Fan CAN access public content directly (this is key!)
          expect(vocal_file.accessible_by?(fan)).to be true
        end

        it 'handles private content in public project in private workspace with collaborator' do
          # Producer joins workspace
          create(:role, user: producer, roleable: studio, name: 'collaborator')
          
          # Project is public
          create(:privacy, privatable: album, user: artist, level: 'public')
          
          # Content is private
          create(:privacy, privatable: vocal_file, user: artist, level: 'private')
          
          studio.reload
          album.reload
          vocal_file.reload
          
          # Producer can access project (workspace member + public project)
          expect(album.accessible_by?(producer)).to be true
          
          # Producer cannot access private content (only privacy setter can)
          expect(vocal_file.accessible_by?(producer)).to be false
          
          # Only artist (privacy setter) can access
          expect(vocal_file.accessible_by?(artist)).to be true
        end
      end

      context 'role changes and privacy interactions' do
        it 'handles role removal while privacy is set' do
          # Producer joins and creates private content
          create(:role, user: producer, roleable: studio, name: 'collaborator')
          studio.reload
          
          producer_content = create(:track_content, track_version: track, user: producer)
          create(:privacy, privatable: producer_content, user: producer, level: 'private')
          producer_content.reload
          
          # Producer can access their private content
          expect(producer_content.accessible_by?(producer)).to be true
          
          # Remove producer from workspace
          producer.roles.where(roleable: studio).destroy_all
          
          # Producer should still access their private content (privacy trumps roles)
          expect(producer_content.accessible_by?(producer)).to be true
          
          # Artist (workspace owner) should NOT access producer's private content
          expect(producer_content.accessible_by?(artist)).to be false
        end

        it 'handles workspace owner losing access to private content' do
          create(:privacy, privatable: vocal_file, user: producer, level: 'private')  # Producer sets privacy
          vocal_file.reload
          
          # Even workspace owner cannot access content set private by someone else
          expect(vocal_file.accessible_by?(artist)).to be false
          
          # Only producer (privacy setter) can access
          expect(vocal_file.accessible_by?(producer)).to be true
        end
      end

      context 'privacy deletion and orphaned access' do
        it 'handles privacy record deletion' do
          create(:privacy, privatable: vocal_file, user: artist, level: 'private')
          vocal_file.reload
          
          # Initially private
          expect(vocal_file.accessible_by?(fan)).to be false
          
          # Delete privacy record
          vocal_file.privacy.destroy
          vocal_file.reload
          
          # Should fall back to inherited access (workspace owner)
          expect(vocal_file.accessible_by?(artist)).to be true
          
          # Fan still shouldn't have access (no workspace membership)
          expect(vocal_file.accessible_by?(fan)).to be false
        end

        it 'handles user who set privacy being deleted' do
          create(:privacy, privatable: vocal_file, user: artist, level: 'private')
          privacy_id = vocal_file.privacy.id
          
          # Delete the user who set privacy
          artist.destroy
          
          # Privacy record should be deleted too (due to foreign key)
          expect(Privacy.exists?(privacy_id)).to be false
        end
      end

      context 'bulk operations and consistency' do
        it 'maintains consistency when changing multiple privacy levels' do
          # Set up hierarchy with all public
          create(:privacy, privatable: studio, user: artist, level: 'public')
          create(:privacy, privatable: album, user: artist, level: 'public')
          create(:privacy, privatable: track, user: artist, level: 'public')
          create(:privacy, privatable: vocal_file, user: artist, level: 'public')
          
          [studio, album, track, vocal_file].each(&:reload)
          
          # Fan can access everything
          expect(studio.accessible_by?(fan)).to be true
          expect(album.accessible_by?(fan)).to be true
          expect(track.accessible_by?(fan)).to be true
          expect(vocal_file.accessible_by?(fan)).to be true
          
          # Change project to private
          album.privacy.update!(level: 'private')
          album.reload
          track.reload
          vocal_file.reload
          
          # Fan loses access to project and everything below it
          expect(album.accessible_by?(fan)).to be false
          expect(track.accessible_by?(fan)).to be true
          expect(vocal_file.accessible_by?(fan)).to be true
          
          
          # But public content should still be directly accessible
          vocal_file.privacy.update!(level: 'public')
          vocal_file.reload
          expect(vocal_file.accessible_by?(fan)).to be true
        end
      end

      context 'edge cases with nil/missing data' do

        it 'handles privacy checks with nil user' do
          expect(vocal_file.accessible_by?(nil)).to be false
        end

        it 'handles privacy checks with deleted related records' do
          create(:privacy, privatable: vocal_file, user: artist, level: 'public')
          vocal_file.reload
          
          # Delete the project (cascade should clean up)
          album.destroy
          
          # Should handle gracefully
          expect { vocal_file.accessible_by?(fan) }.not_to raise_error
        end
      end
    end

    describe "database constraints and edge cases" do
      it "enforces unique privacy per resource" do
        user = create(:user)
        project = create(:project)
        
        # Create first privacy record
        Privacy.create!(user: user, privatable: project, level: 'private')
        
        # Try to create duplicate - should fail
        expect {
          Privacy.create!(user: user, privatable: project, level: 'public')
        }.to raise_error(ActiveRecord::RecordInvalid, /User has already been taken/)

      end

      it "handles orphaned privacy records gracefully" do
        user = create(:user)
        project = create(:project)
        privacy = create(:privacy, user: user, privatable: project, level: 'private')
        
        # Delete the project (should cascade delete privacy)
        project_id = project.id
        project.destroy
        
        expect(Privacy.exists?(privacy.id)).to be false
      end

      it "handles user deletion with privacy records" do
        user = create(:user)
        project = create(:project)
        privacy = create(:privacy, user: user, privatable: project, level: 'private')
        
        # Delete user (should cascade delete privacy)
        user.destroy
        
        expect(Privacy.exists?(privacy.id)).to be false
      end
    end
  end
end