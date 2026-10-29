module Types
  class EmailLogType < BaseObject
    description "An outgoing email and the outcome of its latest delivery attempt"

    field :id, ID, null: false, description: "Unique identifier"
    field :recipient, String, null: false, description: "Comma-separated To addresses"
    field :mailer, String, null: false, description: "Mailer class that built the email"
    field :mailer_method, String, null: false, description: "Mailer action that built the email"
    field :subject, String, description: "Subject line"
    field :body, String, description: "HTML (or plain-text) body as sent"
    field :status, EmailLogStatusEnum, null: false, description: "Whether the attempt succeeded"
    field :error_message, String, description: "Error of the latest attempt, null once it succeeds"
    field :attempts, Integer, null: false, description: "Delivery attempts so far, including Sidekiq retries"
    field :sent_at, GraphQL::Types::ISO8601DateTime, description: "When the email was handed to the mail server"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the first attempt was made"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the log last changed"
  end
end
