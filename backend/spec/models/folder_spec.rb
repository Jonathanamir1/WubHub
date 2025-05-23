require 'rails_helper'

RSpec.describe Folder, type: :model do
  describe 'validations' do
    it 'requires name to be present' do
      folder = Folder.new(name: nil)
      expect(folder).not_to be_valid
      expect(folder.errors[:name]).to include("can't be blank")
    end

    it 'requires path to be unique within project' do
      project = create(:project)
      create(:folder, project: project, name: 'samples', path: '/samples')
      
      duplicate_folder = build(:folder, project: project, name: 'samples', path: '/samples')
      expect(duplicate_folder).not_to be_valid
      expect(duplicate_folder.errors[:path]).to include('has already been taken')
    end

    it 'allows same path in different projects' do
      project1 = create(:project)
      project2 = create(:project)
      
      folder1 = create(:folder, project: project1, name: 'samples', path: '/samples')
      folder2 = build(:folder, project: project2, name: 'samples', path: '/samples')
      
      expect(folder2).to be_valid
    end

    it 'is valid with all required attributes' do
      folder = build(:folder)
      expect(folder).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:project) }
    it { should belong_to(:user) }
    it { should belong_to(:parent_folder).optional }
    it { should have_many(:subfolders).dependent(:destroy) }
    it { should have_many(:audio_files).dependent(:destroy) }

    it 'belongs to a project' do
      project = create(:project)
      folder = create(:folder, project: project)

      expect(folder.project).to eq(project)
      expect(project.folders).to include(folder)
    end

    it 'belongs to a user' do
      user = create(:user)
      folder = create(:folder, user: user)

      expect(folder.user).to eq(user)
      expect(user.folders).to include(folder)
    end

    it 'can have a parent folder' do
      parent = create(:folder, name: 'drums')
      subfolder = create(:folder, name: 'kicks', parent_folder: parent, project: parent.project)

      expect(subfolder.parent_folder).to eq(parent)
      expect(parent.subfolders).to include(subfolder)
    end

    it 'can exist without a parent folder (root folder)' do
      folder = create(:folder, parent_folder: nil)
      expect(folder.parent_folder).to be_nil
    end

    it 'destroys subfolders when folder is destroyed' do
      parent = create(:folder)
      subfolder = create(:folder, parent_folder: parent, project: parent.project)
      
      expect { parent.destroy }.to change(Folder, :count).by(-2) # parent + subfolder
    end

    it 'destroys audio files when folder is destroyed' do
      folder = create(:folder)
      audio_file = create(:audio_file, folder: folder)
      
      expect { folder.destroy }.to change(AudioFile, :count).by(-1)
    end
  end

  describe 'hierarchical structure' do
    let(:project) { create(:project) }
    let(:root_folder) { create(:folder, project: project, name: 'audio') }
    let(:drums_folder) { create(:folder, project: project, name: 'drums', parent_folder: root_folder) }
    let(:kicks_folder) { create(:folder, project: project, name: 'kicks', parent_folder: drums_folder) }

    #DEBUG
    
    it 'maintains proper hierarchy levels' do
      root = root_folder 
      drums = drums_folder
      kicks = kicks_folder

      # Root level
      expect(root.parent_folder).to be_nil
      expect(root.subfolders.count).to eq(1)  # ← The failing line
      
      # Second level  
      expect(drums_folder.parent_folder).to eq(root_folder)
      expect(drums_folder.subfolders.count).to eq(1)
      
      # Third level
      expect(kicks_folder.parent_folder).to eq(drums_folder)
      expect(kicks_folder.subfolders.count).to eq(0)
    end

    it 'can have multiple subfolders at the same level' do
      snares_folder = create(:folder, project: project, name: 'snares', parent_folder: drums_folder)
      hihats_folder = create(:folder, project: project, name: 'hihats', parent_folder: drums_folder)

      expect(drums_folder.subfolders).to include(kicks_folder, snares_folder, hihats_folder)
      expect(drums_folder.subfolders.count).to eq(3)
    end
  end

  describe 'path generation' do
    let(:project) { create(:project) }

    it 'generates correct path for root folder' do
      folder = create(:folder, project: project, name: 'samples', parent_folder: nil)
      expect(folder.path).to eq('/samples')
    end

    it 'generates correct path for nested folders' do
      parent = create(:folder, project: project, name: 'drums', parent_folder: nil)
      child = create(:folder, project: project, name: 'kicks', parent_folder: parent)
      
      expect(parent.path).to eq('/drums')
      expect(child.path).to eq('/drums/kicks')
    end

    it 'generates correct path for deeply nested folders' do
      root = create(:folder, project: project, name: 'audio', parent_folder: nil)
      level2 = create(:folder, project: project, name: 'drums', parent_folder: root)
      level3 = create(:folder, project: project, name: 'acoustic', parent_folder: level2)
      level4 = create(:folder, project: project, name: 'kicks', parent_folder: level3)
      
      expect(root.path).to eq('/audio')
      expect(level2.path).to eq('/audio/drums')
      expect(level3.path).to eq('/audio/drums/acoustic')
      expect(level4.path).to eq('/audio/drums/acoustic/kicks')
    end

    it 'updates path when folder is moved' do
      old_parent = create(:folder, project: project, name: 'old_location')
      new_parent = create(:folder, project: project, name: 'new_location')
      child = create(:folder, project: project, name: 'moved_folder', parent_folder: old_parent)
      
      expect(child.path).to eq('/old_location/moved_folder')
      
      child.update!(parent_folder: new_parent)
      expect(child.path).to eq('/new_location/moved_folder')
    end
  end

  describe 'folder organization' do
    let(:project) { create(:project) }

    it 'can organize different types of content' do
      audio_folder = create(:folder, project: project, name: 'audio')
      samples_folder = create(:folder, project: project, name: 'samples', parent_folder: audio_folder)
      stems_folder = create(:folder, project: project, name: 'stems', parent_folder: audio_folder)
      bounces_folder = create(:folder, project: project, name: 'bounces', parent_folder: audio_folder)

      expect(audio_folder.subfolders.pluck(:name)).to contain_exactly('samples', 'stems', 'bounces')
    end

    it 'can find root folders for a project' do
      root1 = create(:folder, project: project, name: 'audio', parent_folder: nil)
      root2 = create(:folder, project: project, name: 'docs', parent_folder: nil)
      nested = create(:folder, project: project, name: 'nested', parent_folder: root1)

      root_folders = project.folders.where(parent_folder: nil)
      expect(root_folders).to include(root1, root2)
      expect(root_folders).not_to include(nested)
    end

    it 'can find all folders in a project' do
      root = create(:folder, project: project, name: 'root')
      child1 = create(:folder, project: project, name: 'child1', parent_folder: root)
      child2 = create(:folder, project: project, name: 'child2', parent_folder: root)
      grandchild = create(:folder, project: project, name: 'grandchild', parent_folder: child1)

      all_folders = project.folders
      expect(all_folders).to include(root, child1, child2, grandchild)
      expect(all_folders.count).to eq(4)
    end
  end

  describe 'metadata handling' do
    it 'can store JSON metadata' do
      metadata = {
        'color' => '#ff6b6b',
        'icon' => 'folder-music',
        'description' => 'Main drum samples folder',
        'tags' => ['acoustic', 'processed']
      }
      folder = create(:folder, metadata: metadata)

      expect(folder.metadata).to eq(metadata)
      expect(folder.metadata['color']).to eq('#ff6b6b')
      expect(folder.metadata['tags']).to include('acoustic')
    end

    it 'can store folder settings' do
      settings = {
        'sort_by' => 'name',
        'sort_order' => 'asc',
        'view_mode' => 'grid',
        'show_waveforms' => true
      }
      folder = create(:folder, metadata: settings)

      expect(folder.metadata['sort_by']).to eq('name')
      expect(folder.metadata['show_waveforms']).to be true
    end

    it 'handles nil metadata gracefully' do
      folder = create(:folder, metadata: nil)
      expect(folder.metadata).to be_nil
    end

    it 'handles empty metadata gracefully' do
      folder = create(:folder, metadata: {})
      expect(folder.metadata).to eq({})
    end
  end

  describe 'folder queries and filtering' do
    let(:project) { create(:project) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      create(:folder, project: project, user: user1, name: 'user1_folder')
      create(:folder, project: project, user: user2, name: 'user2_folder')
      create(:folder, project: project, user: user1, name: 'shared_name')
      create(:folder, project: project, user: user2, name: 'shared_name1')
    end

    it 'can find folders by user' do
      user1_folders = project.folders.where(user: user1)
      expect(user1_folders.count).to eq(2)
      expect(user1_folders.pluck(:name)).to include('user1_folder', 'shared_name')
    end

    it 'can find folders by name' do
      
      shared_folders = project.folders.where(name: 'shared_name')
      expect(shared_folders.count).to eq(1)  # There's 1 folder named 'shared_name'
      
      user1_folders = project.folders.where(name: 'user1_folder')
      expect(user1_folders.count).to eq(1)  # There's 1 folder named 'user1_folder'
    end

    it 'can search folders by name pattern' do
      matching_folders = project.folders.where('name ILIKE ?', '%user1%')
      expect(matching_folders.count).to eq(1)
      expect(matching_folders.first.name).to eq('user1_folder')
    end
  end

  describe 'data integrity' do
    it 'maintains referential integrity with project' do
      project = create(:project)
      folder = create(:folder, project: project)

      # When project is destroyed, folder should be destroyed too
      expect { project.destroy }.to change(Folder, :count).by(-1)
    end

    it 'maintains referential integrity with user' do
      user = create(:user)
      folder = create(:folder, user: user)

      # When user is destroyed, their folders should be destroyed too
      expect { user.destroy }.to change(Folder, :count).by(-1)
    end

    it 'maintains hierarchy when parent is destroyed' do
      parent = create(:folder)
      child = create(:folder, parent_folder: parent, project: parent.project)
      grandchild = create(:folder, parent_folder: child, project: parent.project)

      # All should be destroyed when parent is destroyed (cascade)
      expect { parent.destroy }.to change(Folder, :count).by(-3)
    end
  end

  describe 'timestamps' do
    it 'sets created_at when folder is created' do
      folder = create(:folder)
      expect(folder.created_at).to be_present
      expect(folder.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when folder is modified' do
      folder = create(:folder)
      original_updated_at = folder.updated_at
      
      sleep 0.1 # Ensure time difference
      folder.update!(name: 'Updated Folder Name')
      
      expect(folder.updated_at).to be > original_updated_at
    end
  end

  describe 'edge cases' do
    it 'handles very long folder names' do
      long_name = 'A' * 500
      folder = build(:folder, name: long_name)
      expect(folder.name.length).to eq(500)
    end

    it 'handles unicode in folder names' do
      unicode_name = '🎵 Music Folder 音楽 🎶'
      folder = create(:folder, name: unicode_name)
      expect(folder.name).to eq(unicode_name)
    end

    it 'handles special characters in folder names' do
      special_name = 'Folder-With_Special.Characters & More!'
      folder = create(:folder, name: special_name)
      expect(folder.name).to eq(special_name)
    end

    it 'handles very deep nesting' do
      project = create(:project)
      current_folder = nil
      
      # Create 10 levels deep
      10.times do |i|
        current_folder = create(:folder, 
                              project: project, 
                              name: "level_#{i}", 
                              parent_folder: current_folder)
      end
      
      expect(current_folder.path).to eq('/level_0/level_1/level_2/level_3/level_4/level_5/level_6/level_7/level_8/level_9')
    end
  end

  describe 'folder usage patterns' do
    let(:project) { create(:project) }

    it 'supports typical music project structure' do
      # Root folders
      audio = create(:folder, project: project, name: 'Audio')
      midi = create(:folder, project: project, name: 'MIDI')
      docs = create(:folder, project: project, name: 'Documents')
      
      # Audio subfolders
      drums = create(:folder, project: project, name: 'Drums', parent_folder: audio)
      bass = create(:folder, project: project, name: 'Bass', parent_folder: audio)
      vocals = create(:folder, project: project, name: 'Vocals', parent_folder: audio)
      
      # Drum subfolders
      kicks = create(:folder, project: project, name: 'Kicks', parent_folder: drums)
      snares = create(:folder, project: project, name: 'Snares', parent_folder: drums)
      
      expect(audio.subfolders.pluck(:name)).to contain_exactly('Drums', 'Bass', 'Vocals')
      expect(drums.subfolders.pluck(:name)).to contain_exactly('Kicks', 'Snares')
      expect(kicks.path).to eq('/Audio/Drums/Kicks')
    end
  end

  describe 'data persistence' do
    it 'persists correctly to database' do
      folder = create(:folder, 
                    name: 'Test Folder',
                    metadata: { 'color' => 'blue', 'tags' => ['test'] })
      
      # Reload from database
      reloaded_folder = Folder.find(folder.id)
      
      expect(reloaded_folder.name).to eq('Test Folder')
      expect(reloaded_folder.metadata['color']).to eq('blue')
      expect(reloaded_folder.metadata['tags']).to include('test')
      expect(reloaded_folder.project_id).to eq(folder.project_id)
      expect(reloaded_folder.user_id).to eq(folder.user_id)
    end
  end
end