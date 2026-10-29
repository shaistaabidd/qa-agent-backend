module Types
  class ResetPasswordAttributesInput < BaseInputObject
    description "New password plus the token returned by validateOtp for a password reset"

    argument :password, String, description: "8+ characters with upper, lower and special characters"
    argument :password_confirmation, String, description: "Must match password"
    argument :reset_password_token, String, as: :token,
                                            description: "Token returned by validateOtp, valid for 15 minutes"
  end
end
