# v1 posts to a single ClickUp workspace via one shared API token (no
# per-project OAuth flow built yet). Each project's target list_id lives on
# its own click_up Integration row (see Integrations::ConnectClickUp).
class ClickUpService
  class ConfigurationError < StandardError; end
  class PostError < StandardError; end

  PRIORITY_BY_SEVERITY = { 'critical' => 1, 'high' => 2, 'medium' => 3, 'low' => 4 }.freeze

  def create_task(list_id, finding)
    response = HTTParty.post(
      "https://api.clickup.com/api/v2/list/#{list_id}/task",
      headers: { 'Authorization' => api_token, 'Content-Type' => 'application/json' },
      body: task_payload(finding).to_json,
      timeout: 10
    )
    raise PostError, "ClickUp responded with #{response.code}" unless response.success?

    response.parsed_response['id']
  end

  private

  def task_payload(finding)
    {
      name: finding.title,
      description: description_for(finding),
      priority: PRIORITY_BY_SEVERITY.fetch(finding.severity)
    }
  end

  def description_for(finding)
    steps = Array(finding.repro_steps).each_with_index.map { |step, index| "#{index + 1}. #{step}" }.join("\n")
    ['Repro steps:', steps, finding.screenshot_url].compact.join("\n\n")
  end

  def api_token
    ENV.fetch('CLICKUP_API_TOKEN', nil).presence || raise(ConfigurationError, 'CLICKUP_API_TOKEN is not configured')
  end
end
