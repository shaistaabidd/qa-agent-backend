class Integration < ApplicationRecord
  belongs_to :project

  enum :integration_type, { github: 0, click_up: 1 }

  validates :integration_type, presence: true
  validates :project_id, uniqueness: { scope: :integration_type }
  validates :repo_full_name, presence: true, if: :github?

  # For click_up, external_account_id holds the ClickUp list_id findings get
  # posted into (mirrors how it holds the GitHub installation_id for github).
  validates :external_account_id, presence: true, if: :click_up?
end
