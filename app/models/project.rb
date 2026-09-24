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

  private

  def clear_repo_connection
    # rubocop:disable-next Rails/SkipsModelValidations -- mid-destroy; validating would be pointless and re-triggering callbacks unsafe
    update_column(:repo_connection_id, nil) if repo_connection_id.present?
  end
end
