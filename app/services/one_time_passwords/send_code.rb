module OneTimePasswords
  class SendCode < ApplicationService
    def initialize(user:, purpose:, to: user.email)
      @user = user
      @purpose = purpose.to_s
      @to = to
    end

    def call
      code = OneTimePassword.issue!(user: @user, purpose: @purpose)
      AuthMailer.with(user: @user, to: @to, code:, purpose: @purpose).verification_code.deliver_later
      success
    end
  end
end
