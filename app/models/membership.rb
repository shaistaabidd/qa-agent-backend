class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum :role, { member: 0, admin: 1 }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :project_id }
end
