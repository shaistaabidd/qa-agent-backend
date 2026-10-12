require 'securerandom'
require 'json'

# Sentry/Scout-style instrumentation for QA runs. While enabled it records,
# for every request and Sidekiq job: each SQL query (with the app line that
# ran it), N+1 patterns, slow queries, every exception raised in app code —
# including ones the app rescues and swallows — and memory allocated. The QA
# worker picks a request's report up via the X-QA-Probe-Id response header.
#
# Off unless QA_PROBE_ENABLED=true (default: on in development). Reports are
# readable only with QA_PROBE_TOKEN. Not meant for production traffic.
module QaProbe
  IGNORED_EXCEPTIONS = %w[GraphQL::ExecutionError Interactor::Failure].freeze

  def self.enabled?
    return false if token.blank?

    flag = ENV.fetch('QA_PROBE_ENABLED', nil)
    flag.nil? ? Rails.env.development? : flag == 'true'
  end

  def self.token = ENV.fetch('QA_PROBE_TOKEN', nil)
  def self.n_plus_one_threshold = Integer(ENV.fetch('QA_PROBE_N_PLUS_ONE_THRESHOLD', 3))
  def self.slow_query_ms = Float(ENV.fetch('QA_PROBE_SLOW_SQL_MS', 100))

  def self.ignored_exceptions
    IGNORED_EXCEPTIONS + ENV.fetch('QA_PROBE_IGNORED_EXCEPTIONS', '').split(',').map(&:strip).reject(&:empty?)
  end

  def self.install!(app_config)
    return unless enabled?

    app_config.middleware.insert_before 0, QaProbe::Middleware
    QaProbe::Recorder.subscribe_to_sql!

    return unless defined?(Sidekiq)

    Sidekiq.configure_server do |config|
      config.server_middleware { |chain| chain.add QaProbe::SidekiqMiddleware }
    end
  end
end

require_relative 'qa_probe/sql'
require_relative 'qa_probe/recorder'
require_relative 'qa_probe/store'
require_relative 'qa_probe/middleware'
require_relative 'qa_probe/sidekiq_middleware'
