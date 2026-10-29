# v1 posts to a single ClickUp workspace through one shared API token (no per-project OAuth yet).
# Each project's target list lives on its own click_up Integration (see Integrations::ConnectClickUp).
class ClickUpService
  class ConfigurationError < StandardError; end
  # The request was understood and refused; retrying won't help.
  class PostError < StandardError; end
  # Rate limited, a ClickUp outage or a network problem; worth retrying.
  class TransientError < StandardError; end

  PRIORITY_BY_SEVERITY = { "critical" => 1, "high" => 2, "medium" => 3, "low" => 4 }.freeze
  TIMEOUT = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, HTTParty::Error].freeze

  def create_task(list_id, finding)
    response = HTTParty.post(
      "https://api.clickup.com/api/v2/list/#{ERB::Util.url_encode(list_id)}/task",
      headers: { "Authorization" => api_token, "Content-Type" => "application/json" },
      body: task_payload(finding).to_json,
      timeout: TIMEOUT
    )
    raise_for(response)

    response.parsed_response["id"]
  rescue *NETWORK_ERRORS => e
    raise TransientError, "ClickUp unreachable: #{e.class}"
  end

  private

  def raise_for(response)
    return if response.success?

    error = response.code == 429 || response.code >= 500 ? TransientError : PostError
    raise error, "ClickUp responded with #{response.code}"
  end

  def task_payload(finding)
    {
      name: finding.title,
      description: description_for(finding),
      priority: PRIORITY_BY_SEVERITY.fetch(finding.severity)
    }
  end

  def description_for(finding)
    steps = Array(finding.repro_steps).each_with_index.map { |step, index| "#{index + 1}. #{step}" }.join("\n")
    ["Repro steps:", steps, finding.screenshot_url].compact.join("\n\n")
  end

  def api_token
    ENV.fetch("CLICKUP_API_TOKEN", nil).presence || raise(ConfigurationError, "CLICKUP_API_TOKEN is not configured")
  end
end
