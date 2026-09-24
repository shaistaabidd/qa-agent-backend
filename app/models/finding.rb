class Finding < ApplicationRecord
  belongs_to :run
  has_one_attached :screenshot

  enum :severity, { low: 0, medium: 1, high: 2, critical: 3 }

  validates :title, presence: true, uniqueness: { scope: :run_id }
  validates :severity, presence: true

  def screenshot_url
    return nil unless screenshot.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      screenshot, host: ENV.fetch('APP_BASE_URL', 'http://localhost:3000')
    )
  end
end
