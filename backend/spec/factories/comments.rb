FactoryBot.define do
  factory :comment do
    content { "This is a test comment" }
    association :user
    association :track_version
  end
end