module Types
  class UserAccessStatusEnum < BaseEnum
    DESCRIPTIONS = {
      "active" => "Access is enabled",
      "inactive" => "Access has been revoked by an admin"
    }.freeze

    description "Whether an account may sign in"

    Users::FilterQuery::ACCESS_STATUSES.each { value it, DESCRIPTIONS.fetch(it), value: it }
  end
end
