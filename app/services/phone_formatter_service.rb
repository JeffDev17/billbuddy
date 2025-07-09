# Service to handle phone number formatting
class PhoneFormatterService
  def self.format(phone)
    return nil if phone.blank?

    # Remove caracteres não numéricos, mantendo o +
    numbers_only = phone.gsub(/[^\d+]/, "")

    # Garante que começa com +
    numbers_only.start_with?("+") ? numbers_only : "+#{numbers_only}"
  end
end
