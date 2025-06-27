# spec/factories/queue_items.rb
FactoryBot.define do
  factory :queue_item do
    association :workspace
    association :user
    
    batch_id { SecureRandom.uuid }
    draggable_type { :file }  # Use symbol for enum
    draggable_name { 'test_audio.mp3' }
    original_path { '/Users/musician/Desktop/test_audio.mp3' }
    total_files { 1 }
    completed_files { 0 }
    failed_files { 0 }
    status { :pending }  # Use symbol for enum
    metadata { {} }
    
    trait :folder do
      draggable_type { :folder }
      draggable_name { 'Audio Project' }
      original_path { '/Users/musician/Desktop/Audio Project' }
      total_files { 5 }
    end
    
    trait :mixed do
      draggable_type { :mixed }
      draggable_name { 'Mixed Files Drop' }
      total_files { 8 }
    end
    
    trait :processing do
      status { :processing }
      completed_files { 2 }
    end
    
    trait :completed do
      status { :completed }
      completed_files { 5 }
      total_files { 5 }
    end
    
    trait :failed do
      status { :failed }
      completed_files { 3 }
      failed_files { 2 }
      total_files { 5 }
    end
    
    trait :with_metadata do
      metadata do
        {
          upload_source: 'drag_drop',
          client_info: {
            browser: 'Chrome',
            version: '91.0',
            user_agent: 'Mozilla/5.0...'
          },
          original_folder_structure: ['Drums', 'Bass', 'Vocals'],
          drop_timestamp: Time.current.iso8601
        }
      end
    end
    
    trait :large_batch do
      total_files { 25 }
      draggable_type { :folder }
      draggable_name { 'Large Audio Session' }
    end
  end
end