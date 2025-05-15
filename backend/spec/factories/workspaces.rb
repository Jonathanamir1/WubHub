FactoryBot.define do
  factory :workspace do
    name { "MyString" }
    description { "MyText" }
    workspace_type { "MyString" }
    visibility { "MyString" }
    user { nil }
  end
end
