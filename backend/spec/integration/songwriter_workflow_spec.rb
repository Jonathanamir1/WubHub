require 'rails_helper'

RSpec.describe 'Songwriter Workflow Integration', type: :integration do
  let(:user) { create(:user) }
  let(:songwriter_workspace) { create(:workspace, user: user, name: "My Song Studio") }

  describe 'Complete songwriter project creation workflow' do
    it 'handles full user journey from file upload to organized project' do
      # Step 1: User uploads mixed files to workspace
      container = create(:container, workspace: songwriter_workspace, name: "workspace_root")
      
      lyrics_file = create(:track_content, 
        title: "Amazing_Grace_lyrics.txt", 
        user: user, 
        container: container
      )
      
      demo_file = create(:track_content, 
        title: "Amazing_Grace_demo.wav", 
        user: user, 
        container: container
      )
      
      voice_memo = create(:track_content, 
        title: "Amazing_Grace_idea.m4a", 
        user: user, 
        container: container
      )
      
      other_file = create(:track_content, 
        title: "random_song.txt", 
        user: user, 
        container: container
      )
      
      # Step 2: System identifies related files by name pattern
      grouping_service = FileGroupingService.new(songwriter_workspace)
      
      # Should find files starting with "Amazing_Grace"
      related_files = grouping_service.find_files_starting_with("Amazing Grace", [lyrics_file, demo_file, voice_memo, other_file])
      
      expect(related_files).to include(lyrics_file, demo_file, voice_memo)
      expect(related_files).not_to include(other_file)
      
      # Step 3: System suggests project name from common pattern
      suggested_name = grouping_service.suggest_project_name_from_files(related_files)
      expect(suggested_name).to eq("Amazing Grace")
      
      # Step 4: Create project and organize files
      project_container = grouping_service.create_project_from_files(related_files, suggested_name)
      
      # Verify project was created
      expect(project_container.name).to eq("Amazing Grace")
      expect(project_container.workspace).to eq(songwriter_workspace)
      
      # Step 5: Verify files are organized by extension within project
      text_container = project_container.children.find_by(name: "Text Files")
      audio_container = project_container.children.find_by(name: "Audio Files")
      
      expect(text_container).to be_present
      expect(audio_container).to be_present
      
      # Check files are in correct containers
      expect(text_container.track_contents).to include(lyrics_file)
      expect(audio_container.track_contents).to include(demo_file, voice_memo)
      
      # Step 6: Verify files are moved from workspace to project
      lyrics_file.reload
      demo_file.reload
      voice_memo.reload
      
      expect(lyrics_file.container).to eq(text_container)
      expect(demo_file.container).to eq(audio_container)
      expect(voice_memo.container).to eq(audio_container)
      
      # Step 7: Verify other file remains in workspace (not grouped)
      other_file.reload
      expect(other_file.container).to eq(container)  # Still in workspace root
      
      # Step 8: Verify project structure is clean and organized
      expect(project_container.children.count).to eq(2)  # Text Files + Audio Files
      expect(project_container.track_contents.count).to eq(0)  # No loose files in project root
    end
  end
  
  describe 'Edge cases and variations' do
    it 'handles single file project creation' do
      container = create(:container, workspace: songwriter_workspace, name: "workspace_root")
      
      single_file = create(:track_content, 
        title: "Solo_Song_lyrics.txt", 
        user: user, 
        container: container
      )
      
      grouping_service = FileGroupingService.new(songwriter_workspace)
      project_container = grouping_service.create_project_from_files([single_file], "Solo Song")
      
      expect(project_container.name).to eq("Solo Song")
      
      text_container = project_container.children.find_by(name: "Text Files")
      expect(text_container.track_contents).to include(single_file)
    end
    
    it 'groups user-selected mixed files into custom-named project' do
      container = create(:container, workspace: songwriter_workspace, name: "workspace_root")
      
      # User selects these specific files (intentional selection)
      selected_files = [
        create(:track_content, title: "lyrics1.txt", user: user, container: container),
        create(:track_content, title: "demo2.wav", user: user, container: container),
        create(:track_content, title: "cover.jpg", user: user, container: container)
      ]
      
      # Files that user did NOT select - should remain in workspace
      unselected_file = create(:track_content, title: "other_song.txt", user: user, container: container)
      
      grouping_service = FileGroupingService.new(songwriter_workspace)
      
      # User provides custom project name for their selection
      project_container = grouping_service.create_project_from_files(selected_files, "My Mixed Project")
      
      # Should create containers for the file types that were selected
      expect(project_container.children.map(&:name)).to include("Text Files", "Audio Files", "Images")
      
      # Only selected files should be moved to project
      selected_files.each(&:reload)
      expect(selected_files.all? { |file| file.container.workspace == songwriter_workspace }).to be true
      expect(selected_files.none? { |file| file.container == container }).to be true
      
      # Unselected files should remain in workspace
      unselected_file.reload
      expect(unselected_file.container).to eq(container)
    end
    
    it 'handles files with no metadata gracefully' do
      container = create(:container, workspace: songwriter_workspace, name: "workspace_root")
      
      simple_audio = create(:track_content, 
        title: "mystery.wav", 
        user: user, 
        container: container
      )
      
      grouping_service = FileGroupingService.new(songwriter_workspace)
      project_container = grouping_service.create_project_from_files([simple_audio], "Mystery Song")
      
      # Should organize by extension regardless of metadata
      audio_container = project_container.children.find_by(name: "Audio Files")
      expect(audio_container.track_contents).to include(simple_audio)
      
      simple_audio.reload
      expect(simple_audio.container).to eq(audio_container)
    end
  end
end