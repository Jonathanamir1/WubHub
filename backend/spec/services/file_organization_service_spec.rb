require 'rails_helper'

RSpec.describe FileOrganizationService, type: :service do
  let(:workspace) { create(:workspace) }
  let(:service) { FileOrganizationService.new(workspace) }

  describe '#categorize_by_extension' do
    it 'groups basic audio and text files by extension' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      audio_file = create(:track_content, title: "song.wav", user: user, container: container)
      text_file = create(:track_content, title: "lyrics.txt", user: user, container: container)
      
      result = service.categorize_by_extension([audio_file, text_file])
      
      expect(result["Audio Files"]).to eq([audio_file])
      expect(result["Text Files"]).to eq([text_file])
    end
    
    it 'handles unknown file extensions' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      unknown_file = create(:track_content, title: "mystery.xyz", user: user, container: container)
      
      result = service.categorize_by_extension([unknown_file])
      
      expect(result["Other Files"]).to eq([unknown_file])
    end
    
    it 'handles project files and images' do
      user = create(:user)
      container = create(:container, workspace: workspace)
      
      project_file = create(:track_content, title: "song.logicx", user: user, container: container)
      image_file = create(:track_content, title: "cover.jpg", user: user, container: container)
      
      result = service.categorize_by_extension([project_file, image_file])
      
      expect(result["Project Files"]).to eq([project_file])
      expect(result["Images"]).to eq([image_file])
    end
  end
end