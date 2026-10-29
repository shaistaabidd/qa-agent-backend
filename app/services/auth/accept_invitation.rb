module Auth
  class AcceptInvitation < ApplicationService
    def initialize(token:, password:, password_confirmation:)
      @token = token
      @password = password
      @password_confirmation = password_confirmation
    end

    def call
      user = User.find_by_invitation_token(@token)
      return failure(:invalid_token) unless user

      accepted = user.accept_invitation(password: @password, password_confirmation: @password_confirmation)
      return failure(:validation_failed, record: user) unless accepted

      success(Session.start_for!(user))
    end
  end
end
