class ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def show
    # Display user profile
  end

  def edit
    # Edit user profile form
  end

  def update
    # For email changes, we need to validate current password
    if params[:user][:email] != @user.email
      unless @user.valid_password?(params[:user][:current_password])
        @user.errors.add(:current_password, "est\u00E1 incorreta")
        render :edit, status: :unprocessable_entity
        return
      end
    end

    if @user.update(user_params)
      redirect_to profile_path, notice: "Perfil atualizado com sucesso!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def change_password
    # Show change password form
  end

  def update_password
    if @user.valid_password?(params[:current_password])
      if @user.update(password_params)
        bypass_sign_in(@user) # Keep user signed in after password change
        redirect_to profile_path, notice: "Senha alterada com sucesso!"
      else
        flash.now[:alert] = "Erro ao alterar senha. Verifique os dados informados."
        render :change_password, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Senha atual incorreta."
      render :change_password, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:email)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
