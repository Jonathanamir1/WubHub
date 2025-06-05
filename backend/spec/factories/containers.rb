FactoryBot.define do
  factory :container do
    workspace { nil }
    parent_container { nil }
    name { "MyString" }
    container_type { "MyString" }
    template_level { 1 }
    metadata { "" }
  end
end
