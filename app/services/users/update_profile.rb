module Users
  # Saves profile fields, and texts the welcome SMS when this save is the one
  # that completes onboarding.
  class UpdateProfile < ApplicationService
    def initialize(user:, attributes:)
      @user = user
      @attributes = attributes
    end

    def call
      onboarding_was_complete = @user.onboarding.completed?
      return failure(:validation_failed, record: @user) unless @user.update(@attributes)

      Sms::SendWelcome.call(user: @user) if !onboarding_was_complete && @user.onboarding.completed?
      success(@user)
    end
  end
end
