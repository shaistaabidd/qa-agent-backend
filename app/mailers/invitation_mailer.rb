class InvitationMailer < ApplicationMailer
  def invitation
    @user = params[:user]
    @inviter_name = @user.invited_by&.full_name
    token = @user.generate_token_for(:invitation)
    hide_in_email_log(token, CGI.escape(token))
    @accept_url = FrontendUrl.build("/setup-account", token:)
    @valid_for_days = User::INVITATION_TTL.in_days.to_i

    mail to: @user.email, subject: t(".subject", app_name: Rails.configuration.x.app_name)
  end
end
