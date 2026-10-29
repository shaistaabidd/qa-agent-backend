module EmailChanges
  # Shared by any step that just changed @user.email, whichever path got it
  # there: alerts the address it changed away from, so a change nobody made
  # is caught right away.
  module NotifiesPreviousEmail
    private

    def notify_previous_email(previous_email)
      UserMailer.with(user: @user, previous_email:).email_changed.deliver_later
    end
  end
end
