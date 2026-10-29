module Auth
  # Shared by any operation that has just verified who someone is and must
  # decide how to let them in: with otp_enabled on, email a login code and
  # make them confirm it (see ValidateOtp); with it off, start their session
  # immediately instead.
  module GrantsAccess
    private

    def grant_access(user)
      if FeatureFlag.enabled?(:otp_enabled, user)
        OneTimePasswords::SendCode.call(user:, purpose: :login)
        nil
      else
        start_session(user)
      end
    end

    def start_session(user)
      user.touch(:last_sign_in_at)
      Session.start_for!(user)
    end
  end
end
