require 'rails_helper'

RSpec.describe "File Attachment Workflows", type: :model do
  describe "multi-level file organization" do
    it "allows files at every level of the hierarchy" do
      # Create the hierarchy
      user = create(:user, username: "producer_mike")
      studio = create(:workspace, user: user, name: "Mike's Studio")
      album = create(:project, workspace: studio, user: user, title: "Debut Album")
      demo = create(:track_version, project: album, user: user, title: "Song Demo V1")
      
      # Attach files at every level
      studio_logo = create(:file_attachment, :attached_to_workspace,
                          attachable: studio, user: user, filename: "studio_logo.png")
      
      album_artwork = create(:file_attachment, :attached_to_project,
                           attachable: album, user: user, filename: "album_cover.jpg")
      
      demo_audio = create(:file_attachment, :attached_to_track_version,
                         attachable: demo, user: user, filename: "demo_mix.wav")
      
      # Verify the organization
      expect(studio.file_attachments.count).to eq(1)
      expect(album.file_attachments.count).to eq(1)
      expect(demo.file_attachments.count).to eq(1)
      
      # Verify file details
      expect(studio_logo.filename).to eq("studio_logo.png")
      expect(album_artwork.filename).to eq("album_cover.jpg")
      expect(demo_audio.filename).to eq("demo_mix.wav")
      
      # Verify all files belong to the same user
      all_files = FileAttachment.where(user: user)
      expect(all_files.count).to eq(3)
      expect(all_files.map(&:filename)).to contain_exactly(
        "studio_logo.png", "album_cover.jpg", "demo_mix.wav"
      )
    end
  end
end