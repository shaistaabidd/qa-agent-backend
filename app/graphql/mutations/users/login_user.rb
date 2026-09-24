module Mutations
  module Users
    class LoginUser < BaseMutation
      argument :email, String, required: true
      argument :password, String, required: true

      type Types::Users::AuthPayload

      def resolve(**params)
        result = ::Users::Login.call(email: params[:email], password: params[:password])

        result.success? ? result : execution_error(message: result.error, code: 401)
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end
