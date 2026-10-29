module Auth
  class ResetPassword < ApplicationService
    def initialize(token:, password:, password_confirmation:)
      @token = token
      @password = password
      @password_confirmation = password_confirmation
    end

    def call
      user = User.find_by_password_reset_token(@token)
      return failure(:invalid_token) unless user&.can_sign_in?

      updated = user.update_password(password: @password, password_confirmation: @password_confirmation)
      return failure(:validation_failed, record: user) unless updated

      success(Session.start_for!(user))
    end
  end
end
