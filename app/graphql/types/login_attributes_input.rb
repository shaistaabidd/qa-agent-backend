module Types
  class LoginAttributesInput < BaseInputObject
    description "Credentials for the first login step"

    argument :email, String, description: "Account email address"
    argument :password, String, description: "Account password"
  end
end
