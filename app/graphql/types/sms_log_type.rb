module Types
  class SmsLogType < BaseObject
    description "An outgoing SMS and what Twilio answered"

    field :id, ID, null: false, description: "Unique identifier"
    field :recipient, String, null: false, description: "Phone number it was sent to (E.164)"
    field :body, String, null: false, description: "Message text"
    field :message_type, SmsMessageTypeEnum, null: false, description: "Why it was sent"
    field :status, SmsLogStatusEnum, null: false, description: "Pending, or what Twilio answered"
    field :provider_sid, String, description: "Twilio message SID, once handed over"
    field :error_code, String, description: "Twilio error code of a failed message"
    field :error_message, String, description: "What went wrong, in plain words"
    field :sent_at, GraphQL::Types::ISO8601DateTime, description: "When Twilio accepted it"
    field :user, UserType, description: "The recipient's account; null if it was deleted"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the SMS was created"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the log last changed"
  end
end
