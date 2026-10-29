FactoryBot.define do
  factory :sms_log do
    user
    recipient { "+12015550123" }
    body { "Welcome to QA Agent!" }
    message_type { :welcome }
    status { :pending }

    trait :queued do
      status { :queued }
      provider_sid { "SM#{SecureRandom.hex(16)}" }
      sent_at { Time.current }
    end

    trait :failed do
      status { :failed }
      error_code { "21211" }
      error_message { "The phone number is not valid." }
    end
  end
end
