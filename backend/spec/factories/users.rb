FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    bio { "A test user bio" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end