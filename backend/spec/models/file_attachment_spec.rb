require 'rails_helper'

RSpec.describe FileAttachment, type: :model do
  describe 'validations' do
    it 'requires filename to be present' do
      file_attachment = FileAttachment.new(filename: nil)
      expect(file_attachment).not_to be_valid
      expect(file_attachment.errors[:filename]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to an attachable resource polymorphically' do
      project = create(:project)
      file_attachment = FileAttachment.new(
        filename: 'test.wav',
        attachable: project
      )
      
      expect(file_attachment.attachable).to eq(project)
      expect(file_attachment.attachable_type).to eq('Project')
      expect(file_attachment.attachable_id).to eq(project.id)
    end
  end

  describe 'file handling' do
    it 'can have an attached file' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      
      file_attachment = create(:file_attachment, :attached_to_project, 
                              attachable: project, user: user)
      
      # Create a temporary file for testing
      file = Tempfile.new(['test_audio', '.wav'])
      file.write('fake audio data')
      file.rewind
      
      file_attachment.file.attach(
        io: file,
        filename: 'test_audio.wav',
        content_type: 'audio/wav'
      )
      
      expect(file_attachment.file).to be_attached
      expect(file_attachment.file.filename.to_s).to eq('test_audio.wav')
      
      file.close
      file.unlink
    end
  end

  describe 'polymorphic attachments' do
    it 'can attach to different resource types' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      track_version = create(:track_version, project: project, user: user)
      
      # Create attachments for different resources
      workspace_file = create(:file_attachment, :attached_to_workspace, 
                            attachable: workspace, user: user, filename: 'workspace_logo.png')
      project_file = create(:file_attachment, :attached_to_project,
                          attachable: project, user: user, filename: 'project_notes.txt')
      track_file = create(:file_attachment, :attached_to_track_version,
                        attachable: track_version, user: user, filename: 'mix_v1.wav')
      
      # Test polymorphic relationships work
      expect(workspace_file.attachable).to eq(workspace)
      expect(project_file.attachable).to eq(project)  
      expect(track_file.attachable).to eq(track_version)
      
      expect(workspace_file.attachable_type).to eq('Workspace')
      expect(project_file.attachable_type).to eq('Project')
      expect(track_file.attachable_type).to eq('TrackVersion')
    end

    it 'allows resources to access their file attachments' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      
      file1 = create(:file_attachment, :attached_to_project,
                    attachable: project, user: user, filename: 'demo.wav')
      file2 = create(:file_attachment, :attached_to_project,
                    attachable: project, user: user, filename: 'notes.txt')
      
      expect(project.file_attachments).to include(file1, file2)
      expect(project.file_attachments.count).to eq(2)
    end

    it 'works with all resource types' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      track_version = create(:track_version, project: project, user: user)
      
      # Create files for each resource type
      workspace_file = create(:file_attachment, :attached_to_workspace,
                            attachable: workspace, user: user)
      project_file = create(:file_attachment, :attached_to_project,
                          attachable: project, user: user)
      track_file = create(:file_attachment, :attached_to_track_version,
                        attachable: track_version, user: user)
      
      # Test reverse associations work for all types
      expect(workspace.file_attachments).to include(workspace_file)
      expect(project.file_attachments).to include(project_file)
      expect(track_version.file_attachments).to include(track_file)
      
      expect(workspace.file_attachments.count).to eq(1)
      expect(project.file_attachments.count).to eq(1)
      expect(track_version.file_attachments.count).to eq(1)
    end
  end

  
end