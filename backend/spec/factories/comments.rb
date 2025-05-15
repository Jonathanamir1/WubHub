FactoryBot.define do
  factory :comment do
    content { "MyText" }
    user { nil }
    track_version { nil }
  end
end
