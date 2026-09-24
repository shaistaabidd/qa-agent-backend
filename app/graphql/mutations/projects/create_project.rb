module Mutations
  module Projects
    class CreateProject < BaseMutation
      include AuthenticableApiUser

      argument :name, String, required: true
      argument :target_url, String, required: true

      type Types::Projects::ProjectPayload

      def resolve(**params)
        authenticate_user!

        result = ::Projects::Create.call(
          current_user: current_user,
          name: params[:name],
          target_url: params[:target_url]
        )

        result.success? ? result : execution_error(message: result.error)
      rescue GraphQL::ExecutionError
        raise
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end
