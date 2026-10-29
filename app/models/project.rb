class Project < ApplicationRecord
  NAME_MAX_LENGTH = 255
  TARGET_URL_MAX_LENGTH = 2048

  belongs_to :repo_connection, class_name: "Integration", optional: true

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :integrations, dependent: :destroy
  has_many :role_credentials, dependent: :destroy
  has_many :scope_features, dependent: :destroy
  has_many :runs, dependent: :destroy

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :target_url, presence: true, length: { maximum: TARGET_URL_MAX_LENGTH }
  validates :target_url, public_http_url: true

  def repo_connected? = repo_connection_id.present?
  def github_installed? = integrations.any?(&:github?)

  # Stores the GitHub App installation; the repo is picked separately. A different
  # installation can't see the old repo, so that link is dropped.
  def attach_github_installation!(installation_id)
    integration = integrations.find_or_initialize_by(integration_type: :github)
    installation_changed = integration.external_account_id != installation_id.to_s

    # The user just changed what the installation can see on GitHub.
    GitHubAppService.forget_repositories(installation_id)

    transaction do
      update!(repo_connection: nil) if installation_changed && repo_connection
      integration.update!(
        external_account_id: installation_id.to_s,
        repo_full_name: installation_changed ? nil : integration.repo_full_name,
        scope: "contents:read"
      )
    end
    self
  end
end
