module Types
  class InvitationRejectionType < BaseObject
    description "An address that was not invited"

    field :email, String, null: false, description: "The address that was skipped"
    field :message, String, null: false, description: "Why it was skipped"
  end
end
