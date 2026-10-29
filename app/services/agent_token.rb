# The shared secret the agent worker sends as X-Agent-Token. Every place that checks it goes through
# here, so the comparison is constant-time and a missing secret never lets anyone in.
module AgentToken
  HEADER = "X-Agent-Token".freeze

  module_function

  def valid?(token)
    expected = Rails.configuration.x.agent[:api_token]
    token.present? && expected.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
  end
end
