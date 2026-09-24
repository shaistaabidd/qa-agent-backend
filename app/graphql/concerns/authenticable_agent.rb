module AuthenticableAgent
  extend ActiveSupport::Concern

  private

  def authenticate_agent!
    raise unauthorized_agent_error unless context[:agent_authenticated]
  end

  def unauthorized_agent_error
    GraphQL::ExecutionError.new('Unauthorized agent', options: { status: :unauthorized, code: 401 })
  end
end
