module Sms
  # Texts a user the welcome message, once ever (a unique index backs that up),
  # while sms_enabled is on for them. Off, nothing is sent or logged.
  class SendWelcome < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      return success unless FeatureFlag.enabled?(:sms_enabled, @user)
      return success if @user.phone.blank? || SmsLog.welcome.exists?(user: @user)

      sms_log = SmsLog.create!(user: @user, recipient: @user.phone, message_type: :welcome, body:)
      SmsDeliveryJob.perform_later(sms_log.id)
      success(sms_log)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent request already created this user's welcome SMS.
      success
    end

    private

    def body = I18n.t("sms.welcome", app_name: Rails.configuration.x.app_name, first_name: @user.first_name)
  end
end
