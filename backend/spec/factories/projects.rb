FactoryBot.define do
  factory :project do
    title { "MyString" }
    description { "MyText" }
    workspace { nil }
    user { nil }
    visibility { "MyString" }
  end
end
