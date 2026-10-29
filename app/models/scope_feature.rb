class ScopeFeature < ApplicationRecord
  belongs_to :project

  has_many :runs, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :project_id }
end
