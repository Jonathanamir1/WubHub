require 'rails_helper'

RSpec.describe TrackVersion, type: :model do
  describe 'validations' do
    it 'requires title to be present' do
      track_version = TrackVersion.new(title: nil)
      expect(track_version).not_to be_valid
      expect(track_version.errors[:title]).to include("can't be blank")
    end

    it 'is valid with all required attributes' do
      track_version = build(:track_version)
      expect(track_version).to be_valid
    end

    it 'accepts empty description' do
      track_version = build(:track_version, description: '')
      expect(track_version).to be_valid
    end

    it 'accepts nil description' do
      track_version = build(:track_version, description: nil)
      expect(track_version).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:project) }
    it { should belong_to(:user) }
    it { should have_many(:track_contents).dependent(:destroy) }

    it 'destroys associated track contents when track version is destroyed' do
      track_version = create(:track_version)
      track_content = create(:track_content, track_version: track_version)
      
      expect { track_version.destroy }.to change(TrackContent, :count).by(-1)
    end
  end

  describe 'track version ownership and project relationship' do
    it 'belongs to the user who created it' do
      user = create(:user)
      track_version = create(:track_version, user: user)

      expect(track_version.user).to eq(user)
      expect(user.track_versions).to include(track_version)
    end

    it 'belongs to a project' do
      project = create(:project)
      track_version = create(:track_version, project: project)

      expect(track_version.project).to eq(project)
      expect(project.track_versions).to include(track_version)
    end

    it 'can be created by different users within the same project' do
      project = create(:project)
      user1 = create(:user)
      user2 = create(:user)
      
      version1 = create(:track_version, project: project, user: user1)
      version2 = create(:track_version, project: project, user: user2)

      expect(version1.user).to eq(user1)
      expect(version2.user).to eq(user2)
      expect(project.track_versions).to include(version1, version2)
    end
  end

  describe 'metadata handling' do
    it 'can store JSON metadata' do
      metadata = {
        'tempo' => 120,
        'key' => 'C major',
        'time_signature' => '4/4',
        'genre' => 'Electronic'
      }
      track_version = create(:track_version, metadata: metadata)

      expect(track_version.metadata).to eq(metadata)
      expect(track_version.metadata['tempo']).to eq(120)
      expect(track_version.metadata['key']).to eq('C major')
    end

    it 'handles nil metadata gracefully' do
      track_version = create(:track_version, metadata: nil)
      expect(track_version.metadata).to be_nil
    end

    it 'handles empty metadata gracefully' do
      track_version = create(:track_version, metadata: {})
      expect(track_version.metadata).to eq({})
    end

    it 'can update metadata' do
      track_version = create(:track_version, metadata: { tempo: 120 })
      
      track_version.update!(metadata: { tempo: 140, key: 'D minor' })
      
      expect(track_version.metadata['tempo']).to eq(140)
      expect(track_version.metadata['key']).to eq('D minor')
    end

    it 'can store complex nested metadata' do
      complex_metadata = {
        audio: {
          format: 'WAV',
          sample_rate: 44100,
          bit_depth: 24,
          duration: 180.5
        },
        mixing: {
          eq_settings: { low: -2, mid: 1, high: 0 },
          compression: { ratio: 4.0, threshold: -18 }
        },
        tags: ['demo', 'needs_vocals', 'v1']
      }
      
      track_version = create(:track_version, metadata: complex_metadata)
      expect(track_version.metadata['audio']['sample_rate']).to eq(44100)
      expect(track_version.metadata['mixing']['eq_settings']['low']).to eq(-2)
      expect(track_version.metadata['tags']).to include('demo')
    end
  end

  describe 'waveform data handling' do
    it 'can store waveform data' do
      waveform_data = '[0.1, 0.2, 0.3, 0.2, 0.1]'
      track_version = create(:track_version, waveform_data: waveform_data)
      
      expect(track_version.waveform_data).to eq(waveform_data)
    end

    it 'handles empty waveform data' do
      track_version = create(:track_version, waveform_data: '')
      expect(track_version.waveform_data).to eq('')
    end

    it 'handles nil waveform data' do
      track_version = create(:track_version, waveform_data: nil)
      expect(track_version.waveform_data).to be_nil
    end

    it 'can store large waveform datasets' do
      large_waveform = Array.new(10000) { rand(-1.0..1.0) }.to_json
      track_version = create(:track_version, waveform_data: large_waveform)
      
      expect(track_version.waveform_data).to eq(large_waveform)
    end
  end

  describe 'track contents relationship' do
    it 'can have multiple track contents' do
      track_version = create(:track_version)
      audio_content = create(:track_content, track_version: track_version, content_type: 'audio')
      lyrics_content = create(:track_content, track_version: track_version, content_type: 'lyrics')

      expect(track_version.track_contents).to include(audio_content, lyrics_content)
      expect(track_version.track_contents.count).to eq(2)
    end

    it 'can have contents of different types' do
      track_version = create(:track_version)
      create(:track_content, track_version: track_version, content_type: 'audio')
      create(:track_content, track_version: track_version, content_type: 'lyrics')
      create(:track_content, track_version: track_version, content_type: 'project_file')

      content_types = track_version.track_contents.pluck(:content_type)
      expect(content_types).to contain_exactly('audio', 'lyrics', 'project_file')
    end

    it 'returns empty collection when no contents exist' do
      track_version = create(:track_version)
      expect(track_version.track_contents).to be_empty
    end
  end



  describe 'version history and ordering' do
    let(:project) { create(:project) }

    it 'can be ordered by creation date' do
      old_version = create(:track_version, project: project, created_at: 2.days.ago, title: 'V1')
      new_version = create(:track_version, project: project, created_at: 1.day.ago, title: 'V2')

      versions_by_date = project.track_versions.order(:created_at)
      expect(versions_by_date.first).to eq(old_version)
      expect(versions_by_date.last).to eq(new_version)
    end

    it 'can be ordered by title for versioning' do
      version_b = create(:track_version, project: project, title: 'Mix B')
      version_a = create(:track_version, project: project, title: 'Mix A')
      version_c = create(:track_version, project: project, title: 'Mix C')

      versions_by_title = project.track_versions.order(:title)
      expect(versions_by_title).to eq([version_a, version_b, version_c])
    end
  end

  describe 'data integrity' do
    it 'maintains referential integrity with project' do
      project = create(:project)
      track_version = create(:track_version, project: project)

      # When project is destroyed, track version should be destroyed too
      expect { project.destroy }.to change(TrackVersion, :count).by(-1)
    end

    it 'maintains referential integrity with user' do
      user = create(:user)
      track_version = create(:track_version, user: user)

      # When user is destroyed, their track versions should be destroyed too
      expect { user.destroy }.to change(TrackVersion, :count).by(-1)
    end
  end

  describe 'querying and filtering' do
    let(:project) { create(:project) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    let!(:user1_version1) { create(:track_version, project: project, user: user1, title: 'Demo 1') }
    let!(:user1_version2) { create(:track_version, project: project, user: user1, title: 'Demo 2') }
    let!(:user2_version) { create(:track_version, project: project, user: user2, title: 'Mix 1') }

    it 'can find versions by project' do
      project_versions = project.track_versions
      expect(project_versions).to include(user1_version1, user1_version2, user2_version)
    end

    it 'can find versions by user' do
      user1_versions = user1.track_versions
      expect(user1_versions).to include(user1_version1, user1_version2)
      expect(user1_versions).not_to include(user2_version)
    end

    it 'can find versions by both project and user' do
      user_project_versions = TrackVersion.where(project: project, user: user1)
      expect(user_project_versions).to include(user1_version1, user1_version2)
      expect(user_project_versions).not_to include(user2_version)
    end
  end

  describe 'timestamps' do
    it 'sets created_at when track version is created' do
      track_version = create(:track_version)
      expect(track_version.created_at).to be_present
      expect(track_version.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when track version is modified' do
      track_version = create(:track_version)
      original_updated_at = track_version.updated_at
      
      sleep 0.1 # Ensure time difference
      track_version.update!(title: 'Updated Version')
      
      expect(track_version.updated_at).to be > original_updated_at
    end
  end

  describe 'edge cases' do
    it 'handles very long titles' do
      long_title = 'A' * 1000
      track_version = build(:track_version, title: long_title)
      expect(track_version.title.length).to eq(1000)
    end

    it 'handles very long descriptions' do
      long_description = 'A' * 5000
      track_version = build(:track_version, description: long_description)
      expect(track_version.description.length).to eq(5000)
    end

    it 'handles unicode characters in titles' do
      unicode_title = '🎵 My Track 🎶 (Demo) 🎧'
      track_version = create(:track_version, title: unicode_title)
      expect(track_version.title).to eq(unicode_title)
    end
  end

  describe 'string representation' do
    it 'can be represented as a string' do
      track_version = create(:track_version, title: 'My Awesome Track V1')
      expect(track_version.title).to eq('My Awesome Track V1')
    end
  end
end