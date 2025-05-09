# app/controllers/service_packages_controller.rb
class ServicePackagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service_package, only: [:show, :edit, :update, :destroy]

  def index
    @service_packages = ServicePackage.all.order(name: :asc)
  end

  def show
  end

  def new
    @service_package = ServicePackage.new(active: true)
  end

  def create
    @service_package = ServicePackage.new(service_package_params)

    if @service_package.save
      redirect_to @service_package, notice: 'Pacote de serviço criado com sucesso.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @service_package.update(service_package_params)
      redirect_to @service_package, notice: 'Pacote de serviço atualizado com sucesso.'
    else
      render :edit
    end
  end

  def destroy
    if @service_package.customer_credits.any?
      redirect_to service_packages_path, alert: 'Não é possível excluir um pacote que está sendo usado por clientes.'
    else
      @service_package.destroy
      redirect_to service_packages_path, notice: 'Pacote de serviço excluído com sucesso.'
    end
  end

  private

  def set_service_package
    @service_package = ServicePackage.find(params[:id])
  end

  def service_package_params
    params.require(:service_package).permit(:name, :hours, :price, :active)
  end
end