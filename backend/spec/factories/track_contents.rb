FactoryBot.define do
  factory :track_content do
    sequence(:title) { |n| "Content #{n}" }
    description { "Test track content" }
    content_type { "audio" }
    text_content { "Sample lyrics or notes" }
    metadata { { "duration" => 180, "format" => "wav" } }
    association :track_version
    
    user { track_version.user }

    trait :lyrics do
      content_type { "lyrics" }
      text_content { "Verse 1: Sample lyrics here..." }
    end

    trait :audio do
      content_type { "audio" }
      text_content { nil }
    end
  end
end