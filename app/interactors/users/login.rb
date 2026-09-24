module Users
  class Login < BaseInteractor
    def call
      find_user
      verify_password
      context.token = Users::GenerateToken.call!(user: context.user).token
    end

    private

    def find_user
      context.user = User.find_by(email: context.email&.downcase)
      context.fail!(error: 'Invalid email or password') unless context.user
    end

    def verify_password
      return if context.user.valid_password?(context.password)

      context.fail!(error: 'Invalid email or password')
    end
  end
end
