module Mutations
  module Users
    class RegisterUser < BaseMutation
      argument :email, String, required: true
      argument :password, String, required: true

      type Types::Users::AuthPayload

      def resolve(**params)
        result = ::Users::Register.call(email: params[:email], password: params[:password])

        result.success? ? result : execution_error(message: result.error)
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end
