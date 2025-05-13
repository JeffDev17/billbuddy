class ApplicationController < ActionController::Base
  # Comente ou remova qualquer linha relacionada a authenticate_user!
  before_action :authenticate_user!

  # Defina um método current_user simples para desenvolvimento
  helper_method :current_user

  def current_user
    # Retorna o primeiro usuário ou cria um se não existir
    @current_user ||= User.first_or_create(email: 'admin@example.com', password: 'password')
  end
end