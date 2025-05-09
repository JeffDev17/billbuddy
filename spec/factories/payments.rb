FactoryBot.define do
  factory :payment do
    customer { nil }
    payment_type { "MyString" }
    amount { "9.99" }
    payment_date { "2025-05-08" }
    notes { "MyText" }
  end
end
