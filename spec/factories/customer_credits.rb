FactoryBot.define do
  factory :customer_credit do
    customer { nil }
    service_package { nil }
    remaining_hours { 1.5 }
    purchase_date { "2025-05-08 14:07:32" }
  end
end
