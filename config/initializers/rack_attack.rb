# Coarse per-IP limits at the edge. Per-operation limits for login, codes and
# password reset are declared on the operations (GraphqlOperation.rate_limit),
# because the operation name in a GraphQL request body is chosen by the client.
module Rack
  class Attack
    GRAPHQL_PATH = "/graphql".freeze
    GOOGLE_SIGN_IN_PATH = "/auth/google".freeze

    throttle("graphql/ip", limit: 300, period: 1.minute) do |request|
      request.ip if request.path == GRAPHQL_PATH
    end

    throttle("google_sign_in/ip", limit: 30, period: 1.minute) do |request|
      request.ip if request.path.start_with?(GOOGLE_SIGN_IN_PATH)
    end

    throttle("active_storage/ip", limit: 120, period: 1.minute) do |request|
      request.ip if request.path.start_with?("/rails/active_storage")
    end

    self.throttled_responder = lambda do |_request|
      body = { errors: [{ message: I18n.t("errors.rate_limited"),
                          extensions: { code: "RATE_LIMITED" } }] }
      [429, { "Content-Type" => "application/json" }, [body.to_json]]
    end
  end
end
