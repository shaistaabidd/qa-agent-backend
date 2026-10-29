module Types
  class EmailLogStatusEnum < BaseEnum
    DESCRIPTIONS = {
      "success" => "The email was handed to the mail server",
      "failed" => "Delivery raised an error; Sidekiq retries it"
    }.freeze

    description "Outcome of the latest delivery attempt"

    EmailLog.statuses.each_key { value it.upcase, DESCRIPTIONS.fetch(it), value: it }
  end
end
