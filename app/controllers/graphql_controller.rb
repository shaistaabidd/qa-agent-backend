class GraphqlController < ApplicationController
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActiveStorage::SetCurrent

  before_action :set_current_request_details
  rescue_from JSON::ParserError, with: :render_malformed_variables

  def execute
    result = QaAgentBackendSchema.execute(
      params[:query],
      variables: graphql_variables,
      operation_name: params[:operationName],
      context: { current_session: Current.session, current_user: Current.user, ip_address: Current.ip_address,
                 agent: agent_authenticated? }
    )

    render json: result
  end

  private

  def set_current_request_details
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
    Current.session = authenticated_session
    PaperTrail.request.whodunnit = Current.actor&.id
  end

  # An invalid, expired or blocked token is treated as no token, so the
  # operation itself decides whether it needs a signed-in user.
  def authenticated_session
    session = authenticate_with_http_token { |token, _options| Session.find_by_token(token) }
    return unless session&.usable?

    session.record_activity!
    session
  end

  # Machine-to-machine auth for the agent worker calling back: a shared secret, never a user.
  def agent_authenticated? = AgentToken.valid?(request.headers[AgentToken::HEADER])

  def render_malformed_variables
    render json: { errors: [{ message: I18n.t("errors.malformed_request"), extensions: { code: "BAD_REQUEST" } }] },
           status: :bad_request
  end

  def graphql_variables
    variables = params[:variables]
    return variables.to_unsafe_h if variables.is_a?(ActionController::Parameters)
    return JSON.parse(variables) if variables.is_a?(String) && variables.present?

    {}
  end
end
