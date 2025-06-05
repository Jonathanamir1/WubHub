FactoryBot.define do
  factory :track_content do
    container { nil }
    user { nil }
    title { "MyString" }
    description { "MyText" }
    content_type { "MyString" }
    text_content { "MyText" }
    metadata { "" }
  end
end
