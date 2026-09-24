module AuthenticableApiUser
  extend ActiveSupport::Concern

  private

  def current_user
    context[:current_user]
  end

  def authenticate_user!
    raise unauthorized_error unless current_user
  end

  def unauthorized_error
    GraphQL::ExecutionError.new('Unauthorized', options: { status: :unauthorized, code: 401 })
  end
end
