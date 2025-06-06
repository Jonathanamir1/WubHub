# spec/models/track_content_spec.rb
require 'rails_helper'

RSpec.describe TrackContent, type: :model do
  describe 'validations' do
    it 'requires container to be present' do
      track_content = TrackContent.new(container: nil)
      expect(track_content).not_to be_valid
      expect(track_content.errors[:container]).to include("must exist")
    end

    it 'requires user to be present' do
      track_content = TrackContent.new(user: nil)
      expect(track_content).not_to be_valid
      expect(track_content.errors[:user]).to include("must exist")
    end

    it 'does not require title to be present' do
      workspace = create(:workspace)
      container = Container.create!(
        workspace: workspace,
        name: "Test Container",
        container_type: "folder",
        template_level: 1
      )
      user = create(:user)
      
      track_content = TrackContent.new(
        container: container,
        user: user,
        title: nil
      )
      
      expect(track_content).to_not be_valid
    end

    it 'allows different content types' do
      workspace = create(:workspace)
      container = Container.create!(
        workspace: workspace,
        name: "Test Container",
        container_type: "folder",
        template_level: 1
      )
      user = create(:user)
      
      audio_content = TrackContent.create!(
        container: container,
        user: user,
        title: "My Beat",
        content_type: "audio"
      )
      
      text_content = TrackContent.create!(
        container: container,
        user: user,
        title: "Lyrics",
        content_type: "text"
      )
      
      expect(audio_content.content_type).to eq("audio")
      expect(text_content.content_type).to eq("text")
    end

    it 'can have file attachments' do
      workspace = create(:workspace)
      container = Container.create!(
        workspace: workspace,
        name: "Audio Container",
        container_type: "folder", 
        template_level: 1
      )
      user = create(:user)
      
      track_content = TrackContent.create!(
        container: container,
        user: user,
        title: "My Beat",
        content_type: "audio"
      )
      
      file_attachment = FileAttachment.create!(
        attachable: track_content,
        user: user,
        filename: "beat.wav",
        content_type: "audio/wav",
        file_size: 1024
      )
      
      expect(track_content.file_attachments).to include(file_attachment)
    end

    it 'stores and retrieves metadata as JSON' do
      workspace = create(:workspace)
      container = Container.create!(
        workspace: workspace,
        name: "Audio Container",
        container_type: "folder",
        template_level: 1
      )
      user = create(:user)
      
      metadata = {
        "duration" => 180,
        "bpm" => 120,
        "key" => "C major",
        "tags" => ["hip-hop", "instrumental"]
      }
      
      track_content = TrackContent.create!(
        container: container,
        user: user,
        title: "My Beat",
        content_type: "audio",
        metadata: metadata
      )
      
      track_content.reload
      expect(track_content.metadata).to eq(metadata)
      expect(track_content.metadata["duration"]).to eq(180)
      expect(track_content.metadata["bpm"]).to eq(120)
    end
  end
end