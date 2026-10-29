module Types
  class UserFilterInput < PaginatedFilterInput
    description "Filters and paging for the user list"

    argument :role, UserRoleEnum, required: false, description: "Only users with this role"
    argument :search, String, required: false, description: "Matches email, first name or last name"
    argument :status, UserAccessStatusEnum, required: false, description: "Only users with this access status"
    argument :pending, Boolean, required: false,
                                description: "True for pending invitations only, false to exclude them"
    argument :archived, Boolean, required: false, description: "True for archived users only, false to exclude them"
  end
end
