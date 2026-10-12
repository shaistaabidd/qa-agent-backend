module QaProbe
  # Records each request and tags the response with X-QA-Probe-Id. Also
  # serves the reports to the QA worker:
  #   GET /__qa_probe/requests/:id
  #   GET /__qa_probe/jobs?since=<ISO8601>
  # both requiring the X-QA-Probe-Token header.
  class Middleware
    ENDPOINT = %r{\A/__qa_probe/(requests/(?<id>\h+)|jobs)\z}

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      if (match = ENDPOINT.match(request.path_info))
        return serve(request, match[:id])
      end
      # The QA worker's own calls back into this API aren't what's under test.
      return @app.call(env) if env['HTTP_X_AGENT_TOKEN'] || request.request_method == 'OPTIONS'

      record(request, env)
    end

    private

    def record(request, env)
      recorder = nil
      Recorder.record(kind: 'request', name: label(request)) do |current|
        recorder = current
        status, headers, body = @app.call(env)
        current.response_status!(status)
        headers['X-QA-Probe-Id'] = current.id
        [status, headers, body]
      end
    ensure
      persist(recorder) if recorder
    end

    def persist(recorder)
      Store.save_request(recorder.report)
    rescue StandardError => e
      Rails.logger.warn("[QaProbe] could not store report: #{e.class}: #{e.message}")
    end

    def label(request)
      operation = graphql_operation(request) if request.post? && request.path_info.end_with?('graphql')
      "#{request.request_method} #{request.path_info}#{operation ? " (#{operation})" : ''}"
    end

    def graphql_operation(request)
      return nil unless request.media_type == 'application/json'

      body = request.body.read
      request.body.rewind
      parsed = JSON.parse(body)
      Array.wrap(parsed).filter_map { |op| op['operationName'] if op.is_a?(Hash) }.join(', ').presence
    rescue JSON::ParserError
      nil
    end

    def serve(request, id)
      return json(401, error: 'Unauthorized') unless authorized?(request)
      return json(200, jobs: Store.jobs_since(since(request))) unless id

      report = Store.request(id)
      report ? json(200, report) : json(404, error: 'Not found or expired')
    end

    def since(request)
      Time.iso8601(request.params['since'].to_s)
    rescue ArgumentError
      15.minutes.ago
    end

    def authorized?(request)
      given = request.get_header('HTTP_X_QA_PROBE_TOKEN').to_s
      given.present? && ActiveSupport::SecurityUtils.secure_compare(given, QaProbe.token)
    end

    def json(status, body)
      [status, { 'Content-Type' => 'application/json' }, [JSON.generate(body)]]
    end
  end
end
