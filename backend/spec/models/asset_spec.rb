# spec/models/asset_spec.rb
require 'rails_helper'

RSpec.describe Asset, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should belong_to(:container).optional }
    it { should belong_to(:user) }
    it { should have_one_attached(:file_blob) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace) }
    let(:container) { create(:container, workspace: workspace) }
    
    it { should validate_presence_of(:filename) }
    
    it 'validates unique filename within same container' do
      create(:asset, filename: 'song.mp3', container: container, workspace: workspace, user: user)
      
      duplicate = build(:asset, filename: 'song.mp3', container: container, workspace: workspace, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:filename]).to include('has already been taken')
    end
    
    it 'allows same filename in different containers' do
      container1 = create(:container, workspace: workspace)
      container2 = create(:container, workspace: workspace)
      
      file1 = create(:asset, filename: 'vocal.wav', container: container1, workspace: workspace, user: user)
      file2 = build(:asset, filename: 'vocal.wav', container: container2, workspace: workspace, user: user)
      
      expect(file2).to be_valid
    end
    
    it 'validates unique filename at workspace root level' do
      create(:asset, filename: 'readme.txt', container: nil, workspace: workspace, user: user)
      
      duplicate = build(:asset, filename: 'readme.txt', container: nil, workspace: workspace, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:filename]).to include('has already been taken')
    end
    
    it 'allows same filename in workspace root vs container' do
      # File in workspace root
      root_file = create(:asset, filename: 'song.mp3', container: nil, workspace: workspace, user: user)
      
      # File in container with same name - should be valid
      container_file = build(:asset, filename: 'song.mp3', container: container, workspace: workspace, user: user)
      expect(container_file).to be_valid
    end
  end

  describe 'workspace consistency' do
    let(:user) { create(:user) }
    
    it 'ensures file workspace matches container workspace' do
      workspace1 = create(:workspace)
      workspace2 = create(:workspace)
      container_ws1 = create(:container, workspace: workspace1)
      
      # Try to create file in workspace2 but container from workspace1
      file = build(:asset, workspace: workspace2, container: container_ws1, user: user)
      expect(file).not_to be_valid
      expect(file.errors[:container]).to include('must be in the same workspace')
    end
  end

  describe 'path generation' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace) }
    
    it 'generates correct path for root file' do
      file = create(:asset, filename: 'master.wav', container: nil, workspace: workspace, user: user)
      expect(file.full_path).to eq('/master.wav')
    end
    
    it 'generates correct path for file in container' do
      container = create(:container, name: 'Beats', workspace: workspace)
      file = create(:asset, filename: 'kick.wav', container: container, workspace: workspace, user: user)
      expect(file.full_path).to eq('/Beats/kick.wav')
    end
    
    it 'generates correct path for file in nested containers' do
      parent = create(:container, name: 'Projects', workspace: workspace)
      child = create(:container, name: 'Song1', parent_container: parent, workspace: workspace)
      file = create(:asset, filename: 'vocal.wav', container: child, workspace: workspace, user: user)
      
      expect(file.full_path).to eq('/Projects/Song1/vocal.wav')
    end
  end

  describe 'access control' do
    let(:owner) { create(:user) }
    let(:collaborator) { create(:user) }
    let(:viewer) { create(:user) }
    let(:outsider) { create(:user) }
    let(:workspace) { create(:workspace, user: owner) }
    let(:asset) { create(:asset, workspace: workspace, user: owner) }
    
    before do
      create(:role, user: collaborator, roleable: workspace, name: 'collaborator')
      create(:role, user: viewer, roleable: workspace, name: 'viewer')
    end
    
    it 'allows workspace owner to access file' do
      expect(asset.accessible_by?(owner)).to be true
    end
    
    it 'allows collaborators to access file' do
      expect(asset.accessible_by?(collaborator)).to be true
    end
    
    it 'allows viewers to access file' do
      expect(asset.accessible_by?(viewer)).to be true
    end
    
    it 'denies access to outsiders' do
      expect(asset.accessible_by?(outsider)).to be false
    end
  end

  describe 'file operations' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace) }
    let(:container) { create(:container, workspace: workspace) }
    
    it 'tracks uploader correctly' do
      asset = create(:asset, container: container, workspace: workspace, user: user)
      expect(asset.user).to eq(user)
      expect(asset.uploaded_by).to eq(user.email)
    end
    
    it 'sets file size when file is attached' do
      # Create asset without default content_type from factory
      asset = create(:asset, container: container, workspace: workspace, user: user, content_type: nil)
      
      # Simulate file attachment
      test_file = Tempfile.new(['test', '.txt'])
      test_file.write('Hello World')
      test_file.rewind
      
      asset.file_blob.attach(
        io: test_file,
        filename: 'test.txt',
        content_type: 'text/plain'
      )
      
      # Manually extract metadata (in real app, this would be called after upload)
      asset.extract_file_metadata!
      
      expect(asset.file_size).to be > 0
      expect(asset.content_type).to eq('text/plain')
      
      test_file.close
      test_file.unlink
    end
  end
end