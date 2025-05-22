FactoryBot.define do
  factory :track_version do
    sequence(:title) { |n| "Version #{n}" }
    description { "A test track version" }
    waveform_data { "sample_waveform_data" }
    metadata { { "tempo" => 120, "key" => "C major" } }
    association :project
    association :user

    trait :with_contents do
      after(:create) do |version|
        create_list(:track_content, 2, track_version: version)
      end
    end
  end
end