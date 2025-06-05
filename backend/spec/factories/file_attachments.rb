FactoryBot.define do
  factory :file_attachment do
    sequence(:filename) { |n| "file_#{n}.wav" }
    content_type { "audio/wav" }
    file_size { 1024 }
    metadata { { duration: 180 } }
    
    # Use existing factories and make sure user creates the project
    user { attachable.user }  # User who owns the attachable resource
    
    trait :attached_to_project do
      association :attachable, factory: :project
    end
    
    trait :attached_to_workspace do
      association :attachable, factory: :workspace
    end
    
    trait :attached_to_track_version do
      association :attachable, factory: :track_version
    end

  end
end