FactoryBot.define do
  factory :audio_file do
    sequence(:filename) { |n| "audio_file_#{n}.mp3" }
    file_type { "audio/mpeg" }
    file_size { 1024 * 1024 } # 1MB
    duration { 180.5 } # 3 minutes and 30 seconds
    waveform_data { "[0.1, 0.2, 0.3, 0.4, 0.5, 0.4, 0.3, 0.2, 0.1]" }
    metadata { { 'sample_rate' => 44100, 'channels' => 2 } }
    association :folder
    association :project
    association :user
    
    trait :with_file do
      after(:build) do |audio_file|
        # This is a placeholder - in a real test, you would attach a fixture file
        # audio_file.file.attach(io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3')), 
        #                        filename: 'test_audio.mp3', 
        #                        content_type: 'audio/mpeg')
      end
    end
    
    trait :wav do
      filename { "audio_file.wav" }
      file_type { "audio/wav" }
    end
    
    trait :flac do
      filename { "audio_file.flac" }
      file_type { "audio/flac" }
    end
  end
end