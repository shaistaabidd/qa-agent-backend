class Finding < ApplicationRecord
  belongs_to :run
  has_one_attached :screenshot

  enum :severity, { low: 0, medium: 1, high: 2, critical: 3 }

  # Where the problem lives, derived from the evidence type the worker recorded:
  # backend  — the server: exceptions, SQL/N+1, memory, 5xx, GraphQL errors, slow responses
  # network  — a request that was rejected (4xx) or never completed
  # frontend — the browser: JS crashes, console errors, blank/error screens, page speed, leaks
  SOURCES = %w[frontend backend network].freeze
  BACKEND_TYPES = %w[n_plus_one slow_query query_count backend_allocations backend_memory_growth
                     graphql_error slow_request].freeze
  NETWORK_TYPES = %w[request_failed page_load_failed].freeze

  SOURCE_SQL = <<~SQL.squish.freeze
    CASE
      WHEN findings.category = 'backend'
        OR findings.details->>'type' IN (#{BACKEND_TYPES.map { |t| "'#{t}'" }.join(', ')})
        OR (findings.details->>'type' = 'http_error' AND (findings.details->'request'->>'status')::int >= 500)
        THEN 'backend'
      WHEN findings.category = 'network'
        OR findings.details->>'type' IN (#{NETWORK_TYPES.map { |t| "'#{t}'" }.join(', ')})
        THEN 'network'
      ELSE 'frontend'
    END
  SQL

  scope :from_source, ->(source) { where("(#{SOURCE_SQL}) = ?", source) }

  # Same rules as SOURCE_SQL, without a query per finding.
  def source
    type = details['type']
    server_error = type == 'http_error' && details.dig('request', 'status').to_i >= 500
    return 'backend' if category == 'backend' || BACKEND_TYPES.include?(type) || server_error
    return 'network' if category == 'network' || NETWORK_TYPES.include?(type)

    'frontend'
  end

  validates :title, presence: true, uniqueness: { scope: :run_id }
  validates :severity, presence: true

  def screenshot_url
    return nil unless screenshot.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      screenshot, host: ENV.fetch('APP_BASE_URL', 'http://localhost:3000')
    )
  end
end
