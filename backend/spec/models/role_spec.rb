require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'associations' do
    it 'allows workspace role' do
      workspace = create(:workspace)
      role = Role.new(user: create(:user), roleable: workspace, name: 'owner')
      
      expect(role.roleable).to eq(workspace)
      expect(role.roleable_type).to eq('Workspace')
    end

    it 'allows project role' do
      project = create(:project)
      role = Role.new(user: create(:user), roleable: project, name: 'collaborator')
      
      expect(role.roleable).to eq(project)
      expect(role.roleable_type).to eq('Project')
    end

    it 'allows track version role' do
      track_version = create(:track_version)
      role = Role.new(user: create(:user), roleable: track_version, name: 'viewer')
      
      expect(role.roleable).to eq(track_version)
      expect(role.roleable_type).to eq('TrackVersion')
    end

    it 'allows track content role' do
      track_content = create(:track_content)
      role = Role.new(user: create(:user), roleable: track_content, name: 'collaborator')
      
      expect(role.roleable).to eq(track_content)
      expect(role.roleable_type).to eq('TrackContent')
    end

    it 'allows collaborator role' do
      role = Role.new(user: create(:user), roleable: create(:project), name: 'collaborator')
      expect(role).to be_valid
    end

  end



  describe 'validations' do
    it 'requires name to be present' do
      role = Role.new(user: create(:user), roleable: create(:project), name: nil)
      expect(role).not_to be_valid
      expect(role.errors[:name]).to include("can't be blank")
    end

    it 'only allows valid role names' do
      valid_role = Role.new(user: create(:user), roleable: create(:project), name: 'owner')
      invalid_role = Role.new(user: create(:user), roleable: create(:project), name: 'invalid_role')
      
      expect(valid_role).to be_valid
      expect(invalid_role).not_to be_valid
      expect(invalid_role.errors[:name]).to include('is not included in the list')
    end      
  end

  describe 'permission inheritance' do
    it 'user with workspace role has access to projects in that workspace' do
      workspace = create(:workspace)
      project = create(:project, workspace: workspace)
      user = create(:user)
      
      # User has role on workspace
      Role.create!(user: user, roleable: workspace, name: 'owner')
      
      # User should have access to projects in that workspace
      expect(user.has_access_to?(project)).to be true
    end
    
    it 'user with project role has access to track versions in that project' do
      project = create(:project)
      track_version = create(:track_version, project: project)
      user = create(:user)
      
      Role.create!(user: user, roleable: project, name: 'collaborator')
      
      expect(user.has_access_to?(track_version)).to be true
    end

    it 'user with track versions role has access to track contents in that track version' do
      track_version = create(:track_version)
      track_content = create(:track_content, track_version: track_version)
      user = create(:user)

      Role.create!(user: user, roleable: track_version, name: 'collaborator')

      expect(user.has_access_to?(track_content)).to be true 
    end
  end
end