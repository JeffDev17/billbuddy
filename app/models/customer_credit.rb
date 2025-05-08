class CustomerCredit < ApplicationRecord
  belongs_to :customer
  belongs_to :service_package
end
