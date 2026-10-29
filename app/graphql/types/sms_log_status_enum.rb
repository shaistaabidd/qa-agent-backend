module Types
  class SmsLogStatusEnum < BaseEnum
    DESCRIPTIONS = {
      "pending" => "Saved, not yet handed to Twilio",
      "queued" => "Twilio's status: taken and queued for sending",
      "failed" => "Twilio refused it (see the error code), or it could not be handed over after retries",
      "accepted" => "Twilio's status: taken by a Messaging Service, which picks the sending number"
    }.freeze

    description "What Twilio answered when the SMS was sent"

    SmsLog.statuses.each_key { value it.upcase, DESCRIPTIONS.fetch(it), value: it }
  end
end
