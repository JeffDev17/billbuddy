module CreditDeductible
  extend ActiveSupport::Concern

  def deduct_credits(hours, reason = nil)
    return false if hours <= 0
    
    ActiveRecord::Base.transaction do
      remaining_hours = hours
      credits = customer_credits.where('remaining_hours > 0').order(purchase_date: :asc)
      
      credits.each do |credit|
        break if remaining_hours <= 0
        
        if credit.remaining_hours >= remaining_hours
          credit.update!(remaining_hours: credit.remaining_hours - remaining_hours)
          remaining_hours = 0
        else
          remaining_hours -= credit.remaining_hours
          credit.update!(remaining_hours: 0)
        end
      end
      
      if remaining_hours == 0
        create_appointment_record(hours, reason)
        true
      else
        raise ActiveRecord::Rollback
        false
      end
    end
  end

  private

  def create_appointment_record(hours, reason)
    appointments.create!(
      scheduled_at: Time.current,
      duration: hours,
      status: 'completed',
      notes: reason ? "Débito manual: #{reason}" : nil
    )
  end
end 