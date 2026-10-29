class Integration < ApplicationRecord
  belongs_to :project

  enum :integration_type, { github: 0, click_up: 1 }, validate: true

  validates :project_id, uniqueness: { scope: :integration_type }
  # github: the App installation id, present as soon as the App is installed (repo_full_name is
  # filled in once an admin picks a repo, and only then does it become the project's repo
  # connection). click_up: the list findings are posted into.
  validates :external_account_id, presence: true
end
