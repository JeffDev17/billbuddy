class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :navigation_service

  def navigation_service
    @navigation_service ||= NavigationSessionService.new(session)
  end

  def store_current_filters(filters, key = :filters)
    session_key = "#{controller_name}_#{key}"
    clean_filters = filters.reject { |k, v| v.blank? }
    session[session_key] = clean_filters
  end

  def restore_filters_from_session(key = :filters)
    session_key = "#{controller_name}_#{key}"
    session[session_key] || {}
  end

  def clear_filters_from_session(key = :filters)
    session_key = "#{controller_name}_#{key}"
    session.delete(session_key)
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end
end
