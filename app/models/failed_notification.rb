class FailedNotification < ApplicationRecord
  belongs_to :customer

  validates :notification_type, presence: true
  validates :error_message, presence: true

  scope :retryable, -> { where('created_at > ?', 24.hours.ago) }
end
