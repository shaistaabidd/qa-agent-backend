class UserMailer < ApplicationMailer
  def email_changed
    @user = params[:user]

    mail to: params[:previous_email], subject: t(".subject")
  end

  def registration_attempted
    @user = params[:user]

    mail to: @user.email, subject: t(".subject", app_name: Rails.configuration.x.app_name)
  end
end
