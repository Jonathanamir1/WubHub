# backend/spec/models/audio_file_spec.rb
require 'rails_helper'

RSpec.describe AudioFile, type: :model do
  describe 'validations' do
    it 'requires filename to be present' do
      audio_file = AudioFile.new(filename: nil)
      expect(audio_file).not_to be_valid
      expect(audio_file.errors[:filename]).to include("can't be blank")
    end

    it 'requires filename to be unique within folder' do
      folder = create(:folder)
      create(:audio_file, folder: folder, filename: 'kick.wav')
      
      duplicate_file = build(:audio_file, folder: folder, filename: 'kick.wav')
      expect(duplicate_file).not_to be_valid
      expect(duplicate_file.errors[:filename]).to include('has already been taken')
    end

    it 'allows same filename in different folders' do
      folder1 = create(:folder)
      folder2 = create(:folder)
      
      file1 = create(:audio_file, folder: folder1, filename: 'kick.wav')
      file2 = build(:audio_file, folder: folder2, filename: 'kick.wav')
      
      expect(file2).to be_valid
    end

    it 'is valid with all required attributes' do
      audio_file = build(:audio_file)
      expect(audio_file).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:folder) }
    it { should belong_to(:project) }
    it { should belong_to(:user) }
    it { should have_one_attached(:file) }

    it 'belongs to a folder' do
      folder = create(:folder)
      audio_file = create(:audio_file, folder: folder)

      expect(audio_file.folder).to eq(folder)
      expect(folder.audio_files).to include(audio_file)
    end

    it 'belongs to a project' do
      project = create(:project)
      audio_file = create(:audio_file, project: project)

      expect(audio_file.project).to eq(project)
      expect(project.audio_files).to include(audio_file)
    end

    it 'belongs to a user' do
      user = create(:user)
      audio_file = create(:audio_file, user: user)

      expect(audio_file.user).to eq(user)
      expect(user.audio_files).to include(audio_file)
    end
  end

  describe 'file type handling' do
    it 'can store various audio file types' do
      file_types = %w[audio/wav audio/mp3 audio/aiff audio/flac audio/ogg]
      
      file_types.each do |file_type|
        audio_file = create(:audio_file, file_type: file_type)
        expect(audio_file.file_type).to eq(file_type)
      end
    end

    it 'validates allowed content types' do
      allowed_types = [
        'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/x-wav',
        'audio/aiff', 'audio/x-aiff', 'audio/flac', 'audio/ogg', 'audio/x-ms-wma'
      ]
      
      allowed_types.each do |content_type|
        # This test assumes you have validation for allowed content types
        # If not implemented yet, this will help guide the implementation
        expect(AudioFile::ALLOWED_CONTENT_TYPES).to include(content_type)
      end
    end
  end

  describe 'file attachment handling' do
    it 'can have an attached file' do
      audio_file = create(:audio_file)
      
      # Create a temporary file for testing
      temp_file = Tempfile.new(['test_audio', '.wav'])
      temp_file.write('fake audio data')
      temp_file.rewind
      
      audio_file.file.attach(
        io: temp_file,
        filename: 'test_audio.wav',
        content_type: 'audio/wav'
      )
      
      expect(audio_file.file).to be_attached
      expect(audio_file.file.filename.to_s).to eq('test_audio.wav')
      expect(audio_file.file.content_type).to eq('audio/wav')
      
      temp_file.close
      temp_file.unlink
    end

    it 'can exist without an attached file' do
      audio_file = create(:audio_file)
      expect(audio_file.file).not_to be_attached
    end

    it 'can handle different audio file extensions' do
      extensions = %w[.wav .mp3 .aiff .flac .ogg .m4a]
      
      extensions.each do |ext|
        audio_file = create(:audio_file)
        temp_file = Tempfile.new(['test', ext])
        temp_file.write('audio data')
        temp_file.rewind
        
        audio_file.file.attach(
          io: temp_file,
          filename: "test#{ext}",
          content_type: 'audio/wav'
        )
        
        expect(audio_file.file).to be_attached
        expect(audio_file.file.filename.to_s).to eq("test#{ext}")
        
        temp_file.close
        temp_file.unlink
      end
    end
  end

  describe 'audio metadata handling' do
    it 'can store basic audio metadata' do
      metadata = {
        'duration' => 180.5,
        'sample_rate' => 44100,
        'bit_depth' => 24,
        'format' => 'WAV',
        'channels' => 2
      }
      audio_file = create(:audio_file, metadata: metadata)

      expect(audio_file.metadata).to eq(metadata)
      expect(audio_file.metadata['duration']).to eq(180.5)
      expect(audio_file.metadata['sample_rate']).to eq(44100)
    end

    it 'can store musical metadata' do
      musical_metadata = {
        'tempo' => 128.0,
        'key' => 'A minor',
        'time_signature' => '4/4',
        'genre' => 'Electronic',
        'instruments' => ['synthesizer', 'drums', 'bass'],
        'mood' => 'energetic'
      }
      audio_file = create(:audio_file, metadata: musical_metadata)

      expect(audio_file.metadata['tempo']).to eq(128.0)
      expect(audio_file.metadata['instruments']).to include('synthesizer')
    end

    it 'can store technical audio metadata' do
      technical_metadata = {
        'peak_level' => -3.2,
        'rms_level' => -12.4,
        'dynamic_range' => 8.7,
        'loudness_lufs' => -23.1,
        'true_peak' => -2.8,
        'spectral_centroid' => 2500.0
      }
      audio_file = create(:audio_file, metadata: technical_metadata)

      expect(audio_file.metadata['peak_level']).to eq(-3.2)
      expect(audio_file.metadata['loudness_lufs']).to eq(-23.1)
    end

    it 'handles nil metadata gracefully' do
      audio_file = create(:audio_file, metadata: nil)
      expect(audio_file.metadata).to be_nil
    end

    it 'handles empty metadata gracefully' do
      audio_file = create(:audio_file, metadata: {})
      expect(audio_file.metadata).to eq({})
    end
  end

  describe 'waveform data handling' do
    it 'can store waveform data as string' do
      waveform = '[0.1, 0.2, 0.8, 0.5, 0.3, 0.1, 0.0, -0.2, -0.5, -0.3]'
      audio_file = create(:audio_file, waveform_data: waveform)
      
      expect(audio_file.waveform_data).to eq(waveform)
    end

    it 'can store large waveform datasets' do
      # Simulate a 3-minute audio file at 44.1kHz (simplified)
      large_waveform = Array.new(1000) { rand(-1.0..1.0).round(3) }.to_json
      audio_file = create(:audio_file, waveform_data: large_waveform)
      
      expect(audio_file.waveform_data).to eq(large_waveform)
      expect(audio_file.waveform_data.length).to be > 1000
    end

    it 'handles empty waveform data' do
      audio_file = create(:audio_file, waveform_data: '')
      expect(audio_file.waveform_data).to eq('')
    end

    it 'handles nil waveform data' do
      audio_file = create(:audio_file, waveform_data: nil)
      expect(audio_file.waveform_data).to be_nil
    end
  end

  describe 'file properties' do
    it 'can store file size information' do
      audio_file = create(:audio_file, file_size: 1024000)  # 1MB
      expect(audio_file.file_size).to eq(1024000)
    end

    it 'can store duration information' do
      audio_file = create(:audio_file, duration: 180.5)  # 3 minutes 30.5 seconds
      expect(audio_file.duration).to eq(180.5)
    end

    it 'can handle various file sizes' do
      sizes = [1024, 1048576, 10485760, 104857600]  # 1KB, 1MB, 10MB, 100MB
      
      sizes.each do |size|
        audio_file = create(:audio_file, file_size: size)
        expect(audio_file.file_size).to eq(size)
      end
    end

    it 'can handle various durations' do
      durations = [10.5, 60.0, 180.25, 600.75]  # Various song lengths
      
      durations.each do |duration|
        audio_file = create(:audio_file, duration: duration)
        expect(audio_file.duration).to eq(duration)
      end
    end
  end

  describe 'audio analysis' do
    it 'responds to analyze_audio method' do
      audio_file = create(:audio_file)
      expect(audio_file).to respond_to(:analyze_audio)
    end

    it 'can analyze attached audio file' do
      audio_file = create(:audio_file)
      
      # Mock file attachment
      temp_file = Tempfile.new(['test', '.wav'])
      temp_file.write('fake audio data')
      temp_file.rewind
      
      audio_file.file.attach(
        io: temp_file,
        filename: 'test.wav',
        content_type: 'audio/wav'
      )
      
      # This should not raise an error
      expect { audio_file.analyze_audio }.not_to raise_error
      
      # Should update file properties based on attachment
      audio_file.analyze_audio
      expect(audio_file.file_size).to be_present if audio_file.file.attached?
      expect(audio_file.file_type).to be_present if audio_file.file.attached?
      
      temp_file.close
      temp_file.unlink
    end
  end

  describe 'file organization' do
    let(:project) { create(:project) }
    let(:drums_folder) { create(:folder, project: project, name: 'drums') }
    let(:vocals_folder) { create(:folder, project: project, name: 'vocals') }

    it 'can organize files in different folders' do
      kick_file = create(:audio_file, folder: drums_folder, project: project, filename: 'kick.wav')
      vocal_file = create(:audio_file, folder: vocals_folder, project: project, filename: 'lead_vocal.wav')

      expect(drums_folder.audio_files).to include(kick_file)
      expect(vocals_folder.audio_files).to include(vocal_file)
      expect(drums_folder.audio_files).not_to include(vocal_file)
    end

    it 'maintains project relationship across folders' do
      file1 = create(:audio_file, folder: drums_folder, project: project)
      file2 = create(:audio_file, folder: vocals_folder, project: project)

      expect(project.audio_files).to include(file1, file2)
    end
  end

  describe 'querying and filtering' do
    let(:project) { create(:project) }
    let(:folder) { create(:folder, project: project) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      create(:audio_file, folder: folder, project: project, user: user1, filename: 'kick.wav', file_type: 'audio/wav')
      create(:audio_file, folder: folder, project: project, user: user1, filename: 'snare.wav', file_type: 'audio/wav')
      create(:audio_file, folder: folder, project: project, user: user2, filename: 'bass.mp3', file_type: 'audio/mp3')
    end

    it 'can find files by user' do
      user1
      user2
      project
      folder
      
      user1_files = folder.audio_files.where(user: user1)
      expect(user1_files.count).to eq(2)
      expect(user1_files.pluck(:filename)).to contain_exactly('kick.wav', 'snare.wav')
    end

    it 'can find files by file type' do
      user1
      user2
      project
      folder
      
      wav_files = folder.audio_files.where(file_type: 'audio/wav')
      mp3_files = folder.audio_files.where(file_type: 'audio/mp3')
      
      expect(wav_files.count).to eq(2)
      expect(mp3_files.count).to eq(1)
    end

    it 'can search files by filename pattern' do
      user1
      user2
      project
      folder
      
      drum_files = folder.audio_files.where('filename ILIKE ?', '%k%')  # kick, snare (has 'k')
      expect(drum_files.count).to eq(1)  # Only kick.wav matches
      expect(drum_files.first.filename).to eq('kick.wav')
    end
  end

  describe 'data integrity' do
    it 'is destroyed when folder is destroyed' do
      folder = create(:folder)
      audio_file = create(:audio_file, folder: folder)

      expect { folder.destroy }.to change(AudioFile, :count).by(-1)
    end

    it 'is destroyed when project is destroyed' do
      project = create(:project)
      audio_file = create(:audio_file, project: project)

      expect { project.destroy }.to change(AudioFile, :count).by(-1)
    end

    it 'is destroyed when user is destroyed' do
      user = create(:user)
      audio_file = create(:audio_file, user: user)

      expect { user.destroy }.to change(AudioFile, :count).by(-1)
    end

    it 'maintains referential integrity' do
      audio_file = create(:audio_file)
      
      expect(audio_file.folder).to be_present
      expect(audio_file.project).to be_present
      expect(audio_file.user).to be_present
    end
  end

  describe 'timestamps' do
    it 'sets created_at when audio file is created' do
      audio_file = create(:audio_file)
      expect(audio_file.created_at).to be_present
      expect(audio_file.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when audio file is modified' do
      audio_file = create(:audio_file)
      original_updated_at = audio_file.updated_at
      
      sleep 0.1 # Ensure time difference
      audio_file.update!(filename: 'updated_filename.wav')
      
      expect(audio_file.updated_at).to be > original_updated_at
    end
  end

  describe 'edge cases' do
    it 'handles very long filenames' do
      long_filename = 'a' * 200 + '.wav'
      audio_file = build(:audio_file, filename: long_filename)
      expect(audio_file.filename.length).to eq(204)
    end

    it 'handles unicode in filenames' do
      unicode_filename = '🎵_音楽_файл.wav'
      audio_file = create(:audio_file, filename: unicode_filename)
      expect(audio_file.filename).to eq(unicode_filename)
    end

    it 'handles special characters in filenames' do
      special_filename = 'track-1_final(mix).wav'
      audio_file = create(:audio_file, filename: special_filename)
      expect(audio_file.filename).to eq(special_filename)
    end

    it 'handles very large file sizes' do
      large_size = 1073741824  # 1GB
      audio_file = create(:audio_file, file_size: large_size)
      expect(audio_file.file_size).to eq(large_size)
    end

    it 'handles very long durations' do
      long_duration = 3600.0  # 1 hour
      audio_file = create(:audio_file, duration: long_duration)
      expect(audio_file.duration).to eq(long_duration)
    end
  end

  describe 'music production workflow' do
    let(:project) { create(:project) }
    let(:stems_folder) { create(:folder, project: project, name: 'stems') }
    let(:bounces_folder) { create(:folder, project: project, name: 'bounces') }

    it 'supports typical music production file organization' do
      # Individual stems
      drum_stem = create(:audio_file, folder: stems_folder, project: project, filename: 'drums.wav')
      bass_stem = create(:audio_file, folder: stems_folder, project: project, filename: 'bass.wav')
      vocal_stem = create(:audio_file, folder: stems_folder, project: project, filename: 'vocals.wav')
      
      # Final bounces
      rough_mix = create(:audio_file, folder: bounces_folder, project: project, filename: 'rough_mix_v1.wav')
      final_mix = create(:audio_file, folder: bounces_folder, project: project, filename: 'final_mix.wav')

      expect(stems_folder.audio_files.count).to eq(3)
      expect(bounces_folder.audio_files.count).to eq(2)
      expect(project.audio_files.count).to eq(5)
    end
  end

  describe 'data persistence' do
    it 'persists correctly to database' do
      audio_file = create(:audio_file,
                        filename: 'test_audio.wav',
                        file_type: 'audio/wav',
                        file_size: 1024000,
                        duration: 180.5,
                        metadata: { 'tempo' => 120 },
                        waveform_data: '[0.1, 0.2, 0.3]')
      
      # Reload from database
      reloaded_file = AudioFile.find(audio_file.id)
      
      expect(reloaded_file.filename).to eq('test_audio.wav')
      expect(reloaded_file.file_type).to eq('audio/wav')
      expect(reloaded_file.file_size).to eq(1024000)
      expect(reloaded_file.duration).to eq(180.5)
      expect(reloaded_file.metadata['tempo']).to eq(120)
      expect(reloaded_file.waveform_data).to eq('[0.1, 0.2, 0.3]')
    end
  end
end