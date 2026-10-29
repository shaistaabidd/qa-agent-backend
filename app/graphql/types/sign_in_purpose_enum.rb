module Types
  class SignInPurposeEnum < BaseEnum
    DESCRIPTIONS = {
      "login" => "The code from the login step",
      "password_reset" => "The code from forgot password"
    }.freeze

    description "Which emailed code a sign-in screen is working with"

    OneTimePassword::SIGN_IN_PURPOSES.each { value it, DESCRIPTIONS.fetch(it), value: it }
  end
end
