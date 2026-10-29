module Types
  class ProjectRoleEnum < BaseEnum
    description "A person's role inside one project"

    value "MEMBER", "Can read the project", value: "member"
    value "ADMIN", "Can also connect integrations, store credentials, approve scope and run", value: "admin"
  end
end
