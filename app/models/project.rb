class Project < ApplicationRecord
  belongs_to :repo_connection, class_name: 'Integration', optional: true

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :integrations, dependent: :destroy
  has_many :role_credentials, dependent: :destroy
  has_many :scope_features, dependent: :destroy
  has_many :runs, dependent: :destroy

  validates :name, presence: true
  validates :target_url, presence: true

  # projects.repo_connection_id and integrations.project_id reference each
  # other, so the has_many :integrations dependent: :destroy would otherwise
  # hit a FK violation trying to delete the row this project still points to.
  before_destroy :clear_repo_connection, prepend: true

  # Stores the GitHub App installation; the repo is picked separately. A
  # different installation can't see the old repo, so that link is dropped.
  def attach_github_installation!(installation_id)
    integration = integrations.find_or_initialize_by(integration_type: :github)
    installation_changed = integration.external_account_id != installation_id.to_s

    transaction do
      update!(repo_connection: nil) if installation_changed && repo_connection
      integration.update!(
        external_account_id: installation_id.to_s,
        repo_full_name: installation_changed ? nil : integration.repo_full_name,
        scope: 'contents:read'
      )
    end
    self
  end

  private

  def clear_repo_connection
    # rubocop:disable-next Rails/SkipsModelValidations -- mid-destroy; validating would be pointless and re-triggering callbacks unsafe
    update_column(:repo_connection_id, nil) if repo_connection_id.present?
  end
end
