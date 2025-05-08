FactoryBot.define do
  factory :customer do
    name { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    status { "MyString" }
    plan_type { "MyString" }
    user { nil }
  end
end
