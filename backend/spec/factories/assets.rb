FactoryBot.define do
  factory :asset do
    sequence(:filename) { |n| "file_#{n}.mp3" }
    association :workspace
    association :user
    file_size { rand(1024..10_485_760) }  # 1KB to 10MB
    content_type { 'audio/mpeg' }
    
    # Make sure container belongs to the same workspace
    trait :in_container do
      container { association(:container, workspace: workspace) }
    end
    
    trait :in_root do
      container { nil }
    end
    
    # File type traits
    trait :audio_file do
      filename { "#{Faker::Music.album.parameterize}.mp3" }
      content_type { 'audio/mpeg' }
    end
    
    trait :wav_file do
      filename { "#{Faker::Music.album.parameterize}.wav" }
      content_type { 'audio/wav' }
    end
    
    trait :project_file do
      filename { "#{Faker::Music.album.parameterize}.logic" }
      content_type { 'application/octet-stream' }
    end
    
    trait :image_file do
      filename { "cover_art.jpg" }
      content_type { 'image/jpeg' }
    end
    
    trait :document_file do
      filename { "lyrics.pdf" }
      content_type { 'application/pdf' }
    end
    
    trait :large_file do
      file_size { 50_000_000 }  # 50MB
    end
    
    trait :with_attached_file do
      after(:create) do |asset|
        # Create a temporary file for testing
        temp_file = Tempfile.new(['test', File.extname(asset.filename)])
        temp_file.write("Test file content for #{asset.filename}")
        temp_file.rewind
        
        asset.file_blob.attach(
          io: temp_file,
          filename: asset.filename,
          content_type: asset.content_type
        )
        
        temp_file.close
        temp_file.unlink
      end
    end
  end
end