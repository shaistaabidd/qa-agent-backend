module Types
  class AcceptInvitationAttributesInput < BaseInputObject
    description "Password for an invited account plus the token from the invitation link"

    argument :password, String, description: "8+ characters with upper, lower and special characters"
    argument :password_confirmation, String, description: "Must match password"
    argument :token, String, description: "Token from the invitation link"
  end
end
