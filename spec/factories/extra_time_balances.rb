FactoryBot.define do
  factory :extra_time_balance do
    customer { nil }
    hours { 1.5 }
    expiry_date { "2025-05-08" }
  end
end
