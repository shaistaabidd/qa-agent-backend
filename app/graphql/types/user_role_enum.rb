module Types
  class UserRoleEnum < BaseEnum
    DESCRIPTIONS = {
      "user" => "A regular account holder",
      "super_admin" => "Platform administrator who manages every account"
    }.freeze

    description "What a user is allowed to do"

    User.roles.each_key { value it, DESCRIPTIONS.fetch(it), value: it }
  end
end
