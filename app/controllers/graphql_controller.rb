# frozen_string_literal: true

class GraphqlController < ApplicationController
  include AuthenticableUser

  def execute
    result = QaAgentBackendSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      context: graphql_context,
      operation_name: params[:operationName]
    )
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  def graphql_context
    { current_user: current_user, agent_authenticated: agent_authenticated?, request: request }
  end

  # Machine-to-machine auth for the external agent worker calling back
  # (receiveRunResult, resolveRoleCredential) — a static shared secret,
  # distinct from user JWTs.
  def agent_authenticated?
    header_token = request.headers['X-Agent-Token']
    expected_token = ENV.fetch('AGENT_API_TOKEN', nil)
    return false if header_token.blank? || expected_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(header_token, expected_token)
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      variables_param.present? ? JSON.parse(variables_param) : {}
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(error)
    logger.error error.message
    logger.error error.backtrace.join("\n")

    render json: { errors: [{ message: error.message, backtrace: error.backtrace }], data: {} },
           status: :internal_server_error
  end
end
