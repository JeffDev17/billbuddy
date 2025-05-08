FactoryBot.define do
  factory :service_package do
    name { "MyString" }
    hours { 1 }
    price { "9.99" }
    active { false }
  end
end
