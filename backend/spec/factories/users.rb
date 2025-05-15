FactoryBot.define do
  factory :user do
    email { "MyString" }
    username { "MyString" }
    name { "MyString" }
    bio { "MyText" }
    password_digest { "MyString" }
    profile_image { "MyString" }
  end
end
