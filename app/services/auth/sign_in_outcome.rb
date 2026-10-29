module Auth
  # What a sign-in-capable operation hands back: the verified user, and a
  # session only when access was granted immediately (otp_enabled off)
  # rather than via a code the caller still has to confirm with ValidateOtp.
  SignInOutcome = Data.define(:user, :session)
end
