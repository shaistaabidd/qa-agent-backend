class Finding < ApplicationRecord
  # Where the problem lives, derived from the evidence type the worker recorded:
  # backend  - the server: exceptions, SQL/N+1, memory, 5xx, GraphQL errors, slow responses
  # network  - a request that was rejected (4xx) or never completed
  # frontend - the browser: JS crashes, console errors, blank/error screens, page speed, leaks
  SOURCES = %w[frontend backend network].freeze
  BACKEND_TYPES = %w[n_plus_one slow_query query_count backend_allocations backend_memory_growth
                     graphql_error slow_request].freeze
  NETWORK_TYPES = %w[request_failed page_load_failed].freeze
  SCREENSHOT_URL_TTL = 1.hour

  belongs_to :run
  has_one_attached :screenshot

  enum :severity, { low: 0, medium: 1, high: 2, critical: 3 }, validate: true

  before_validation :assign_source

  validates :title, presence: true, uniqueness: { scope: :run_id }
  validates :source, inclusion: { in: SOURCES }

  scope :from_source, ->(source) { where(source:) }

  # A screenshot whose storage service can't be reached (for example a bucket that isn't configured in
  # this environment) reads as "no screenshot" rather than failing the whole list it appears in.
  def screenshot_url
    screenshot.url(expires_in: SCREENSHOT_URL_TTL) if screenshot.attached?
  rescue StandardError => e
    Rails.logger.warn("Finding##{id} screenshot unavailable: #{e.class}: #{e.message}")
    nil
  end

  private

  # Set once on save, so listing by source is a plain indexed column filter.
  def assign_source
    type = details["type"]
    server_error = type == "http_error" && details.dig("request", "status").to_i >= 500

    self.source =
      if category == "backend" || BACKEND_TYPES.include?(type) || server_error
        "backend"
      elsif category == "network" || NETWORK_TYPES.include?(type)
        "network"
      else
        "frontend"
      end
  end
end
