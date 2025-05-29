require 'rails_helper'

RSpec.describe TrackContent, type: :model do
  describe 'validations' do
    it 'requires content_type to be present' do
      track_content = TrackContent.new(content_type: nil)
      expect(track_content).not_to be_valid
      expect(track_content.errors[:content_type]).to include("can't be blank")
    end

    it 'is valid with required attributes' do
      track_content = build(:track_content)
      expect(track_content).to be_valid
    end

    it 'accepts empty title' do
      track_content = build(:track_content, title: '')
      expect(track_content).to be_valid
    end

    it 'accepts nil title' do
      track_content = build(:track_content, title: nil)
      expect(track_content).to be_valid
    end

    it 'accepts empty description' do
      track_content = build(:track_content, description: '')
      expect(track_content).to be_valid
    end

    it 'accepts nil description' do
      track_content = build(:track_content, description: nil)
      expect(track_content).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:track_version) }
    it { should have_one_attached(:file) }

    it 'belongs to a track version' do
      track_version = create(:track_version)
      track_content = create(:track_content, track_version: track_version)

      expect(track_content.track_version).to eq(track_version)
      expect(track_version.track_contents).to include(track_content)
    end
    it 'can have a privacy record' do
      track_content = create(:track_content)
      privacy = create(:privacy, privatable: track_content)
      
      expect(track_content.privacy).to eq(privacy)
      expect(privacy.privatable).to eq(track_content)
    end
  end

  describe 'content type handling' do
    it 'can store audio content type' do
      track_content = create(:track_content, content_type: 'audio')
      expect(track_content.content_type).to eq('audio')
    end

    it 'can store lyrics content type' do
      track_content = create(:track_content, content_type: 'lyrics')
      expect(track_content.content_type).to eq('lyrics')
    end

    it 'can store project file content type' do
      track_content = create(:track_content, content_type: 'project_file')
      expect(track_content.content_type).to eq('project_file')
    end

    it 'can store image content type' do
      track_content = create(:track_content, content_type: 'image')
      expect(track_content.content_type).to eq('image')
    end

    it 'can store document content type' do
      track_content = create(:track_content, content_type: 'document')
      expect(track_content.content_type).to eq('document')
    end

    it 'can store other content types' do
      track_content = create(:track_content, content_type: 'sheet_music')
      expect(track_content.content_type).to eq('sheet_music')
    end
  end

  describe 'text content handling' do
    it 'can store lyrics as text content' do
      lyrics = "Verse 1:\nThis is a sample song\nWith multiple lines"
      track_content = create(:track_content, 
                            content_type: 'lyrics', 
                            text_content: lyrics)
      
      expect(track_content.text_content).to eq(lyrics)
    end

    it 'can store notes as text content' do
      notes = "Producer notes: Increase reverb on vocals, adjust EQ on drums"
      track_content = create(:track_content, 
                            content_type: 'notes', 
                            text_content: notes)
      
      expect(track_content.text_content).to eq(notes)
    end

    it 'can store very long text content' do
      long_text = 'A' * 10000
      track_content = create(:track_content, text_content: long_text)
      expect(track_content.text_content.length).to eq(10000)
    end

    it 'handles empty text content' do
      track_content = create(:track_content, text_content: '')
      expect(track_content.text_content).to eq('')
    end

    it 'handles nil text content' do
      track_content = create(:track_content, text_content: nil)
      expect(track_content.text_content).to be_nil
    end

    it 'handles unicode text content' do
      unicode_text = '🎵 Music notes with émojis and spëcial characters 🎶'
      track_content = create(:track_content, text_content: unicode_text)
      expect(track_content.text_content).to eq(unicode_text)
    end
  end

  describe 'metadata handling' do
    it 'can store JSON metadata' do
      metadata = {
        'duration' => 180.5,
        'format' => 'WAV',
        'sample_rate' => 44100,
        'bit_depth' => 24
      }
      track_content = create(:track_content, metadata: metadata)

      expect(track_content.metadata).to eq(metadata)
      expect(track_content.metadata['duration']).to eq(180.5)
      expect(track_content.metadata['format']).to eq('WAV')
    end

    it 'can store file metadata' do
      file_metadata = {
        'file_size' => 1024000,
        'mime_type' => 'audio/wav',
        'original_filename' => 'my_track.wav',
        'uploaded_at' => Time.current.iso8601
      }
      track_content = create(:track_content, metadata: file_metadata)

      expect(track_content.metadata['file_size']).to eq(1024000)
      expect(track_content.metadata['mime_type']).to eq('audio/wav')
    end

    it 'can store audio-specific metadata' do
      audio_metadata = {
        'tempo' => 128,
        'key' => 'A minor',
        'time_signature' => '4/4',
        'instruments' => ['piano', 'drums', 'bass'],
        'effects' => {
          'reverb' => { 'room_size' => 0.8, 'damping' => 0.5 },
          'compression' => { 'ratio' => 4.0, 'threshold' => -12 }
        }
      }
      track_content = create(:track_content, metadata: audio_metadata)

      expect(track_content.metadata['tempo']).to eq(128)
      expect(track_content.metadata['instruments']).to include('piano')
      expect(track_content.metadata['effects']['reverb']['room_size']).to eq(0.8)
    end

    it 'handles nil metadata gracefully' do
      track_content = create(:track_content, metadata: nil)
      expect(track_content.metadata).to be_nil
    end

    it 'handles empty metadata gracefully' do
      track_content = create(:track_content, metadata: {})
      expect(track_content.metadata).to eq({})
    end
  end

  describe 'file attachment handling' do
    it 'can have an attached file' do
      track_content = create(:track_content)
      
      # Create a temporary file for testing
      file = Tempfile.new(['test_audio', '.wav'])
      file.write('fake audio data')
      file.rewind
      
      track_content.file.attach(
        io: file,
        filename: 'test_audio.wav',
        content_type: 'audio/wav'
      )
      
      expect(track_content.file).to be_attached
      expect(track_content.file.filename.to_s).to eq('test_audio.wav')
      expect(track_content.file.content_type).to eq('audio/wav')
      
      file.close
      file.unlink
    end

    it 'can exist without an attached file' do
      track_content = create(:track_content, content_type: 'lyrics')
      expect(track_content.file).not_to be_attached
    end

    it 'can handle different file types' do
      track_content = create(:track_content)
      
      # Test with different file extensions
      %w[.wav .mp3 .pdf .txt .jpg].each do |extension|
        file = Tempfile.new(['test', extension])
        file.write('test data')
        file.rewind
        
        track_content.file.attach(
          io: file,
          filename: "test#{extension}",
          content_type: 'application/octet-stream'
        )
        
        expect(track_content.file).to be_attached
        expect(track_content.file.filename.to_s).to eq("test#{extension}")
        
        file.close
        file.unlink
      end
    end
  end

  describe 'title and description' do
    it 'can have custom title and description' do
      track_content = create(:track_content, 
                            title: 'Final Mix',
                            description: 'The final stereo mix with mastering')
      
      expect(track_content.title).to eq('Final Mix')
      expect(track_content.description).to eq('The final stereo mix with mastering')
    end

    it 'can have very long titles and descriptions' do
      long_title = 'A' * 500
      long_description = 'B' * 2000
      
      track_content = create(:track_content, 
                            title: long_title,
                            description: long_description)
      
      expect(track_content.title.length).to eq(500)
      expect(track_content.description.length).to eq(2000)
    end
  end

  describe 'track version relationship' do
    it 'multiple contents can belong to the same track version' do
      track_version = create(:track_version)
      
      audio_content = create(:track_content, 
                            track_version: track_version, 
                            content_type: 'audio')
      lyrics_content = create(:track_content, 
                             track_version: track_version, 
                             content_type: 'lyrics')
      project_content = create(:track_content, 
                              track_version: track_version, 
                              content_type: 'project_file')

      expect(track_version.track_contents).to include(audio_content, lyrics_content, project_content)
      expect(track_version.track_contents.count).to eq(3)
    end

    it 'maintains referential integrity with track version' do
      track_version = create(:track_version)
      track_content = create(:track_content, track_version: track_version)

      # When track version is destroyed, content should be destroyed too
      expect { track_version.destroy }.to change(TrackContent, :count).by(-1)
    end
  end

  describe 'querying and filtering' do
    let(:track_version) { create(:track_version) }

    before do
      create(:track_content, track_version: track_version, content_type: 'audio', title: 'Main Mix')
      create(:track_content, track_version: track_version, content_type: 'lyrics', title: 'Song Lyrics')
      create(:track_content, track_version: track_version, content_type: 'project_file', title: 'Logic Project')
    end

    it 'can find contents by type' do
      audio_contents = track_version.track_contents.where(content_type: 'audio')
      expect(audio_contents.count).to eq(1)
      expect(audio_contents.first.title).to eq('Main Mix')
    end

    it 'can find contents by track version' do
      all_contents = track_version.track_contents
      expect(all_contents.count).to eq(3)
      expect(all_contents.pluck(:content_type)).to contain_exactly('audio', 'lyrics', 'project_file')
    end

    it 'can search contents by title' do
      matching_contents = track_version.track_contents.where('title ILIKE ?', '%mix%')
      expect(matching_contents.count).to eq(1)
      expect(matching_contents.first.content_type).to eq('audio')
    end
  end

  describe 'timestamps' do
    it 'sets created_at when track content is created' do
      track_content = create(:track_content)
      expect(track_content.created_at).to be_present
      expect(track_content.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when track content is modified' do
      track_content = create(:track_content)
      original_updated_at = track_content.updated_at
      
      sleep 0.1 # Ensure time difference
      track_content.update!(title: 'Updated Title')
      
      expect(track_content.updated_at).to be > original_updated_at
    end
  end

  describe 'edge cases' do
    it 'handles special characters in content types' do
      track_content = create(:track_content, content_type: 'custom_type_with_underscores')
      expect(track_content.content_type).to eq('custom_type_with_underscores')
    end

    it 'handles very long content types' do
      long_type = 'a' * 100
      track_content = create(:track_content, content_type: long_type)
      expect(track_content.content_type.length).to eq(100)
    end

    it 'handles multiline text content with various line endings' do
      multiline_text = "Line 1\nLine 2\r\nLine 3\rLine 4"
      track_content = create(:track_content, text_content: multiline_text)
      expect(track_content.text_content).to eq(multiline_text)
    end
  end

  describe 'data integrity' do
    it 'can be created and persisted correctly' do
      track_content = create(:track_content,
                            title: 'Test Content',
                            description: 'Test Description',
                            content_type: 'audio',
                            text_content: 'Sample text',
                            metadata: { 'key' => 'value' })
      
      # Reload from database to ensure persistence
      reloaded_content = TrackContent.find(track_content.id)
      
      expect(reloaded_content.title).to eq('Test Content')
      expect(reloaded_content.description).to eq('Test Description')
      expect(reloaded_content.content_type).to eq('audio')
      expect(reloaded_content.text_content).to eq('Sample text')
      expect(reloaded_content.metadata['key']).to eq('value')
    end
  end
end