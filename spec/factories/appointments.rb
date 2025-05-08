FactoryBot.define do
  factory :appointment do
    customer { nil }
    scheduled_at { "2025-05-08 14:08:14" }
    duration { 1.5 }
    status { "MyString" }
    notes { "MyText" }
  end
end
