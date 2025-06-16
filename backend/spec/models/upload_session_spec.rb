# spec/models/upload_session_spec.rb
require 'rails_helper'

RSpec.describe UploadSession, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should belong_to(:container).optional }
    it { should belong_to(:user) }
    it { should have_many(:chunks).dependent(:destroy) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:total_size) }
    it { should validate_presence_of(:chunks_count) }
    it { should validate_presence_of(:status) }
    
    it 'validates status inclusion' do
      should validate_inclusion_of(:status).in_array(['pending', 'uploading', 'assembling', 'completed', 'failed', 'cancelled'])
    end
    
    it 'validates total_size is positive' do
      upload_session = build(:upload_session, total_size: -1)
      expect(upload_session).not_to be_valid
      expect(upload_session.errors[:total_size]).to include('must be greater than 0')
    end
    
    it 'validates chunks_count is positive' do
      upload_session = build(:upload_session, chunks_count: 0)
      expect(upload_session).not_to be_valid
      expect(upload_session.errors[:chunks_count]).to include('must be greater than 0')
    end
    
    it 'validates filename format' do
      upload_session = build(:upload_session, filename: '')
      expect(upload_session).not_to be_valid
      expect(upload_session.errors[:filename]).to include("can't be blank")
    end
    
    it 'allows valid file extensions for music files' do
      valid_filenames = [
        'song.mp3', 'track.wav', 'project.logic', 'stems.aiff', 
        'master.flac', 'demo.m4a', 'backup.zip'
      ]
      
      valid_filenames.each do |filename|
        upload_session = build(:upload_session, filename: filename, workspace: workspace, user: user)
        expect(upload_session).to be_valid, "#{filename} should be valid"
      end
    end
    
    it 'validates unique filename within workspace root for active uploads' do
      existing_session = create(:upload_session, 
        filename: 'project.logic', 
        workspace: workspace, 
        container: nil,  # Root level
        user: user,
        status: 'uploading'
      )
      
      duplicate_session = build(:upload_session, 
        filename: 'project.logic', 
        workspace: workspace, 
        container: nil,  # Same location (root)
        user: user,
        status: 'pending'
      )
      
      expect(duplicate_session).not_to be_valid
      expect(duplicate_session.errors[:filename]).to include('is already being uploaded to this location')
    end
    
    it 'validates unique filename within same container for active uploads' do
      container = create(:container, workspace: workspace, name: 'Beats')
      
      existing_session = create(:upload_session, 
        filename: 'kick.wav', 
        workspace: workspace, 
        container: container,
        user: user,
        status: 'uploading'
      )
      
      duplicate_session = build(:upload_session, 
        filename: 'kick.wav', 
        workspace: workspace, 
        container: container,  # Same container
        user: user,
        status: 'pending'
      )
      
      expect(duplicate_session).not_to be_valid
      expect(duplicate_session.errors[:filename]).to include('is already being uploaded to this location')
    end
    
    it 'allows same filename in different containers' do
      container1 = create(:container, workspace: workspace, name: 'Beats')
      container2 = create(:container, workspace: workspace, name: 'Vocals')
      
      create(:upload_session, 
        filename: 'sample.wav', 
        workspace: workspace, 
        container: container1,
        user: user,
        status: 'uploading'
      )
      
      different_container_session = build(:upload_session, 
        filename: 'sample.wav', 
        workspace: workspace, 
        container: container2,  # Different container
        user: user,
        status: 'pending'
      )
      
      expect(different_container_session).to be_valid
    end
    
    it 'allows same filename in workspace root vs container' do
      container = create(:container, workspace: workspace, name: 'Projects')
      
      create(:upload_session, 
        filename: 'master.wav', 
        workspace: workspace, 
        container: nil,  # Root level
        user: user,
        status: 'uploading'
      )
      
      container_session = build(:upload_session, 
        filename: 'master.wav', 
        workspace: workspace, 
        container: container,  # Inside container
        user: user,
        status: 'pending'
      )
      
      expect(container_session).to be_valid
    end
    
    it 'allows same filename if previous upload completed or failed' do
      container = create(:container, workspace: workspace, name: 'Stems')
      
      create(:upload_session, 
        filename: 'project.logic', 
        workspace: workspace, 
        container: container,
        user: user,
        status: 'completed'
      )
      
      new_session = build(:upload_session, 
        filename: 'project.logic', 
        workspace: workspace, 
        container: container,  # Same container, but previous upload finished
        user: user,
        status: 'pending'
      )
      
      expect(new_session).to be_valid
    end
    
    it 'validates container belongs to the same workspace' do
      other_workspace = create(:workspace)
      wrong_container = create(:container, workspace: other_workspace, name: 'Wrong Container')
      
      session = build(:upload_session, 
        filename: 'song.wav',
        workspace: workspace,
        container: wrong_container,  # Container from different workspace
        user: user
      )
      
      expect(session).not_to be_valid
      expect(session.errors[:container]).to include('must belong to the same workspace')
    end
  end

  describe 'upload target location' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    
    it 'can upload to workspace root (no container)' do
      session = create(:upload_session, 
        workspace: workspace, 
        container: nil,
        user: user,
        filename: 'root_file.mp3'
      )
      
      expect(session.upload_location).to eq('/')
      expect(session.target_path).to eq('/root_file.mp3')
    end
    
    it 'can upload to specific container' do
      container = create(:container, workspace: workspace, name: 'Beats')
      
      session = create(:upload_session, 
        workspace: workspace, 
        container: container,
        user: user,
        filename: 'kick.wav'
      )
      
      expect(session.upload_location).to eq('/Beats')
      expect(session.target_path).to eq('/Beats/kick.wav')
    end
    
    it 'can upload to nested containers' do
      parent = create(:container, workspace: workspace, name: 'Projects')
      child = create(:container, workspace: workspace, name: 'Song1', parent_container: parent)
      grandchild = create(:container, workspace: workspace, name: 'Stems', parent_container: child)
      
      session = create(:upload_session, 
        workspace: workspace, 
        container: grandchild,
        user: user,
        filename: 'vocal_stem.wav'
      )
      
      expect(session.upload_location).to eq('/Projects/Song1/Stems')
      expect(session.target_path).to eq('/Projects/Song1/Stems/vocal_stem.wav')
    end
    
    it 'updates target path when container is renamed' do
      container = create(:container, workspace: workspace, name: 'Old Name')
      
      session = create(:upload_session, 
        workspace: workspace, 
        container: container,
        user: user,
        filename: 'test.wav'
      )
      
      expect(session.target_path).to eq('/Old Name/test.wav')
      
      container.update!(name: 'New Name')
      session.reload
      
      expect(session.target_path).to eq('/New Name/test.wav')
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    
    before do
      create(:upload_session, status: 'pending', workspace: workspace, user: user)
      create(:upload_session, status: 'uploading', workspace: workspace, user: user)
      create(:upload_session, status: 'completed', workspace: workspace, user: user)
      create(:upload_session, status: 'failed', workspace: workspace, user: user)
    end
    
    it 'has active scope for non-terminal states' do
      active_sessions = UploadSession.active
      expect(active_sessions.pluck(:status)).to contain_exactly('pending', 'uploading')
    end
    
    it 'has completed scope' do
      completed_sessions = UploadSession.completed
      expect(completed_sessions.pluck(:status)).to all(eq('completed'))
    end
    
    it 'has failed scope' do
      failed_sessions = UploadSession.failed
      expect(failed_sessions.pluck(:status)).to all(eq('failed'))
    end
    
    it 'has for_location scope that filters by workspace and container' do
      container1 = create(:container, workspace: workspace, name: 'Beats')
      container2 = create(:container, workspace: workspace, name: 'Vocals')
      
      root_session = create(:upload_session, workspace: workspace, container: nil, user: user)
      beats_session = create(:upload_session, workspace: workspace, container: container1, user: user)
      vocals_session = create(:upload_session, workspace: workspace, container: container2, user: user)
      
      # Root level sessions
      root_sessions = UploadSession.for_location(workspace, nil)
      expect(root_sessions).to include(root_session)
      expect(root_sessions).not_to include(beats_session, vocals_session)
      
      # Container specific sessions
      beats_sessions = UploadSession.for_location(workspace, container1)
      expect(beats_sessions).to include(beats_session)
      expect(beats_sessions).not_to include(root_session, vocals_session)
    end
  end

  describe 'status transitions' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, status: 'pending', workspace: workspace, user: user) }
    
    it 'can transition from pending to uploading' do
      expect { upload_session.start_upload! }.to change { upload_session.status }.from('pending').to('uploading')
    end
    
    it 'can transition from uploading to assembling' do
      upload_session.update!(status: 'uploading')
      expect { upload_session.start_assembly! }.to change { upload_session.status }.from('uploading').to('assembling')
    end
    
    it 'can transition from assembling to completed' do
      upload_session.update!(status: 'assembling')
      expect { upload_session.complete! }.to change { upload_session.status }.from('assembling').to('completed')
    end
    
    it 'can transition to failed from any state' do
      %w[pending uploading assembling].each do |initial_status|
        session = create(:upload_session, status: initial_status, workspace: workspace, user: user)
        expect { session.fail! }.to change { session.status }.to('failed')
      end
    end
    
    it 'can transition to cancelled from non-terminal states' do
      %w[pending uploading].each do |initial_status|
        session = create(:upload_session, status: initial_status, workspace: workspace, user: user)
        expect { session.cancel! }.to change { session.status }.to('cancelled')
      end
    end
    
    it 'cannot transition from completed state' do
      upload_session.update!(status: 'completed')
      expect { upload_session.start_upload! }.to raise_error(UploadSession::InvalidTransition)
    end
    
    it 'cannot transition from failed to uploading' do
      upload_session.update!(status: 'failed')
      expect { upload_session.start_upload! }.to raise_error(UploadSession::InvalidTransition)
    end
  end

  describe 'chunk management' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, chunks_count: 3, workspace: workspace, user: user) }
    
    it 'calculates progress based on completed chunks' do
      create(:chunk, upload_session: upload_session, status: 'completed')
      create(:chunk, upload_session: upload_session, status: 'completed')
      create(:chunk, upload_session: upload_session, status: 'pending')
      
      expect(upload_session.progress_percentage).to eq(66.67)
    end
    
    it 'returns 0 progress when no chunks completed' do
      create_list(:chunk, 3, upload_session: upload_session, status: 'pending')
      expect(upload_session.progress_percentage).to eq(0.0)
    end
    
    it 'returns 100 progress when all chunks completed' do
      create_list(:chunk, 3, upload_session: upload_session, status: 'completed')
      expect(upload_session.progress_percentage).to eq(100.0)
    end
    
    it 'identifies if all chunks are uploaded' do
      create_list(:chunk, 3, upload_session: upload_session, status: 'completed')
      expect(upload_session.all_chunks_uploaded?).to be true
    end
    
    it 'identifies missing chunks' do
      create(:chunk, upload_session: upload_session, chunk_number: 1, status: 'completed')
      create(:chunk, upload_session: upload_session, chunk_number: 3, status: 'completed')
      # Missing chunk 2
      
      missing = upload_session.missing_chunks
      expect(missing).to eq([2])
    end
    
    it 'calculates total uploaded size' do
      create(:chunk, upload_session: upload_session, size: 1024, status: 'completed')
      create(:chunk, upload_session: upload_session, size: 2048, status: 'completed')
      create(:chunk, upload_session: upload_session, size: 512, status: 'pending')
      
      expect(upload_session.uploaded_size).to eq(3072)
    end
  end

  describe 'file size validations and limits' do
    it 'allows files up to 5GB' do
      large_session = build(:upload_session, total_size: 5.gigabytes)
      expect(large_session).to be_valid
    end
    
    it 'rejects files larger than 5GB' do
      huge_session = build(:upload_session, total_size: 6.gigabytes)
      expect(huge_session).not_to be_valid
      expect(huge_session.errors[:total_size]).to include('cannot exceed 5GB')
    end
    
    it 'rejects files smaller than 1 byte' do
      tiny_session = build(:upload_session, total_size: 0)
      expect(tiny_session).not_to be_valid
      expect(tiny_session.errors[:total_size]).to include('must be greater than 0')
    end
    
    it 'calculates appropriate chunk size based on file size' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      
      # Small file: 1MB chunks
      small_session = create(:upload_session, total_size: 10.megabytes, workspace: workspace, user: user)
      expect(small_session.recommended_chunk_size).to eq(1.megabyte)
      
      # Medium file: 5MB chunks
      medium_session = create(:upload_session, total_size: 100.megabytes, workspace: workspace, user: user)
      expect(medium_session.recommended_chunk_size).to eq(5.megabytes)
      
      # Large file: 10MB chunks
      large_session = create(:upload_session, total_size: 1.gigabyte, workspace: workspace, user: user)
      expect(large_session.recommended_chunk_size).to eq(10.megabytes)
    end
  end

  describe 'workspace access control' do
    let(:owner) { create(:user) }
    let(:collaborator) { create(:user) }
    let(:viewer) { create(:user) }
    let(:outsider) { create(:user) }
    let(:workspace) { create(:workspace, user: owner) }
    
    before do
      create(:role, user: collaborator, roleable: workspace, name: 'collaborator')
      create(:role, user: viewer, roleable: workspace, name: 'viewer')
    end
    
    it 'allows workspace owner to create upload sessions' do
      session = build(:upload_session, workspace: workspace, user: owner)
      expect(session).to be_valid
    end
    
    it 'allows collaborators to create upload sessions' do
      session = build(:upload_session, workspace: workspace, user: collaborator)
      expect(session).to be_valid
    end
    
    it 'prevents viewers from creating upload sessions' do
      session = build(:upload_session, workspace: workspace, user: viewer)
      expect(session).not_to be_valid
      expect(session.errors[:user]).to include('must have upload permissions for this workspace')
    end
    
    it 'prevents outsiders from creating upload sessions' do
      session = build(:upload_session, workspace: workspace, user: outsider)
      expect(session).not_to be_valid
      expect(session.errors[:user]).to include('must have upload permissions for this workspace')
    end
    
    it 'allows creating upload sessions with collaborator trait' do
      session = create(:upload_session, :as_collaborator)
      expect(session).to be_valid
      expect(session.user.roles.where(roleable: session.workspace, name: 'collaborator')).to exist
    end
  end

  describe 'cleanup and expiration' do
    it 'expires old failed sessions after 24 hours' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      
      old_failed = create(:upload_session, status: 'failed', created_at: 25.hours.ago, workspace: workspace, user: user)
      recent_failed = create(:upload_session, status: 'failed', created_at: 1.hour.ago, workspace: workspace, user: user)
      
      expired_sessions = UploadSession.expired
      expect(expired_sessions).to include(old_failed)
      expect(expired_sessions).not_to include(recent_failed)
    end
    
    it 'expires old pending sessions after 1 hour' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      
      old_pending = create(:upload_session, status: 'pending', created_at: 2.hours.ago, workspace: workspace, user: user)
      recent_pending = create(:upload_session, status: 'pending', created_at: 30.minutes.ago, workspace: workspace, user: user)
      
      expired_sessions = UploadSession.expired
      expect(expired_sessions).to include(old_pending)
      expect(expired_sessions).not_to include(recent_pending)
    end
    
    it 'does not expire completed sessions' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      
      old_completed = create(:upload_session, status: 'completed', created_at: 1.week.ago, workspace: workspace, user: user)
      
      expired_sessions = UploadSession.expired
      expect(expired_sessions).not_to include(old_completed)
    end
    
    it 'cleans up associated chunks when session is destroyed' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      upload_session = create(:upload_session, workspace: workspace, user: user)
      chunks = create_list(:chunk, 3, upload_session: upload_session)
      
      expect { upload_session.destroy }.to change(Chunk, :count).by(-3)
    end
  end

  describe 'metadata handling' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace, user: user) }
    let(:upload_session) { create(:upload_session, workspace: workspace, user: user) }
    
    it 'stores custom metadata as JSON' do
      metadata = {
        original_path: '/Users/artist/Music/Project.logic',
        client_info: { browser: 'Chrome', version: '91.0' },
        upload_source: 'web_interface'
      }
      
      upload_session.update!(metadata: metadata)
      upload_session.reload
      
      expect(upload_session.metadata['original_path']).to eq('/Users/artist/Music/Project.logic')
      expect(upload_session.metadata['client_info']['browser']).to eq('Chrome')
    end
    
    it 'handles empty metadata gracefully' do
      upload_session.update!(metadata: {})
      expect(upload_session.metadata).to eq({})
    end
    
    it 'provides helper methods for common metadata' do
      upload_session.update!(metadata: { 
        file_type: 'logic_project',
        estimated_duration: 180.5 
      })
      
      expect(upload_session.file_type).to eq('logic_project')
      expect(upload_session.estimated_duration).to eq(180.5)
    end
  end

  describe 'edge cases and error handling' do
    it 'validates filename length limits' do
      long_filename = 'a' * 300 + '.mp3'
      session = build(:upload_session, filename: long_filename)
      
      expect(session).not_to be_valid
      expect(session.errors[:filename]).to include('is too long (maximum is 255 characters)')
    end
    
    it 'handles special characters in filenames' do
      special_filenames = [
        'Song (Demo Version).mp3',
        'Track #1 - Final.wav',
        'Project_v2.1.logic',
        'Band-Name_Song-Title.aiff'
      ]
      
      special_filenames.each do |filename|
        session = build(:upload_session, filename: filename)
        expect(session).to be_valid, "#{filename} should be valid"
      end
    end
    
    it 'rejects dangerous filenames' do
      dangerous_filenames = [
        '../../../etc/passwd',
        'CON.mp3',  # Windows reserved name
        '...hidden',  # Multiple dots
        ''
      ]
      
      dangerous_filenames.each do |filename|
        session = build(:upload_session, filename: filename)
        expect(session).not_to be_valid, "#{filename} should be invalid"
      end
    end
    
    it 'allows music files with exe in name' do
      # This should be valid - it's an audio file
      session = build(:upload_session, filename: 'file.exe.mp3')
      expect(session).to be_valid
    end
  end

  describe 'performance considerations' do
    it 'efficiently queries chunks with includes' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      session = create(:upload_session, chunks_count: 10, workspace: workspace, user: user)
      create_list(:chunk, 10, upload_session: session)
      
      # This should load chunks efficiently
      chunks_with_sessions = session.chunks.includes(:upload_session)
      expect(chunks_with_sessions.length).to eq(10)
      
      # Should be able to access upload_session without additional queries
      first_chunk = chunks_with_sessions.first
      expect(first_chunk.upload_session.filename).to be_present
    end
    
    it 'handles large numbers of chunks efficiently' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      session = create(:upload_session, chunks_count: 1000, workspace: workspace, user: user)
      
      # Creating chunks should be reasonably fast
      start_time = Time.current
      create_list(:chunk, 100, upload_session: session)
      end_time = Time.current
      
      expect(end_time - start_time).to be < 5.seconds
    end
  end

  describe 'integration with existing models' do
    it 'respects workspace privacy settings' do
      private_workspace = create(:workspace)
      user = create(:user)
      
      session = build(:upload_session, workspace: private_workspace, user: private_workspace.user)
      # Should be valid - privacy is handled at access level, not creation
      expect(session).to be_valid
    end
    
    it 'integrates with user authentication' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      session = create(:upload_session, user: user, workspace: workspace)
      
      expect(session.user).to eq(user)
      expect(user.upload_sessions).to include(session)
    end

    it 'maintains referential integrity with workspace deletion' do
      user = create(:user)
      workspace = create(:workspace, user: user)
      session = create(:upload_session, workspace: workspace, user: user)
      
      expect { workspace.destroy }.to change(UploadSession, :count).by(-1)
    end
  end
end