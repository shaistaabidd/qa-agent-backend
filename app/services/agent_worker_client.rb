# Dispatches a queued Run to the external Playwright/LLM worker (Feature D —
# not built in this repo). The raw role credential is never included in this
# payload; instead we hand over a short-lived, single-use fetch token the
# worker exchanges for the actual value via resolveRoleCredential, at the
# moment it's needed.
class AgentWorkerClient
  class ConfigurationError < StandardError; end
  class DispatchError < StandardError; end

  def dispatch(run)
    response = HTTParty.post(
      "#{worker_base_url}/runs",
      headers: { 'Authorization' => "Bearer #{worker_api_token}", 'Content-Type' => 'application/json' },
      body: payload(run).to_json,
      timeout: 10
    )
    raise DispatchError, "Worker responded with #{response.code}" unless response.success?

    response
  end

  private

  def payload(run)
    {
      run_id: run.id,
      target_url: run.project.target_url,
      role_name: run.role_name,
      scope_feature: { name: run.scope_feature.name, route: run.scope_feature.route },
      callback_url: "#{app_base_url}/graphql",
      credential_fetch_token: RoleCredentials::IssueFetchToken.call!(run: run).token
    }
  end

  def worker_base_url
    fetch_env('AGENT_WORKER_BASE_URL')
  end

  def worker_api_token
    fetch_env('AGENT_WORKER_API_TOKEN')
  end

  def app_base_url
    fetch_env('APP_BASE_URL')
  end

  def fetch_env(key)
    ENV.fetch(key, nil).presence || raise(ConfigurationError, "#{key} is not configured")
  end
end
