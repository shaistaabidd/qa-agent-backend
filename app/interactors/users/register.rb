module Users
  class Register < BaseInteractor
    def call
      create_user
      context.token = Users::GenerateToken.call!(user: context.user).token
    end

    private

    def create_user
      context.user = User.create!(email: context.email, password: context.password)
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end
  end
end
