module Invitations
  # Moving invitation_sent_at forward invalidates the previous invitation link.
  class ResendInvitation < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      @user.update!(invitation_sent_at: Time.current)
      InvitationMailer.with(user: @user).invitation.deliver_later
      success(@user)
    end
  end
end
