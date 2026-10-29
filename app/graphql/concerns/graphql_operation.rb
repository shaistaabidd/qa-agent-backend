# Shared by every query resolver and mutation: authentication, authorization
# context, per-operation rate limits and mapping service failures to errors.
module GraphqlOperation
  extend ActiveSupport::Concern

  RateLimitRule = Data.define(:limit, :period, :discriminator)

  included do
    include ActionPolicy::Behaviour

    authorize :user, through: :current_user
    authorize :session, through: :current_session

    class_attribute :authentication_required, default: true
    class_attribute :agent_only, default: false
    class_attribute :rate_limit_rules, default: []
  end

  class_methods do
    def allow_unauthenticated!
      self.authentication_required = false
    end

    # For operations only the agent worker calls (with X-Agent-Token): there is no signed-in user, but
    # the agent token is required, and a user's own session never stands in for it.
    def agent_only!
      self.authentication_required = false
      self.agent_only = true
    end

    # `by` is evaluated on the operation instance with its arguments and picks
    # what to count per (an email, the current user). Defaults to the client IP.
    # Declare it more than once to enforce several limits (per email and per IP).
    def rate_limit(to:, within:, by: nil)
      self.rate_limit_rules += [RateLimitRule.new(limit: to, period: within, discriminator: by)]
    end
  end

  def ready?(**arguments)
    raise GraphqlErrors.unauthenticated if authentication_required && current_user.nil?
    raise GraphqlErrors.unauthenticated if agent_only && !context[:agent]
    raise GraphqlErrors.rate_limited if rate_limit_exceeded?(arguments)

    super
  end

  private

  def current_user = context[:current_user]
  def current_session = context[:current_session]

  def value_or_raise!(result)
    raise GraphqlErrors.from_service_error(result.error) if result.failure?

    result.value
  end

  # Every aliased copy of an operation in one request runs this, so each counts.
  # Stops at the first exceeded rule, so later rules aren't counted for this call.
  def rate_limit_exceeded?(arguments)
    rate_limit_rules.each_with_index do |rule, index|
      discriminator = rule.discriminator ? instance_exec(arguments, &rule.discriminator) : context[:ip_address]
      limiter = RateLimiter.new(scope: "#{self.class.name}:#{index}", discriminator:,
                                limit: rule.limit, period: rule.period)
      return true if limiter.exceeded?
    end
    false
  end
end
