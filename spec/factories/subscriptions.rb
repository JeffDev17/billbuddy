FactoryBot.define do
  factory :subscription do
    customer { nil }
    amount { "9.99" }
    start_date { "2025-05-08" }
    status { "MyString" }
  end
end
