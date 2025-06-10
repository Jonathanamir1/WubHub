require 'rails_helper'

RSpec.describe FileGroupingService, type: :service do
  let(:workspace) { create(:workspace) }
  let(:service) { FileGroupingService.new(workspace) }

  describe '#find_files_starting_with' do
    it 'finds files that start with given project name (case insensitive)' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      files = [
        create(:track_content, title: "Amazing_Grace_lyrics.txt", user: user, container: container),
        create(:track_content, title: "AMAZING_GRACE_demo.wav", user: user, container: container),
        create(:track_content, title: "amazing-grace-idea.m4a", user: user, container: container),
        create(:track_content, title: "other_song.txt", user: user, container: container)
      ]
      
      result = service.find_files_starting_with("Amazing Grace", files)
      
      expect(result).to include(files[0], files[1], files[2])
      expect(result).not_to include(files[3])
    end
    
    it 'handles different separator patterns' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      files = [
        create(:track_content, title: "My_Song_lyrics.txt", user: user, container: container),
        create(:track_content, title: "My-Song-demo.wav", user: user, container: container),
        create(:track_content, title: "My Song idea.m4a", user: user, container: container)
      ]
      
      result = service.find_files_starting_with("My Song", files)
      
      expect(result.size).to eq(3)
      expect(result).to include(files[0], files[1], files[2])
    end
  end

  describe '#suggest_project_name_from_files' do
    it 'extracts common project name from multiple files' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      files = [
        create(:track_content, title: "Amazing_Grace_lyrics.txt", user: user, container: container),
        create(:track_content, title: "Amazing_Grace_demo.wav", user: user, container: container)
      ]
      
      result = service.suggest_project_name_from_files(files)
      
      expect(result).to eq("Amazing Grace")
    end
    
    it 'handles single file gracefully' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      file = create(:track_content, title: "Solo_Song_lyrics.txt", user: user, container: container)
      
      result = service.suggest_project_name_from_files([file])
      
      expect(result).to eq("Solo Song")
    end
  end

  describe '#create_project_from_files' do
    it 'creates project container and organizes files by extension' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      files = [
        create(:track_content, title: "My_Song_lyrics.txt", user: user, container: container),
        create(:track_content, title: "My_Song_demo.wav", user: user, container: container),
        create(:track_content, title: "My_Song_cover.jpg", user: user, container: container)
      ]
      
      project_container = service.create_project_from_files(files, "My Song")
      
      # Verify project container was created
      expect(project_container.name).to eq("My Song")
      expect(project_container.workspace).to eq(workspace)
      expect(project_container.container_type).to eq("project")
      
      # Verify sub-containers were created
      text_container = project_container.children.find_by(name: "Text Files")
      audio_container = project_container.children.find_by(name: "Audio Files")
      image_container = project_container.children.find_by(name: "Images")
      
      expect(text_container).to be_present
      expect(audio_container).to be_present
      expect(image_container).to be_present
      
      # Verify files were moved to correct containers
      files.each(&:reload)
      
      expect(files[0].container).to eq(text_container)   # lyrics.txt
      expect(files[1].container).to eq(audio_container)  # demo.wav
      expect(files[2].container).to eq(image_container)  # cover.jpg
    end
  end
end