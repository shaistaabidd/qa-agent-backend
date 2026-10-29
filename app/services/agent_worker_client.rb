# Dispatches a queued Run to the external Playwright worker (the separate qa-agent-worker project).
# The raw role credential is never part of this payload: the worker gets a short-lived fetch token
# and exchanges it for the credential through resolveRoleCredential, at the moment it logs in.
class AgentWorkerClient
  class ConfigurationError < StandardError; end
  class DispatchError < StandardError; end

  TIMEOUT = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, HTTParty::Error].freeze

  def dispatch(run)
    response = HTTParty.post(
      "#{setting(:worker_base_url)}/runs",
      headers: { "Authorization" => "Bearer #{setting(:worker_api_token)}", "Content-Type" => "application/json" },
      body: payload(run).to_json,
      timeout: TIMEOUT
    )
    raise DispatchError, "Worker responded with #{response.code}" unless response.success?

    response
  rescue *NETWORK_ERRORS => e
    raise DispatchError, "Worker unreachable: #{e.class}"
  end

  private

  def payload(run)
    {
      run_id: run.id,
      target_url: run.project.target_url,
      role_name: run.role_name,
      scope_feature: { name: run.scope_feature.name, route: run.scope_feature.route },
      callback_url: callback_url,
      credential_fetch_token: fetch_token(run)
    }
  end

  def fetch_token(run)
    result = RoleCredentials::IssueFetchToken.call(run:)
    raise DispatchError, result.error.message if result.failure?

    result.value
  end

  # Where the worker reports back: this API's own public GraphQL endpoint.
  def callback_url
    options = Rails.application.config.action_mailer.default_url_options
    "#{options[:protocol] || "http"}://#{options.fetch(:host)}/graphql"
  end

  def setting(key)
    Rails.configuration.x.agent[key].presence || raise(ConfigurationError, "agent #{key} is not configured")
  end
end
