class Integration < ApplicationRecord
  belongs_to :project

  enum :integration_type, { github: 0, click_up: 1 }

  validates :integration_type, presence: true
  validates :project_id, uniqueness: { scope: :integration_type }
  # A github integration exists as soon as the App is installed (it holds the
  # installation_id in external_account_id); repo_full_name is filled in once
  # the admin picks a repo, and only then does it become the repo_connection.
  validates :external_account_id, presence: true, if: :github?

  # For click_up, external_account_id holds the ClickUp list_id findings get
  # posted into (mirrors how it holds the GitHub installation_id for github).
  validates :external_account_id, presence: true, if: :click_up?
end
