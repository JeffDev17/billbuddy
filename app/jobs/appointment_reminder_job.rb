class AppointmentReminderJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    User.where(appointment_reminders_enabled: true).find_each do |user|
      AppointmentReminderService.send_upcoming_reminders(user)
    end
  end
end
