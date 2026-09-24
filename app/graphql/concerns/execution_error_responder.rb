module ExecutionErrorResponder
  extend ActiveSupport::Concern

  private

  def execution_error(message: nil, code: 422)
    GraphQL::ExecutionError.new(message, options: { status: status_for(code), code: code })
  end

  def status_for(code)
    case code
    when 401 then :unauthorized
    when 403 then :forbidden
    when 404 then :not_found
    else :unprocessable_entity
    end
  end
end
