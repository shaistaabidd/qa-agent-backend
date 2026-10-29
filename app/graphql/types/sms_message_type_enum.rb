module Types
  class SmsMessageTypeEnum < BaseEnum
    DESCRIPTIONS = { "welcome" => "Sent once when a user finishes onboarding" }.freeze

    description "Why an SMS was sent"

    SmsLog.message_types.each_key { value it.upcase, DESCRIPTIONS.fetch(it), value: it }
  end
end
