FactoryBot.define do
  factory :track_version do
    title { "MyString" }
    waveform_data { "MyText" }
    project { nil }
    user { nil }
    metadata { "" }
  end
end
