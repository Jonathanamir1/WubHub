FactoryBot.define do
  factory :track_content do
    track_version { nil }
    content_type { "MyString" }
    text_content { "MyText" }
    metadata { "" }
  end
end
