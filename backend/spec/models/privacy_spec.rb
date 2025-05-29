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
end