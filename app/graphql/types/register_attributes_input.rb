module Types
  class RegisterAttributesInput < BaseInputObject
    description "Details for a new self-registered account"

    argument :email, String, description: "Sign-in email address"
    argument :password, String, description: "8+ characters with upper, lower and special characters"
    argument :password_confirmation, String, description: "Must match password"
    argument :first_name, String, required: false, description: "Given name"
    argument :last_name, String, required: false, description: "Family name"
  end
end
