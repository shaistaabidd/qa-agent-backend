class AuthMailer < ApplicationMailer
  def verification_code
    @user = params[:user]
    @code = params[:code]
    hide_in_email_log(@code)
    @purpose = params[:purpose]
    @valid_for_minutes = OneTimePassword::TTL.in_minutes.to_i

    mail to: params.fetch(:to, @user.email), subject: t(".subject.#{@purpose}")
  end
end
